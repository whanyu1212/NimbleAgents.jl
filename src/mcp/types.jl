###############################################################################
# mcp/types.jl — MCP server/client transport types
###############################################################################

"""
    MCPServer(; command, args, env, timeout, cache_tools)
    MCPServer(; url, headers, timeout, cache_tools)

Describes an MCP server that NimbleAgents can connect to.

Two transports are supported:

- **stdio** — spawns the server as a local subprocess. Provide `command` (and
  optionally `args` / `env`).
- **HTTP** — connects to a remote MCP endpoint via HTTP POST. Provide `url`
  (and optionally `headers` for authentication).

# Fields (stdio)
- `command::String`: Executable to run (e.g. `"uvx"`, `"npx"`, `"python"`).
- `args::Vector{String}`: Arguments passed to the command.
- `env::Dict{String,String}`: Extra environment variables for the subprocess.

# Fields (HTTP)
- `url::String`: HTTP endpoint URL (e.g. `"https://docs.langchain.com/mcp"`).
- `headers::Dict{String,String}`: Request headers, e.g. for auth tokens.

# Fields (shared)
- `timeout::Float64`: Seconds to wait for each JSON-RPC response (default: `60.0`).
- `cache_tools::Bool`: Cache tool list after first discovery (default: `true`).

# Examples
```julia
# stdio
server = MCPServer(
    command = "uvx",
    args    = ["--from", "mcpdoc", "mcpdoc",
               "--urls", "LangGraph:https://langchain-ai.github.io/langgraph/llms.txt",
               "--transport", "stdio"],
)

# HTTP — no auth
server = MCPServer(url="https://docs.langchain.com/mcp")

# HTTP — with Bearer token
server = MCPServer(
    url     = "https://huggingface.co/mcp",
    headers = Dict("Authorization" => "Bearer hf_xxx"),
)
```
"""
struct MCPServer
    command::Union{String,Nothing}
    args::Vector{String}
    env::Dict{String,String}
    url::Union{String,Nothing}
    headers::Dict{String,String}
    timeout::Float64
    cache_tools::Bool
end

function MCPServer(;
    command::Union{String,Nothing}=nothing,
    args::Vector{String}=String[],
    env::Dict{String,String}=Dict{String,String}(),
    url::Union{String,Nothing}=nothing,
    headers::Dict{String,String}=Dict{String,String}(),
    timeout::Float64=60.0,
    cache_tools::Bool=true,
)
    isnothing(command) == isnothing(url) &&
        error("MCPServer: provide exactly one of `command` (stdio) or `url` (HTTP)")
    MCPServer(command, args, env, url, headers, timeout, cache_tools)
end

_is_http(s::MCPServer) = !isnothing(s.url)

"""
    MCPClient(server)

A live connection to one MCP server via stdio. Created via `connect!(MCPClient(server))`.
Not constructed directly by users — attach `MCPServer` objects to an `Agent` and
the framework manages client lifetime.
"""
mutable struct MCPClient
    server::MCPServer
    proc::Union{Base.Process,Nothing}
    proc_stdin::Union{IO,Nothing}
    proc_stdout::Union{IO,Nothing}
    _req_id::Int
    _tools::Union{Vector{NimbleTool},Nothing}
    _lock::ReentrantLock
end

function MCPClient(server::MCPServer)
    MCPClient(server, nothing, nothing, nothing, 0, nothing, ReentrantLock())
end

_connected(c::MCPClient) = !isnothing(c.proc) && process_running(c.proc)

"""
    MCPHTTPClient(server)

A live connection to one MCP server via HTTP POST. Created automatically when
an `MCPServer` is constructed with a `url` field.
"""
mutable struct MCPHTTPClient
    server::MCPServer
    _req_id::Int
    _tools::Union{Vector{NimbleTool},Nothing}
    _lock::ReentrantLock
end

MCPHTTPClient(server::MCPServer) = MCPHTTPClient(server, 0, nothing, ReentrantLock())

const AnyMCPClient = Union{MCPClient,MCPHTTPClient}

function _make_client(server::MCPServer)
    _is_http(server) ? MCPHTTPClient(server) : MCPClient(server)
end
