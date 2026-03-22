@testset "CLIArg" begin
    arg = CLIArg(String, "A file path"; required=true)
    @test arg.type == String
    @test arg.description == "A file path"
    @test arg.required == true

    opt = CLIArg(Int, "Max results"; required=false)
    @test opt.required == false
end

@testset "CLITool construction" begin
    t = CLITool(
        name="echo_tool",
        description="Echo a message.",
        command=["echo", "{msg}"],
        args=["msg" => CLIArg(String, "Message to echo")],
    )

    @test t isa CLITool
    @test t.name == "echo_tool"
    @test t.description == "Echo a message."
    @test t.command == ["echo", "{msg}"]
    @test length(t.args) == 1
    @test t.args[1].first == "msg"
    @test t.timeout == 30.0
    @test t.return_direct == false
    @test t.return_artifact == false
end

@testset "CLITool schema" begin
    t = CLITool(
        name="grep_cli",
        description="Search.",
        command=["grep", "-rn", "{pattern}", "{path}"],
        args=[
            "pattern" => CLIArg(String, "Regex pattern"),
            "path" => CLIArg(String, "Directory to search"),
        ],
    )

    schema = NimbleAgents._cli_schema(t.args)
    @test schema["type"] == "object"
    @test haskey(schema["properties"], "pattern")
    @test haskey(schema["properties"], "path")
    @test schema["properties"]["pattern"]["type"] == "string"
    @test sort(schema["required"]) == ["path", "pattern"]
end

@testset "CLITool schema — optional args excluded from required" begin
    t = CLITool(
        name="search",
        description="Search.",
        command=["grep", "{pattern}"],
        args=[
            "pattern" => CLIArg(String, "Pattern"; required=true),
            "max" => CLIArg(Int, "Limit"; required=false),
        ],
    )
    schema = NimbleAgents._cli_schema(t.args)
    @test "pattern" in schema["required"]
    @test !("max" in schema["required"])
end

@testset "_render_command — placeholder substitution" begin
    t = CLITool(
        name="cp_tool",
        description="Copy.",
        command=["cp", "{src}", "{dst}"],
        args=["src" => CLIArg(String, "Source"), "dst" => CLIArg(String, "Destination")],
    )
    cmd = NimbleAgents._render_command(t, Dict{Symbol,Any}(:src => "/a/b", :dst => "/c/d"))
    @test collect(cmd) == ["cp", "/a/b", "/c/d"]
end

@testset "CLITool execution via dispatch_tool" begin
    t = CLITool(
        name="echo_dispatch",
        description="Echo test.",
        command=["echo", "{msg}"],
        args=["msg" => CLIArg(String, "Message")],
    )
    tool_map = build_tool_map([t])
    result = dispatch_tool(tool_map, "echo_dispatch", Dict{Symbol,Any}(:msg => "hello"))
    @test occursin("hello", result)
end

@testset "CLITool — working_dir" begin
    t = CLITool(
        name="pwd_tool",
        description="Print working dir.",
        command=["pwd"],
        args=Pair{String,CLIArg}[],
        working_dir="/tmp",
    )
    result = NimbleAgents._run_cli(t, Dict{Symbol,Any}())
    @test occursin("tmp", result)
end

@testset "CLITool — return_direct / return_artifact flags" begin
    t1 = CLITool(
        name="a",
        description=".",
        command=["echo"],
        args=Pair{String,CLIArg}[],
        return_direct=true,
    )
    t2 = CLITool(
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

@testset "CLITool — timeout" begin
    t = CLITool(
        name="slow",
        description=".",
        command=["sleep", "60"],
        args=Pair{String,CLIArg}[],
        timeout=0.3,
    )
    result = NimbleAgents._run_cli(t, Dict{Symbol,Any}())
    @test occursin("timed out", lowercase(result))
end
