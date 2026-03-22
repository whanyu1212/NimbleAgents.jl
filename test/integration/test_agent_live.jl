using DotEnv
DotEnv.load!()

using NimbleAgents

# ── Define some simple tools ──────────────────────────────────────────────────

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

# ── Build the agent ───────────────────────────────────────────────────────────

agent = Agent(;
    name="MathBot",
    instructions="""You are a helpful assistant that can do arithmetic and string operations.
Always use tools to compute answers rather than doing the math yourself.""",
    tools=[add_tool, multiply_tool, to_uppercase_tool],
)

println("=" ^ 60)
println("Agent: $(agent.name)")
println("Model: $(agent.model)")
println("Tools: $(join([t.name for t in agent.tools], ", "))")
println("=" ^ 60)

# ── Run 3 conversations ───────────────────────────────────────────────────────

prompts = [
    "What is 12 + 7?",
    "What is 6 multiplied by 9, and then add 4 to the result?",
    "What is (3 + 5) * 10? Then convert the word 'result' to uppercase.",
]

for (i, prompt) in enumerate(prompts)
    println("\n[$i] User: $prompt")
    response = run!(agent, prompt)
    println("[$i] Agent: $response")
    println("-" ^ 60)
end
