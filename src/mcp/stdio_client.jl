###############################################################################
# mcp/stdio_client.jl — stdio transport for MCP
###############################################################################

# Send one JSON-RPC request and return the parsed response Dict.
# Blocks until a response with the matching id arrives or timeout fires.
#
# Note: bytesavailable() always returns 0 for Julia Pipe streams, so we cannot
# poll. Instead we read lines in a background task and use timedwait.
function _rpc(client::MCPClient, method::String, params=nothing)::Dict{String,Any}
    id = _next_id!(client)
    req = Dict{String,Any}("jsonrpc" => "2.0", "id" => id, "method" => method)
    isnothing(params) || (req["params"] = params)

    write(client.proc_stdin, JSON3.write(req) * "\n")
    flush(client.proc_stdin)

    # Read lines in a background task. We loop because the server may send
    # notifications (no "id") before our response.
    result_ref = Ref{Union{Dict{String,Any},Nothing}}(nothing)
    error_ref = Ref{Union{String,Nothing}}(nothing)

    task = @async begin
        while true
            raw = try
                readline(client.proc_stdout; keep=false)
            catch
                ""
            end
            isempty(raw) && break
            resp = try
                Dict{String,Any}(JSON3.read(raw, Dict{String,Any}))
            catch
                continue   # skip malformed / non-JSON lines
            end
            haskey(resp, "id") || continue   # skip notifications
            resp["id"] == id || continue   # skip responses for other requests
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

"""
    connect!(client::MCPClient) -> MCPClient

Spawn the MCP server subprocess and perform the JSON-RPC initialize handshake.
Returns the client (mutated in place) for chaining.
"""
function connect!(client::MCPClient)::MCPClient
    server = client.server

    # Build the command with optional extra env
    cmd = Cmd(
        Cmd([server.command, server.args...]);
        env=if isempty(server.env)
            nothing
        else
            merge(Dict(k => v for (k, v) in ENV), server.env)
        end,
    )

    inp = Pipe()
    out = Pipe()

    proc = run(pipeline(cmd; stdin=inp, stdout=out, stderr=devnull); wait=false)

    close(inp.out)   # close read end of stdin pipe (we write to inp.in)
    close(out.in)    # close write end of stdout pipe (we read from out.out)

    client.proc = proc
    client.proc_stdin = inp.in
    client.proc_stdout = out.out

    # Give the server a moment to start its event loop before we write.
    # Some servers (e.g. mcpdoc) take a few seconds to fetch remote resources.
    sleep(0.5)

    # MCP initialize handshake
    _rpc(
        client,
        "initialize",
        Dict{String,Any}(
            "protocolVersion" => "2024-11-05",
            "capabilities" => Dict{String,Any}(),
            "clientInfo" =>
                Dict{String,Any}("name" => "NimbleAgents.jl", "version" => "0.1"),
        ),
    )

    # Notify server that client is ready
    notif = Dict{String,Any}(
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized",
        "params" => Dict{String,Any}(),
    )
    write(client.proc_stdin, JSON3.write(notif) * "\n")
    flush(client.proc_stdin)

    client
end

"""
    list_tools(client::MCPClient) -> Vector{NimbleTool}

Fetch the tool list from the MCP server and return them as `NimbleTool` objects
ready to be passed to an `Agent`. Results are cached if `server.cache_tools`.
"""
function list_tools(client::MCPClient)::Vector{NimbleTool}
    _list_tools_cached!(client)
end

"""
    close!(client::MCPClient)

Terminate the MCP server subprocess and clean up I/O handles.
"""
function close!(client::MCPClient)
    isnothing(client.proc_stdin) || (
        try
            close(client.proc_stdin)
        catch
        end
    )
    isnothing(client.proc_stdout) || (
        try
            close(client.proc_stdout)
        catch
        end
    )
    if !isnothing(client.proc) && process_running(client.proc)
        kill(client.proc)
    end
    client.proc = nothing
    client.proc_stdin = nothing
    client.proc_stdout = nothing
    client._tools = nothing
    return nothing
end
