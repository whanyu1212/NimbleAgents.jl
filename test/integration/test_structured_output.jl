using Test
using DotEnv
using NimbleAgents

DotEnv.load!()

struct WeatherReport
    "Structured weather data for a location"
    location::String
    temperature_f::Float64
    condition::String
    humidity_pct::Union{Int,Nothing}
end

struct MathResult
    "Result of a math calculation"
    expression::String
    result::Float64
    explanation::Union{String,Nothing}
end

@testset "Live structured output integration" begin
    has_openai = !isempty(get(ENV, "OPENAI_API_KEY", ""))
    has_google = !isempty(get(ENV, "GOOGLE_API_KEY", ""))

    if !(has_openai || has_google)
        @test_skip "Skipping live integration: set OPENAI_API_KEY or GOOGLE_API_KEY."
        return
    end

    model = has_openai ? "gpt-5.4-mini" : "gemini-2.5-flash"

    weather_agent = Agent(;
        name="WeatherExtractor",
        model=model,
        instructions="Extract structured weather information from the user's message.",
        output_type=WeatherReport,
    )

    report = run!(
        weather_agent,
        "It's currently 68°F, partly cloudy in San Francisco with 72% humidity.";
        verbose=false,
    )
    @test report isa WeatherReport
    @test lowercase(report.location) == "san francisco"
    @test 60.0 <= report.temperature_f <= 80.0
    @test report.humidity_pct == 72

    @tool function add(x::Int, y::Int)
        "Add two integers together."
        x + y
    end

    @tool function multiply(x::Int, y::Int)
        "Multiply two integers together."
        x * y
    end

    math_agent = Agent(;
        name="MathExtractor",
        model=model,
        instructions="""You are a math assistant. Use tools to compute results.
After computing, return a structured MathResult with the expression and result.""",
        tools=[add_tool, multiply_tool],
        output_type=MathResult,
    )

    result = run!(math_agent, "What is (4 + 6) * 3?"; verbose=false)
    @test result isa MathResult
    @test result.result == 30.0
end
