###############################################################################
# test_mcp.jl — unit tests for the MCP client
#
# Tests that require a real subprocess use a simple echo-based MCP stub
# written as an inline Julia script, so no external dependencies are needed.
###############################################################################

# ── MCPServer struct ──────────────────────────────────────────────────────────

@testset "MCPServer construction" begin
    s = MCPServer(command="uvx", args=["--from", "mcpdoc", "mcpdoc"])
    @test s.command     == "uvx"
    @test s.args        == ["--from", "mcpdoc", "mcpdoc"]
    @test s.timeout     == 60.0
    @test s.cache_tools == true
    @test s.env         == Dict{String,String}()

    s2 = MCPServer(
        command     = "python",
        args        = ["server.py"],
        timeout     = 10.0,
        cache_tools = false,
        env         = Dict("FOO" => "bar"),
    )
    @test s2.timeout     == 10.0
    @test s2.cache_tools == false
    @test s2.env["FOO"]  == "bar"
end

@testset "MCPClient construction" begin
    server = MCPServer(command="echo", args=String[])
    client = MCPClient(server)
    @test client.server    === server
    @test isnothing(client.proc)
    @test isnothing(client.proc_stdin)
    @test isnothing(client.proc_stdout)
    @test client._req_id   == 0
    @test isnothing(client._tools)
    @test !NimbleAgents._connected(client)
end

# ── Stub MCP server ───────────────────────────────────────────────────────────
#
# We write a minimal MCP server as an inline Julia script that:
#  - Responds to initialize with a valid result
#  - Responds to notifications/initialized (no response needed)
#  - Responds to tools/list with one tool: "echo_tool"
#  - Responds to tools/call for "echo_tool" by echoing the "message" argument
#
# This lets us test connect!, list_tools, and tool invocation without any
# external dependencies or network calls.

const _STUB_SERVER_SCRIPT = """
import JSON3

function respond(id, result)
    msg = Dict("jsonrpc" => "2.0", "id" => id, "result" => result)
    println(JSON3.write(msg))
    flush(stdout)
end

for line in eachline(stdin)
    isempty(strip(line)) && continue
    req = try JSON3.read(line, Dict{String,Any}) catch; continue end
    method = get(req, "method", "")
    id     = get(req, "id", nothing)

    if method == "initialize"
        respond(id, Dict(
            "protocolVersion" => "2024-11-05",
            "capabilities"    => Dict(),
            "serverInfo"      => Dict("name" => "stub", "version" => "0.1"),
        ))
    elseif method == "notifications/initialized"
        # no response
    elseif method == "tools/list"
        respond(id, Dict("tools" => [Dict(
            "name"        => "echo_tool",
            "description" => "Echoes the message argument.",
            "inputSchema" => Dict(
                "type"       => "object",
                "properties" => Dict("message" => Dict("type" => "string")),
                "required"   => ["message"],
            ),
        )]))
    elseif method == "tools/call"
        params = get(req, "params", Dict())
        args   = get(params, "arguments", Dict())
        msg    = get(args, "message", "(no message)")
        respond(id, Dict("content" => [Dict("type" => "text", "text" => "echo: \$msg")]))
    end
end
"""

function _make_stub_server()::MCPServer
    script = tempname() * ".jl"
    write(script, _STUB_SERVER_SCRIPT)
    MCPServer(
        command = joinpath(Sys.BINDIR, "julia"),
        args    = ["--project=$(Base.active_project())", script],
        timeout = 30.0,
    )
end

# ── Shared stub client (spawned once for the connected tests) ─────────────────
# Avoids spawning a new Julia subprocess for every @testset.

const _stub_client = Ref{Union{MCPClient, Nothing}}(nothing)

function _get_stub_client()::MCPClient
    if isnothing(_stub_client[]) || !NimbleAgents._connected(_stub_client[])
        _stub_client[] = connect!(MCPClient(_make_stub_server()))
    end
    _stub_client[]
end

# ── Connected tests (share one subprocess) ────────────────────────────────────

@testset "connect! — stub server handshake" begin
    client = _get_stub_client()
    @test NimbleAgents._connected(client)
end

@testset "list_tools — discovers stub tools" begin
    client = _get_stub_client()
    tools = list_tools(client)
    @test length(tools) == 1
    @test tools[1] isa NimbleTool
    @test tools[1].name == "echo_tool"
    @test occursin("Echo", something(tools[1].description, ""))
    @test haskey(tools[1].parameters["properties"], "message")
end

@testset "list_tools — caching" begin
    client = _get_stub_client()
    tools1 = list_tools(client)
    tools2 = list_tools(client)     # should return cached result
    @test tools1 === tools2         # same object, not re-fetched
end

@testset "tool callable — echo_tool invocation" begin
    client = _get_stub_client()
    tools  = list_tools(client)
    echo   = tools[1]
    result = echo.callable(Dict{Symbol,Any}(:message => "hello MCP"))
    @test result == "echo: hello MCP"
end

@testset "close! — idempotent" begin
    # Use a fresh client so we don't break the shared one
    client = connect!(MCPClient(_make_stub_server()))
    close!(client)
    close!(client)   # second call should not throw
    @test !NimbleAgents._connected(client)
end

# Tear down shared client after connected tests
isnothing(_stub_client[]) || close!(_stub_client[])

# ── cache_tools=false: needs its own server (different config) ────────────────

@testset "list_tools — cache_tools=false refetches" begin
    script = tempname() * ".jl"
    write(script, _STUB_SERVER_SCRIPT)
    server = MCPServer(
        command     = joinpath(Sys.BINDIR, "julia"),
        args        = ["--project=$(Base.active_project())", script],
        timeout     = 30.0,
        cache_tools = false,
    )
    client = connect!(MCPClient(server))
    tools1 = list_tools(client)
    tools2 = list_tools(client)
    @test tools1 !== tools2     # different objects — re-fetched each time
    close!(client)
end

# ── Agent struct test (no subprocess) ────────────────────────────────────────

@testset "Agent with mcp_servers — tools discovered" begin
    server = _make_stub_server()
    agent  = Agent(
        name         = "MCPAgent",
        instructions = "test",
        mcp_servers  = [server],
    )
    @test length(agent.mcp_servers) == 1
    @test agent.mcp_servers[1] === server
end

@testset "_connect_mcp_servers — bad server does not crash" begin
    bad = MCPServer(
        command = "false",   # exits immediately with code 1
        args    = String[],
        timeout = 2.0,
    )
    tools, clients = NimbleAgents._connect_mcp_servers([bad])
    @test isempty(tools)
    @test isempty(clients)
end
