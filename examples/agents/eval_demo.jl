# examples/agents/eval_demo.jl
#
# Demonstrates the NimbleAgents eval harness — run an agent against a set of
# known test cases and score the results with built-in metrics.
#
# Shows:
#   - Defining EvalCase test cases with expected answers and tool trajectories
#   - Running run_eval with multiple metrics
#   - Printing a human-readable eval report
#   - Saving the report to JSON for offline analysis
#   - Using factory metrics (cost_budget, latency_budget)
#
# Run from the repo root:
#   julia --project examples/agents/eval_demo.jl

using DotEnv
DotEnv.load!()

using NimbleAgents

# ── Define tools ─────────────────────────────────────────────────────────────

@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end

@tool function multiply(x::Int, y::Int)
    "Multiply two integers together."
    x * y
end

# ── Set up agent ─────────────────────────────────────────────────────────────

agent = Agent(;
    name="MathBot",
    instructions="""You are a precise maths assistant. Use the available tools to compute answers.
Always respond with ONLY the numeric result — no extra words.""",
    tools=[add_tool, multiply_tool],
    model="gpt-5.4-nano-2026-03-17",
)

# ── Define eval cases ────────────────────────────────────────────────────────

cases = [
    EvalCase(;
        input="What is 2 + 3?", expected="5", expected_tools=["add"], tags=["addition"]
    ),
    EvalCase(;
        input="What is 4 * 7?",
        expected="28",
        expected_tools=["multiply"],
        tags=["multiplication"],
    ),
    EvalCase(;
        input="What is 10 + 5?", expected="15", expected_tools=["add"], tags=["addition"]
    ),
    EvalCase(;
        input="What is 6 * 9?",
        expected="54",
        expected_tools=["multiply"],
        tags=["multiplication"],
    ),
]

# ── Run eval with built-in metrics ───────────────────────────────────────────

println("=== Running eval ($(length(cases)) cases) ===\n")

report = run_eval(
    agent,
    cases;
    metrics=[
        exact_match,
        fuzzy_match,
        tool_trajectory,
        tool_coverage,
        cost_budget(0.01),
        latency_budget(30.0),
    ],
)

# ── Print the report ─────────────────────────────────────────────────────────

print_eval(report)

# ── Save to JSON ─────────────────────────────────────────────────────────────

save_eval(report, "eval_demo_output.json")
println("Open eval_demo_output.json to inspect the full structured results.")
