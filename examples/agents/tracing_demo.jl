# examples/agents/tracing_demo.jl
#
# Demonstrates the NimbleAgents tracer — inspect everything that happened
# after an agent run without any instrumentation upfront.
#
# Shows:
#   - Running a multi-turn session with a tool-calling agent
#   - Building a Trace from the session after the fact
#   - Inspecting the trace programmatically
#   - Printing a human-readable summary
#   - Saving the trace to JSON for offline analysis
#
# Run from the repo root:
#   julia --project examples/agents/tracing_demo.jl

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

@tool function to_words(n::Int)
    "Convert a small integer to its English word representation."
    words = ["zero","one","two","three","four","five","six","seven",
             "eight","nine","ten","eleven","twelve"]
    1 <= n <= length(words) ? words[n] : "$(n)"
end

# ── Set up agent and session ──────────────────────────────────────────────────

agent = Agent(
    name         = "MathBot",
    instructions = "You are a helpful maths assistant. Use the available tools to compute answers.",
    tools        = [add_tool, multiply_tool, to_words_tool],
    model        = "gpt-5.4-nano-2026-03-17",
)

session = Session(app_name="TracingDemo", user_id="alice")

# ── Run a few turns ───────────────────────────────────────────────────────────

println("=== Running agent ===\n")

run!(agent, "What is 6 + 7?"; session=session)
run!(agent, "Now multiply that by 3."; session=session)
run!(agent, "Convert the final result to words."; session=session)

# ── Build the trace ───────────────────────────────────────────────────────────

trace = Trace(session)

# ── Programmatic inspection ───────────────────────────────────────────────────

println("\n=== Programmatic inspection ===\n")

println("Number of turns   : ", length(trace.turns))
println("Agents involved   : ", join(trace.agents, ", "))
println("Total tokens used : ", trace.total_tokens,
        " (", trace.total_input_tokens, " in / ", trace.total_output_tokens, " out)")
println("Total cost        : \$", round(trace.total_cost; digits=4))
println("Total LLM calls   : ", trace.total_llm_calls)
println("Total tool calls  : ", trace.total_tool_calls)
println("Total duration    : ", round(trace.duration; digits=2), "s")

println("\nPer-turn breakdown:")
for (i, turn) in enumerate(trace.turns)
    println("  Turn $(i): \"$(turn.input)\"")
    println("    → $(turn.output)")
    println("    tokens: $(turn.input_tokens + turn.output_tokens) | ",
            "cost: \$$(round(turn.cost; digits=4)) | ",
            "elapsed: $(round(turn.elapsed; digits=2))s")
    for te in turn.tool_calls
        status = isnothing(te.error) ? "✓" : "✗"
        args_str = join(["$(k)=$(v)" for (k,v) in te.args], ", ")
        println("    $(status) $(te.name)($(args_str)) → $(te.result)")
    end
end

# ── Human-readable summary ────────────────────────────────────────────────────

println("\n=== print_trace ===")
print_trace(trace)

# ── Save to JSON ──────────────────────────────────────────────────────────────

println("=== Saving trace ===")
save_trace(trace, "tracing_demo_output.json")
println("Open tracing_demo_output.json to inspect the full structured trace.")
