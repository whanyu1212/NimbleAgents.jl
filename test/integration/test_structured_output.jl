using DotEnv
DotEnv.load!()

using NimbleAgents

# ── Output types ──────────────────────────────────────────────────────────────

struct WeatherReport
    "Structured weather data for a location"
    location::String
    temperature_f::Float64
    condition::String
    humidity_pct::Union{Int, Nothing}
end

struct MathResult
    "Result of a math calculation"
    expression::String
    result::Float64
    explanation::Union{String, Nothing}
end

# ── Test 1: Pure extraction (no tools) ───────────────────────────────────────

println("=" ^ 60)
println("Test 1: Structured extraction (no tools)")
println("=" ^ 60)

weather_agent = Agent(
    name         = "WeatherExtractor",
    instructions = "Extract structured weather information from the user's message.",
    output_type  = WeatherReport,
)

report = run!(weather_agent, "It's currently 68°F, partly cloudy in San Francisco with 72% humidity.")
println("Type:          ", typeof(report))
println("Location:      ", report.location)
println("Temperature:   ", report.temperature_f, "°F")
println("Condition:     ", report.condition)
println("Humidity:      ", report.humidity_pct, "%")

# ── Test 2: Tools + structured output ────────────────────────────────────────

println("\n", "=" ^ 60)
println("Test 2: Tools + structured output")
println("=" ^ 60)

@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end

@tool function multiply(x::Int, y::Int)
    "Multiply two integers together."
    x * y
end

math_agent = Agent(
    name         = "MathExtractor",
    instructions = """You are a math assistant. Use tools to compute results.
After computing, return a structured MathResult with the expression and result.""",
    tools        = [add_tool, multiply_tool],
    output_type  = MathResult,
)

result = run!(math_agent, "What is (4 + 6) * 3?")
println("Type:        ", typeof(result))
println("Expression:  ", result.expression)
println("Result:      ", result.result)
println("Explanation: ", result.explanation)
