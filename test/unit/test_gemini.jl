###############################################################################
# test_gemini.jl — unit tests for GeminiOpenAISchema
###############################################################################

import PromptingTools as PT

@testset "GeminiOpenAISchema — type hierarchy" begin
    schema = GeminiOpenAISchema()
    @test schema isa PT.AbstractOpenAISchema
    @test schema isa PT.AbstractPromptSchema
end

@testset "GeminiOpenAISchema — model registry" begin
    # Gemini models should be registered with GeminiOpenAISchema
    for model in ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash-lite",
                   "gemini-3-flash-preview", "gemini-1.5-pro"]
        @test haskey(PT.MODEL_REGISTRY, model)
        spec = PT.MODEL_REGISTRY[model]
        @test spec.schema isa GeminiOpenAISchema
    end
end

@testset "GeminiOpenAISchema — base URL" begin
    @test NimbleAgents._GEMINI_BASE_URL == "https://generativelanguage.googleapis.com/v1beta/openai"
    # Verify this differs from PT's broken URL
    @test NimbleAgents._GEMINI_BASE_URL != "https://generativelanguage.googleapis.com/v1beta"
end

@testset "GeminiOpenAISchema — message rendering inherits from AbstractOpenAISchema" begin
    schema = GeminiOpenAISchema()
    msgs = PT.AbstractMessage[
        PT.SystemMessage("You are helpful."),
        PT.UserMessage("Hello"),
    ]
    rendered = PT.render(schema, msgs)
    @test length(rendered) == 2
    @test rendered[1]["role"] == "system"
    @test rendered[1]["content"] == "You are helpful."
    @test rendered[2]["role"] == "user"
    @test rendered[2]["content"] == "Hello"
end

@testset "GeminiOpenAISchema — tool rendering inherits from AbstractOpenAISchema" begin
    schema = GeminiOpenAISchema()
    tool = NimbleTool(
        name = "test_tool",
        description = "A test tool",
        parameters = Dict{String,Any}(
            "type" => "object",
            "properties" => Dict{String,Any}(
                "x" => Dict{String,Any}("type" => "integer", "description" => "A number"),
            ),
            "required" => ["x"],
        ),
        callable = (x::Int) -> x * 2,
    )
    rendered = PT.render(schema, [tool])
    @test length(rendered) == 1
    @test rendered[1][:type] == "function"
    @test rendered[1][:function][:name] == "test_tool"
    @test rendered[1][:function][:description] == "A test tool"
end
