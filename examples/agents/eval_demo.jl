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

function example_model(; tier::Symbol=:mini)
    if isempty(get(ENV, "GOOGLE_API_KEY", "")) && !isempty(get(ENV, "GEMINI_API_KEY", ""))
        ENV["GOOGLE_API_KEY"] = ENV["GEMINI_API_KEY"]
    end

    override = strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_MODEL", ""))
    !isempty(override) && return override

    openai_model, gemini_model = if tier === :nano
        ("gpt-5.4-nano-2026-03-17", "gemini-2.5-flash-lite")
    else
        ("gpt-5.4-mini", "gemini-2.5-flash")
    end

    provider = lowercase(strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_PROVIDER", "")))
    provider == "openai" && return openai_model
    provider == "gemini" && return gemini_model
    !isempty(provider) && error(
        "Unsupported NIMBLEAGENTS_EXAMPLE_PROVIDER=$(provider). Use 'openai' or 'gemini'.",
    )

    !isempty(get(ENV, "OPENAI_API_KEY", "")) && return openai_model
    !isempty(get(ENV, "GOOGLE_API_KEY", "")) && return gemini_model

    error(
        "Set OPENAI_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY, or set NIMBLEAGENTS_EXAMPLE_MODEL.",
    )
end

const EXAMPLE_MODEL = example_model(; tier=:nano)

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
    model=EXAMPLE_MODEL,
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
