@testset "ExternalAgentTool construction" begin
    t = ExternalAgentTool(
        name="test_agent",
        description="A test external agent.",
        command=["echo", "{task}"],
        args=["task" => CLIArg(String, "The task")],
    )

    @test t isa ExternalAgentTool
    @test t isa AbstractTool
    @test t.name == "test_agent"
    @test t.description == "A test external agent."
    @test t.command == ["echo", "{task}"]
    @test t.timeout == 300.0
    @test t.working_dir === nothing
    @test t.on_output === nothing
    @test t.parse_result === nothing
    @test t.return_direct == false
    @test t.return_artifact == false
end

@testset "ExternalAgentTool schema" begin
    t = ExternalAgentTool(
        name="agent",
        description=".",
        command=["echo", "{task}"],
        args=[
            "task" => CLIArg(String, "The task"),
            "mode" => CLIArg(String, "Mode"; required=false),
        ],
    )
    schema = t.parameters
    @test schema["type"] == "object"
    @test haskey(schema["properties"], "task")
    @test haskey(schema["properties"], "mode")
    @test "task" in schema["required"]
    @test !("mode" in schema["required"])
end

@testset "ExternalAgentTool — _render_command_ext" begin
    t = ExternalAgentTool(
        name="agent",
        description=".",
        command=["myagent", "-p", "{task}", "--model", "{model}"],
        args=["task" => CLIArg(String, "Task"), "model" => CLIArg(String, "Model")],
    )
    cmd = NimbleAgents._render_command_ext(
        t, Dict{Symbol,Any}(:task => "hello world", :model => "fast")
    )
    @test collect(cmd) == ["myagent", "-p", "hello world", "--model", "fast"]
end

@testset "ExternalAgentTool — execution via _run_external_agent" begin
    t = ExternalAgentTool(
        name="echo_agent",
        description="Echo test.",
        command=["echo", "{task}"],
        args=["task" => CLIArg(String, "Task")],
    )
    result = NimbleAgents._run_external_agent(
        t, Dict{Symbol,Any}(:task => "hello from agent")
    )
    @test occursin("hello from agent", result)
end

@testset "ExternalAgentTool — on_output callback" begin
    captured = String[]
    t = ExternalAgentTool(
        name="echo_cb",
        description=".",
        command=["echo", "{task}"],
        args=["task" => CLIArg(String, "Task")],
        on_output=line -> push!(captured, line),
    )
    NimbleAgents._run_external_agent(t, Dict{Symbol,Any}(:task => "callback test"))
    @test any(l -> occursin("callback test", l), captured)
end

@testset "ExternalAgentTool — parse_result" begin
    t = ExternalAgentTool(
        name="echo_parse",
        description=".",
        command=["echo", "{task}"],
        args=["task" => CLIArg(String, "Task")],
        parse_result=lines -> "PARSED: " * join(lines, "|"),
    )
    result = NimbleAgents._run_external_agent(t, Dict{Symbol,Any}(:task => "raw output"))
    @test startswith(result, "PARSED:")
    @test occursin("raw output", result)
end

@testset "ExternalAgentTool — timeout" begin
    t = ExternalAgentTool(
        name="slow_agent",
        description=".",
        command=["sleep", "60"],
        args=Pair{String,CLIArg}[],
        timeout=0.3,
    )
    result = NimbleAgents._run_external_agent(t, Dict{Symbol,Any}())
    @test occursin("timed out", lowercase(result))
end

@testset "ExternalAgentTool — working_dir" begin
    t = ExternalAgentTool(
        name="pwd_agent",
        description=".",
        command=["pwd"],
        args=Pair{String,CLIArg}[],
        working_dir="/tmp",
    )
    result = NimbleAgents._run_external_agent(t, Dict{Symbol,Any}())
    @test occursin("tmp", result)
end

@testset "ExternalAgentTool — return_direct / return_artifact flags" begin
    t1 = ExternalAgentTool(
        name="a",
        description=".",
        command=["echo"],
        args=Pair{String,CLIArg}[],
        return_direct=true,
    )
    t2 = ExternalAgentTool(
        name="b",
        description=".",
        command=["echo"],
        args=Pair{String,CLIArg}[],
        return_artifact=true,
    )
    @test NimbleAgents._is_return_direct(t1) == true
    @test NimbleAgents._is_return_direct(t2) == false
    @test NimbleAgents._is_return_artifact(t1) == false
    @test NimbleAgents._is_return_artifact(t2) == true
end

@testset "ExternalAgentTool — dispatch_tool integration" begin
    t = ExternalAgentTool(
        name="echo_dispatch_ext",
        description=".",
        command=["echo", "{task}"],
        args=["task" => CLIArg(String, "Task")],
    )
    tool_map = build_tool_map([t])
    result = dispatch_tool(
        tool_map, "echo_dispatch_ext", Dict{Symbol,Any}(:task => "dispatch test")
    )
    @test occursin("dispatch test", result)
end

@testset "ExternalAgentTool — on_output error doesn't crash" begin
    t = ExternalAgentTool(
        name="echo_bad_cb",
        description=".",
        command=["echo", "{task}"],
        args=["task" => CLIArg(String, "Task")],
        on_output=line -> error("callback exploded"),
    )
    # Should complete without throwing, despite the broken callback
    result = NimbleAgents._run_external_agent(t, Dict{Symbol,Any}(:task => "still works"))
    @test occursin("still works", result)
end

@testset "claude_code_tool convenience constructor" begin
    t = claude_code_tool(model="sonnet", working_dir="/tmp", timeout=120.0, max_budget=1.0)
    @test t isa ExternalAgentTool
    @test t.name == "claude_code"
    @test t.working_dir == "/tmp"
    @test t.timeout == 120.0
    @test any(x -> x == "sonnet", t.command)
    @test any(x -> x == "stream-json", t.command)
    @test any(x -> x == "1.0", t.command)
    @test t.parse_result !== nothing
end

@testset "claude_code_tool — session_id flag" begin
    t = claude_code_tool(session_id="sess-abc-123")
    @test any(x -> x == "--session-id", t.command)
    idx = findfirst(x -> x == "--session-id", t.command)
    @test t.command[idx + 1] == "sess-abc-123"
    # --resume should NOT be present when session_id is set
    @test !any(x -> x == "--resume", t.command)
end

@testset "claude_code_tool — resume flag" begin
    t = claude_code_tool(resume=true)
    @test any(x -> x == "--resume", t.command)
    # --session-id should NOT be present
    @test !any(x -> x == "--session-id", t.command)
end

@testset "claude_code_tool — session_id takes precedence over resume" begin
    t = claude_code_tool(session_id="my-session", resume=true)
    @test any(x -> x == "--session-id", t.command)
    @test !any(x -> x == "--resume", t.command)
end

@testset "claude_code_tool — neither session_id nor resume" begin
    t = claude_code_tool()
    @test !any(x -> x == "--session-id", t.command)
    @test !any(x -> x == "--resume", t.command)
end

@testset "codex_tool convenience constructor" begin
    t = codex_tool(model="o4-mini", working_dir="/tmp")
    @test t isa ExternalAgentTool
    @test t.name == "codex"
    @test t.working_dir == "/tmp"
    @test any(x -> x == "o4-mini", t.command)
    @test any(x -> x == "-q", t.command)
end

@testset "_parse_claude_code_result" begin
    # Result line present
    lines = [
        """{"type":"assistant","message":{"content":[{"text":"Done"}]}}""",
        """{"type":"result","subtype":"success","result":"All tests pass","total_cost_usd":0.0042,"session_id":"abc123"}""",
    ]
    result = NimbleAgents._parse_claude_code_result(lines)
    @test occursin("All tests pass", result)
    @test occursin("0.0042", result)
    @test occursin("abc123", result)

    # Error result
    error_lines = [
        """{"type":"result","subtype":"error_max_turns","is_error":true,"result":"Hit max turns"}""",
    ]
    result = NimbleAgents._parse_claude_code_result(error_lines)
    @test occursin("Error", result)
    @test occursin("Hit max turns", result)

    # No result line — returns raw
    raw_lines = ["line 1", "line 2"]
    result = NimbleAgents._parse_claude_code_result(raw_lines)
    @test result == "line 1\nline 2"
end
