###############################################################################
# mcp.jl — Model Context Protocol (MCP) client — stdio transport
#
# Implements just enough of the MCP spec (2024-11-05) to:
#   1. Spawn an MCP server subprocess
#   2. Perform the JSON-RPC initialize handshake
#   3. Discover tools via tools/list
#   4. Invoke tools via tools/call
#
# Wire format: newline-delimited JSON-RPC 2.0 over the process stdin/stdout.
# Each message is a single JSON object followed by \n. Responses are matched
# to requests by the integer "id" field.
#
# Usage:
#   server = MCPServer(command="uvx", args=["--from","mcpdoc","mcpdoc","--urls","LangGraph:https://langchain-ai.github.io/langgraph/llms.txt"])
#   client = connect!(MCPClient(server))
#   tools  = list_tools(client)          # → Vector{NimbleTool}
#   close!(client)
###############################################################################

import JSON3

# ── MCPServer ─────────────────────────────────────────────────────────────────

"""
    MCPServer(; command, args, env, timeout, cache_tools)

Describes an MCP server that NimbleAgents can connect to via stdio.

The server is started as a subprocess. Arguments from the LLM are sent over
JSON-RPC; results are read back on stdout.

# Fields
- `command::String`: Executable to run (e.g. `"uvx"`, `"npx"`, `"python"`).
- `args::Vector{String}`: Arguments passed to the command.
- `env::Dict{String,String}`: Extra environment variables for the subprocess.
- `timeout::Float64`: Seconds to wait for each JSON-RPC response (default: `30.0`).
- `cache_tools::Bool`: Cache the tool list after the first `tools/list` call
  (default: `true`). Set to `false` if the server's tool set changes at runtime.

# Example
```julia
server = MCPServer(
    command = "uvx",
    args    = ["--from", "mcpdoc", "mcpdoc",
               "--urls", "LangGraph:https://langchain-ai.github.io/langgraph/llms.txt",
               "--transport", "stdio"],
)

agent = Agent(
    name        = "DocsBot",
    instructions = "Answer questions using the LangGraph documentation.",
    mcp_servers = [server],
)
```
"""
struct MCPServer
    command     ::String
    args        ::Vector{String}
    env         ::Dict{String, String}
    timeout     ::Float64
    cache_tools ::Bool
end

function MCPServer(;
    command     ::String,
    args        ::Vector{String}          = String[],
    env         ::Dict{String, String}    = Dict{String,String}(),
    timeout     ::Float64                 = 60.0,
    cache_tools ::Bool                    = true,
)
    MCPServer(command, args, env, timeout, cache_tools)
end

# ── MCPClient ─────────────────────────────────────────────────────────────────

"""
    MCPClient(server)

A live connection to one MCP server. Created via `connect!(MCPClient(server))`.
Not constructed directly by users — attach `MCPServer` objects to an `Agent` and
the framework manages client lifetime.
"""
mutable struct MCPClient
    server      ::MCPServer
    proc        ::Union{Base.Process, Nothing}
    proc_stdin  ::Union{IO, Nothing}
    proc_stdout ::Union{IO, Nothing}
    _req_id     ::Int
    _tools      ::Union{Vector{NimbleTool}, Nothing}   # cached after first list_tools
    _lock       ::ReentrantLock                         # serialise JSON-RPC calls
end

MCPClient(server::MCPServer) =
    MCPClient(server, nothing, nothing, nothing, 0, nothing, ReentrantLock())

_connected(c::MCPClient) = !isnothing(c.proc) && process_running(c.proc)

# ── JSON-RPC helpers ──────────────────────────────────────────────────────────

function _next_id!(client::MCPClient)::Int
    client._req_id += 1
end

# Send one JSON-RPC request and return the parsed response Dict.
# Blocks until a response with the matching id arrives or timeout fires.
#
# Note: bytesavailable() always returns 0 for Julia Pipe streams, so we cannot
# poll. Instead we read lines in a background task and use timedwait.
function _rpc(client::MCPClient, method::String, params=nothing)::Dict{String,Any}
    id  = _next_id!(client)
    req = Dict{String,Any}("jsonrpc" => "2.0", "id" => id, "method" => method)
    isnothing(params) || (req["params"] = params)

    write(client.proc_stdin, JSON3.write(req) * "\n")
    flush(client.proc_stdin)

    # Read lines in a background task. We loop because the server may send
    # notifications (no "id") before our response.
    result_ref = Ref{Union{Dict{String,Any}, Nothing}}(nothing)
    error_ref  = Ref{Union{String, Nothing}}(nothing)

    task = @async begin
        while true
            raw = try readline(client.proc_stdout; keep=false) catch; "" end
            isempty(raw) && break
            resp = try
                Dict{String,Any}(JSON3.read(raw, Dict{String,Any}))
            catch
                continue   # skip malformed / non-JSON lines
            end
            haskey(resp, "id") || continue   # skip notifications
            resp["id"] == id   || continue   # skip responses for other requests
            if haskey(resp, "error")
                err = resp["error"]
                error_ref[] = "MCP error $(get(err, "code", "?")): $(get(err, "message", "unknown"))"
            else
                result_ref[] = resp
            end
            break
        end
    end

    status = timedwait(() -> istaskdone(task), client.server.timeout)
    if status == :timed_out
        error("MCP timeout ($(client.server.timeout)s) waiting for response to $(method)")
    end
    !isnothing(error_ref[]) && error(error_ref[])
    isnothing(result_ref[]) && error("MCP: no response received for $(method)")
    result_ref[]
end

# ── connect! ──────────────────────────────────────────────────────────────────

"""
    connect!(client::MCPClient) -> MCPClient

Spawn the MCP server subprocess and perform the JSON-RPC initialize handshake.
Returns the client (mutated in place) for chaining.
"""
function connect!(client::MCPClient)::MCPClient
    server = client.server

    # Build the command with optional extra env
    cmd = Cmd(Cmd([server.command, server.args...]);
              env = isempty(server.env) ? nothing :
                    merge(Dict(k => v for (k,v) in ENV), server.env))

    inp = Pipe()
    out = Pipe()

    proc = run(pipeline(cmd, stdin=inp, stdout=out, stderr=devnull); wait=false)

    close(inp.out)   # close read end of stdin pipe (we write to inp.in)
    close(out.in)    # close write end of stdout pipe (we read from out.out)

    client.proc        = proc
    client.proc_stdin  = inp.in
    client.proc_stdout = out.out

    # Give the server a moment to start its event loop before we write.
    # Some servers (e.g. mcpdoc) take a few seconds to fetch remote resources.
    sleep(0.5)

    # MCP initialize handshake
    _rpc(client, "initialize", Dict{String,Any}(
        "protocolVersion" => "2024-11-05",
        "capabilities"    => Dict{String,Any}(),
        "clientInfo"      => Dict{String,Any}(
            "name"    => "NimbleAgents.jl",
            "version" => "0.1",
        ),
    ))

    # Notify server that client is ready
    notif = Dict{String,Any}(
        "jsonrpc" => "2.0",
        "method"  => "notifications/initialized",
        "params"  => Dict{String,Any}(),
    )
    write(client.proc_stdin, JSON3.write(notif) * "\n")
    flush(client.proc_stdin)

    client
end

# ── list_tools ────────────────────────────────────────────────────────────────

"""
    list_tools(client::MCPClient) -> Vector{NimbleTool}

Fetch the tool list from the MCP server and return them as `NimbleTool` objects
ready to be passed to an `Agent`. Results are cached if `server.cache_tools`.
"""
function list_tools(client::MCPClient)::Vector{NimbleTool}
    if client.server.cache_tools && !isnothing(client._tools)
        return client._tools
    end

    lock(client._lock) do
        # Double-checked locking
        if client.server.cache_tools && !isnothing(client._tools)
            return client._tools
        end

        resp  = _rpc(client, "tools/list", Dict{String,Any}())
        tools_raw = get(get(resp, "result", Dict()), "tools", [])

        tools = NimbleTool[]
        for t in tools_raw
            name        = String(t["name"])
            description = get(t, "description", nothing)
            schema      = Dict{String,Any}(get(t, "inputSchema",
                              Dict("type" => "object", "properties" => Dict())))

            # Close over name and client so the callable captures the right values
            tool_name   = name
            tool_client = client
            callable = (args::Dict{Symbol,<:Any}) -> begin
                str_args = Dict{String,Any}(string(k) => v for (k,v) in args)
                _call_mcp_tool(tool_client, tool_name, str_args)
            end

            push!(tools, NimbleTool(;
                name        = name,
                parameters  = schema,
                description = description,
                callable    = callable,
            ))
        end

        client._tools = tools
        tools
    end
end

# ── _call_mcp_tool ────────────────────────────────────────────────────────────

function _call_mcp_tool(client::MCPClient, name::String,
                        arguments::Dict{String,Any})::String
    lock(client._lock) do
        resp = _rpc(client, "tools/call", Dict{String,Any}(
            "name"      => name,
            "arguments" => arguments,
        ))

        result = get(resp, "result", Dict())
        content = get(result, "content", [])

        # Concatenate all text content blocks
        parts = String[]
        for block in content
            block_type = get(block, "type", "")
            if block_type == "text"
                push!(parts, string(get(block, "text", "")))
            elseif block_type == "image"
                push!(parts, "[image: $(get(block, "mimeType", "image"))]")
            else
                push!(parts, string(block))
            end
        end

        isempty(parts) ? "(no output)" : join(parts, "\n")
    end
end

# ── close! ────────────────────────────────────────────────────────────────────

"""
    close!(client::MCPClient)

Terminate the MCP server subprocess and clean up I/O handles.
"""
function close!(client::MCPClient)
    isnothing(client.proc_stdin)  || (try close(client.proc_stdin)  catch end)
    isnothing(client.proc_stdout) || (try close(client.proc_stdout) catch end)
    if !isnothing(client.proc) && process_running(client.proc)
        kill(client.proc)
    end
    client.proc        = nothing
    client.proc_stdin  = nothing
    client.proc_stdout = nothing
    client._tools      = nothing
    return nothing
end

# ── _mcp_tools_for_run! ───────────────────────────────────────────────────────
# Internal helper used by run!: connect all MCP servers, collect their tools,
# return (tools_vector, clients_vector) so run! can close them in a finally block.

function _connect_mcp_servers(servers::Vector{MCPServer})::Tuple{Vector{NimbleTool}, Vector{MCPClient}}
    all_tools = NimbleTool[]
    clients   = MCPClient[]

    for server in servers
        client = MCPClient(server)
        try
            connect!(client)
            tools = list_tools(client)
            append!(all_tools, tools)
            push!(clients, client)
            println("[MCP] connected to $(server.command) $(join(server.args, " ")) — $(length(tools)) tool(s): $(join([t.name for t in tools], ", "))")
        catch e
            println(stderr, "[MCP] failed to connect: $(sprint(showerror, e))")
            close!(client)
        end
    end

    (all_tools, clients)
end

function _close_mcp_clients(clients::Vector{MCPClient})
    for client in clients
        try close!(client) catch end
    end
end
