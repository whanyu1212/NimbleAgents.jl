# examples/web_ui.jl
#
# Launch the NimbleAgents web UI with a few demo agents.
#
# Run from the project root (multiple threads required for background agent tasks):
#   julia --project=. -t 4 examples/web_ui.jl
#
# Then open http://localhost:8080 in your browser.

using DotEnv
DotEnv.load!()

using NimbleAgents

# ── Tools ─────────────────────────────────────────────────────────────────────

@tool function search_web(query::String)
    "Search the web for information on a topic."
    "[SIMULATED] Search results for '$(query)': Found 3 relevant articles."
end

@tool function get_weather(city::String)
    "Get the current weather for a city."
    "[SIMULATED] Weather in $(city): 22°C, partly cloudy."
end

@tool function send_email(to::String, subject::String, body::String)
    "Send an email to a recipient."
    "[SIMULATED] Email sent to $(to): $(subject)"
end

@tool function delete_file(path::String)
    "Permanently delete a file."
    "[SIMULATED] Deleted: $(path)"
end

@tool return_direct=true function lookup_faq(topic::String)
    "Look up a frequently asked question. Returns a definitive answer."
    faqs = Dict(
        "refund"   => "Refunds are processed within 5–7 business days.",
        "shipping" => "Standard shipping: 3–5 days. Express: 1–2 days.",
        "password" => "Click 'Forgot password' on the login page to reset.",
    )
    get(faqs, lowercase(topic), "No FAQ found for: $(topic)")
end

# ── Agents ────────────────────────────────────────────────────────────────────

# Plain chat agent
chat_agent = Agent(
    name         = "ChatBot",
    instructions = "You are a helpful assistant. Answer questions clearly and concisely.",
    model        = "gpt-4o-mini",
)

# Agent with tools
research_agent = Agent(
    name         = "ResearchBot",
    instructions = """
    You are a research assistant. Use search_web to find information and
    get_weather for weather queries. Always cite your sources.
    """,
    tools = [search_web_tool, get_weather_tool],
    model = "gpt-4o-mini",
)

# Agent with HITL — dangerous tools require approval
ops_agent = Agent(
    name         = "OpsBot",
    instructions = """
    You are an operations assistant. You can send emails and delete files.
    Always confirm the details before taking action.
    """,
    tools = [send_email_tool, delete_file_tool, search_web_tool],
    model = "gpt-4o-mini",
    hooks = AgentHooks(
        should_interrupt = (name, args) -> name in ["send_email", "delete_file"]
    ),
)

# Agent with return_direct
support_agent = Agent(
    name         = "SupportBot",
    instructions = """
    You are a customer support assistant. Use lookup_faq for known topics
    (refund, shipping, password). Search the web for anything else.
    """,
    tools = [lookup_faq_tool, search_web_tool],
    model = "gpt-4o-mini",
)

# ── Launch ────────────────────────────────────────────────────────────────────

serve([chat_agent, research_agent, ops_agent, support_agent]; port=8080)
