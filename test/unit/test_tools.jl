@tool function add(x::Int, y::Int)
    "Add two integers and return the result."
    x + y
end

@tool function greet(name::String)
    "Return a greeting for the given name."
    "Hello, $(name)!"
end

@testset "Tool system" begin

    # ── @tool macro creates a Tool with correct metadata ──────────────────
    @test add_tool isa Tool
    @test add_tool.name == "add"
    @test add_tool.description == "Add two integers and return the result."
    @test haskey(add_tool.parameters, "properties")
    @test haskey(add_tool.parameters["properties"], "x")
    @test haskey(add_tool.parameters["properties"], "y")

    # ── underlying function still works normally ───────────────────────────
    @test add(2, 3) == 5

    # ── build_tool_map ────────────────────────────────────────────────────
    tool_map = build_tool_map([add_tool, greet_tool])
    @test tool_map isa Dict{String, AbstractTool}
    @test haskey(tool_map, "add")
    @test haskey(tool_map, "greet")

    # ── tools_schema produces OpenAI-compatible structure ─────────────────
    schema = tools_schema([add_tool, greet_tool])
    @test schema isa Vector
    @test length(schema) == 2
    for entry in schema
        @test entry["type"] == "function"
        @test haskey(entry["function"], "name")
        @test haskey(entry["function"], "parameters")
        @test haskey(entry["function"], "description")
    end

    # ── dispatch_tool calls the function with Symbol-keyed args ───────────
    result = dispatch_tool(tool_map, "add", Dict{Symbol, Any}(:x => 10, :y => 32))
    @test result == 42

    result2 = dispatch_tool(tool_map, "greet", Dict{Symbol, Any}(:name => "Alice"))
    @test result2 == "Hello, Alice!"

    # ── dispatch_tool raises on unknown tool ──────────────────────────────
    @test_throws Exception dispatch_tool(tool_map, "nonexistent", Dict{Symbol, Any}())
end
