# Tests for return_direct on NimbleTool / @tool macro
# Fixtures (rd_normal_tool, rd_direct_tool, rd_implicit_tool) are defined
# at module scope in runtests.jl to avoid Julia arg-name mangling in closures.

@testset "return_direct — NimbleTool struct" begin
    @test rd_normal_tool isa NimbleTool
    @test rd_direct_tool isa NimbleTool

    @test rd_normal_tool.return_direct == false
    @test rd_direct_tool.return_direct == true

    @test rd_normal_tool.name == "rd_normal"
    @test rd_direct_tool.name == "rd_direct"
    @test rd_normal_tool.callable(3) == 6
    @test rd_direct_tool.callable(3) == 300
end

@testset "return_direct — _is_return_direct helper" begin
    @test NimbleAgents._is_return_direct(rd_direct_tool) == true
    @test NimbleAgents._is_return_direct(rd_normal_tool) == false

    # PT.Tool (third-party tools) always returns false
    import PromptingTools as PT
    pt_tool = PT.Tool(;
        name="pt",
        parameters=Dict{String,Any}("type"=>"object", "properties"=>Dict()),
        description="A PT tool",
        callable=identity,
    )
    @test NimbleAgents._is_return_direct(pt_tool) == false
end

@testset "return_direct — build_tool_map includes NimbleTool" begin
    tool_map = build_tool_map([rd_normal_tool, rd_direct_tool])
    @test haskey(tool_map, "rd_normal")
    @test haskey(tool_map, "rd_direct")
    @test NimbleAgents._is_return_direct(tool_map["rd_direct"]) == true
    @test NimbleAgents._is_return_direct(tool_map["rd_normal"]) == false
end

@testset "return_direct — dispatch_tool still works" begin
    tool_map = build_tool_map([rd_normal_tool, rd_direct_tool])
    @test dispatch_tool(tool_map, "rd_normal", Dict{Symbol,Any}(:x => 5)) == 10
    @test dispatch_tool(tool_map, "rd_direct", Dict{Symbol,Any}(:x => 5)) == 500
end

@testset "return_direct — default is false" begin
    @test rd_implicit_tool.return_direct == false
end
