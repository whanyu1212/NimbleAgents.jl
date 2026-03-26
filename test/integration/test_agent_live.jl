using Test
using DotEnv
using NimbleAgents

DotEnv.load!()

@testset "Live agent run! integration" begin
    has_openai = !isempty(get(ENV, "OPENAI_API_KEY", ""))
    has_google = !isempty(get(ENV, "GOOGLE_API_KEY", ""))

    if !(has_openai || has_google)
        @test_skip "Skipping live integration: set OPENAI_API_KEY or GOOGLE_API_KEY."
        return nothing
    end

    @tool function add(x::Int, y::Int)
        "Add two integers together."
        x + y
    end

    @tool function multiply(x::Int, y::Int)
        "Multiply two integers together."
        x * y
    end

    @tool function to_uppercase(text::String)
        "Convert a string to uppercase."
        uppercase(text)
    end

    model = has_openai ? "gpt-5.4-mini" : "gemini-2.5-flash"
    agent = Agent(;
        name="MathBot",
        model=model,
        instructions="""You are a helpful assistant that can do arithmetic and string operations.
Always use tools to compute answers rather than doing the math yourself.""",
        tools=[add_tool, multiply_tool, to_uppercase_tool],
    )

    prompts = [
        "What is 12 + 7?",
        "What is (3 + 5) * 10? Then convert the word 'result' to uppercase.",
    ]

    for prompt in prompts
        response = run!(agent, prompt; verbose=false)
        @test response isa String
        @test !isempty(strip(response))
    end
end
