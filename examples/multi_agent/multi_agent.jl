# examples/multi_agent.jl
#
# Demonstrates two multi-agent patterns:
#
#   1. agent_as_tool  — orchestrator calls specialist subagents as tools
#   2. run_pipeline!  — triage agent hands off to a specialist via handoff_tool
#
# Run from the project root:
#   julia --project=. examples/multi_agent.jl

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

const EXAMPLE_MODEL = example_model()

divider(c='─', n=60) = println(c ^ n)

# ── Shared tools ───────────────────────────────────────────────────────────────

@tool function add(x::Int, y::Int)
    "Add two integers."
    x + y
end

@tool function multiply(x::Int, y::Int)
    "Multiply two integers."
    x * y
end

@tool function word_count(text::String)
    "Count the number of words in a text string."
    length(split(strip(text)))
end

@tool function reverse_words(text::String)
    "Reverse the order of words in a sentence."
    join(reverse(split(strip(text))), " ")
end

# ══════════════════════════════════════════════════════════════════════════════
# Pattern 1: agent_as_tool
#
# An orchestrator that delegates to a math specialist and a text specialist.
# Each subagent has its own tools, instructions, and hooks.
# ══════════════════════════════════════════════════════════════════════════════

println()
divider('═')
println("  Pattern 1: agent_as_tool")
divider('═')

math_hooks = AgentHooks(;
    on_complete=(ag, result) -> println("  [$(ag.name) on_complete] result = $(result)")
)

text_hooks = AgentHooks(;
    on_complete=(ag, result) -> println("  [$(ag.name) on_complete] result = $(result)")
)

math_agent = Agent(;
    name="MathAgent",
    instructions="You are a math specialist. Always use tools to compute answers.",
    tools=[add_tool, multiply_tool],
    model=EXAMPLE_MODEL,
    hooks=math_hooks,
)

text_agent = Agent(;
    name="TextAgent",
    instructions="You are a text processing specialist. Use tools for all text operations.",
    tools=[word_count_tool, reverse_words_tool],
    model=EXAMPLE_MODEL,
    hooks=text_hooks,
)

session = Session(; app_name="MultiAgentDemo")

orchestrator = Agent(;
    name="Orchestrator",
    instructions="""You are an orchestrator. Delegate every task to the right specialist:
- Use MathAgent for anything involving numbers or arithmetic.
- Use TextAgent for anything involving text manipulation or analysis.
Never answer directly — always delegate.""",
    tools=[
        agent_as_tool(math_agent; session=session),
        agent_as_tool(text_agent; session=session),
    ],
    model=EXAMPLE_MODEL,
)

questions = [
    "What is 12 multiplied by 7?",
    "How many words are in 'the quick brown fox jumps'?",
    "What is 25 + 38?",
]

for (i, q) in enumerate(questions)
    println()
    divider()
    println("  Q$(i): $(q)")
    divider()
    answer = run!(orchestrator, q; session=session, verbose=false)
    println("  Answer: $(answer)")
end

println()
println("  Session events recorded: $(length(session.events))")

# ══════════════════════════════════════════════════════════════════════════════
# Pattern 2: run_pipeline! with handoff_tool
#
# A triage agent decides which specialist should handle the request, then
# hands off using handoff_tool. The specialist resolves it and returns.
# ══════════════════════════════════════════════════════════════════════════════

println()
divider('═')
println("  Pattern 2: run_pipeline! with handoff_tool")
divider('═')

billing_agent = Agent(;
    name="BillingAgent",
    instructions="You handle billing and payment questions. Be concise and direct.",
    tools=Tool[],
    model=EXAMPLE_MODEL,
)

tech_agent = Agent(;
    name="TechAgent",
    instructions="You handle technical support questions. Be concise and direct.",
    tools=Tool[],
    model=EXAMPLE_MODEL,
)

triage_agent = Agent(;
    name="TriageAgent",
    instructions="""You are a customer service triage agent.
Route every incoming request to the correct specialist using handoff tools.
- Billing questions (invoices, payments, subscriptions) → BillingAgent
- Technical questions (bugs, errors, setup, features) → TechAgent
Always hand off — never answer directly.""",
    tools=[handoff_tool(billing_agent), handoff_tool(tech_agent)],
    model=EXAMPLE_MODEL,
)

pipeline_session = Session(; app_name="PipelineDemo")

requests = [
    "I was charged twice for my subscription this month.",
    "My API key is not working — I keep getting a 401 error.",
]

for (i, req) in enumerate(requests)
    println()
    divider()
    println("  Request $(i): $(req)")
    divider()
    response = run_pipeline!(
        triage_agent, req; session=pipeline_session, verbose=true, max_handoffs=5
    )
    println()
    println("  Final response: $(response)")
end

println()
divider('═')
println("  Pipeline session events: $(length(pipeline_session.events))")
divider('═')
println()
