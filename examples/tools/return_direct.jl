# examples/return_direct.jl
#
# Demonstrates return_direct=true on tools.
#
# When a tool is marked return_direct=true, the agent loop short-circuits
# immediately after that tool executes — its return value becomes the final
# output without any further LLM call.
#
# Use cases:
#   • Cache/lookup hits — answer is definitive, no LLM synthesis needed
#   • FAQ databases — tool returns the exact answer
#   • Rule-based routing — tool determines the next step, no LLM judgment needed
#   • Cost control — skip the final LLM call when the tool result is self-contained
#
# Run from the project root:
#   julia --project=. examples/return_direct.jl

using DotEnv
DotEnv.load!()

using NimbleAgents
import Term: Panel, tprintln

function example_model(; tier::Symbol=:mini)
    if isempty(get(ENV, "GOOGLE_API_KEY", "")) && !isempty(get(ENV, "GEMINI_API_KEY", ""))
        ENV["GOOGLE_API_KEY"] = ENV["GEMINI_API_KEY"]
    end

    override = strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_MODEL", ""))
    !isempty(override) && return override

    openai_model, gemini_model = tier === :nano ?
        ("gpt-5.4-nano-2026-03-17", "gemini-2.5-flash-lite") :
        ("gpt-5.4-mini", "gemini-2.5-flash")

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

# ── Example 1 — FAQ lookup ────────────────────────────────────────────────────
#
# The LLM calls lookup_faq. Because return_direct=true, the tool's answer is
# returned immediately — the LLM never gets to rephrase or summarise it.

const FAQ = Dict(
    "refund" => "Refunds are processed within 5–7 business days.",
    "shipping" => "Standard shipping takes 3–5 business days. Express is 1–2.",
    "password" => "Click 'Forgot password' on the login page to reset.",
)

@tool return_direct=true function lookup_faq(topic::String)
    "Look up a frequently asked question by topic keyword. Returns a definitive answer."
    get(FAQ, lowercase(topic), "No FAQ found for topic: $(topic)")
end

@tool function search_web(query::String)
    "Search the web for general information."
    "[SIMULATED] Web results for: $(query)"
end

tprintln(
    Panel(
        "Example 1 — FAQ lookup\n" *
        "lookup_faq is return_direct=true.\n" *
        "The LLM calls it, its answer is returned immediately.";
        title="return_direct",
        style="cyan",
        padding=(1, 2, 1, 2),
    ),
)

faq_agent = Agent(;
    name="SupportBot",
    instructions="""
  You are a customer support assistant. Use lookup_faq for specific support
  topics (refund, shipping, password). Use search_web for anything else.
  """,
    tools=[lookup_faq_tool, search_web_tool],
    model=EXAMPLE_MODEL,
)

result1 = run!(faq_agent, "How long do refunds take?"; verbose=false)
println("Result: ", result1, "\n")

result2 = run!(faq_agent, "What are your shipping options?"; verbose=false)
println("Result: ", result2, "\n")

# ── Example 2 — normal vs return_direct side by side ─────────────────────────
#
# Same tool, return_direct toggled. Without it the LLM wraps the answer in a
# sentence. With it, the raw tool output is returned as-is.

tprintln(
    Panel(
        "Example 2 — normal vs return_direct side by side\n" *
        "Same tool content, different agent behaviour.";
        title="return_direct",
        style="yellow",
        padding=(1, 2, 1, 2),
    ),
)

@tool function get_price_normal(product::String)
    "Get the current price of a product."
    "Price of $(product): \$49.99"
end

@tool return_direct=true function get_price_direct(product::String)
    "Get the current price of a product. Returns the definitive price string."
    "Price of $(product): \$49.99"
end

agent_normal = Agent(;
    name="PriceBot-Normal",
    instructions="You answer product pricing questions.",
    tools=[get_price_normal_tool],
    model=EXAMPLE_MODEL,
)

agent_direct = Agent(;
    name="PriceBot-Direct",
    instructions="You answer product pricing questions.",
    tools=[get_price_direct_tool],
    model=EXAMPLE_MODEL,
)

r_normal = run!(agent_normal, "How much does the Widget cost?"; verbose=false)
r_direct = run!(agent_direct, "How much does the Widget cost?"; verbose=false)

println("Normal (LLM wraps result):   ", r_normal)
println("Direct (raw tool output):    ", r_direct, "\n")

# ── Example 3 — return_direct with session ────────────────────────────────────
#
# return_direct still writes to session history so subsequent turns have context.

tprintln(
    Panel(
        "Example 3 — return_direct with session\n" *
        "Short-circuit result is still recorded in session history.";
        title="return_direct",
        style="magenta",
        padding=(1, 2, 1, 2),
    ),
)

session = Session(; app_name="return_direct_demo", user_id="user")

run!(faq_agent, "What is the refund policy?"; session=session, verbose=false)
follow_up = run!(
    faq_agent, "Can you summarise what you just told me?"; session=session, verbose=false
)

println("Follow-up (has context from return_direct turn):")
println(follow_up, "\n")
