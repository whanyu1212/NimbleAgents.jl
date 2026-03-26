# examples/web/web_ui.jl
#
# Launch the NimbleAgents web UI with a few demo agents.
#
# Requires:
#   OPENAI_API_KEY or GOOGLE_API_KEY (GEMINI_API_KEY also works here) — for the LLM
#   TAVILY_API_KEY  — for real web search (https://tavily.com)
#
# Run from the repo root (multiple threads required for background agent tasks):
#   julia --project -t 4 examples/web/web_ui.jl
#
# Then open http://localhost:8080 in your browser.

using DotEnv
DotEnv.load!()

using NimbleAgents
using HTTP: HTTP
using JSON3: JSON3
using Dates: Dates

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

const EXAMPLE_MODEL = example_model()

# ── Tools ─────────────────────────────────────────────────────────────────────

# Real web search via Tavily API
@tool function search_web(query::String; max_results::Int=5)
    "Search the web for up-to-date information. Returns titles, URLs, and snippets."
    api_key = get(ENV, "TAVILY_API_KEY", "")
    isempty(api_key) && return "Error: TAVILY_API_KEY not set."

    resp = HTTP.post(
        "https://api.tavily.com/search",
        ["Authorization" => "Bearer $(api_key)", "Content-Type" => "application/json"],
        JSON3.write(
            Dict("query" => query, "max_results" => max_results, "include_answer" => true)
        );
        status_exception=false,
    )

    if resp.status != 200
        return "Search failed (HTTP $(resp.status)): $(String(resp.body))"
    end

    data = JSON3.read(resp.body)

    buf = IOBuffer()
    if !isempty(get(data, :answer, ""))
        println(buf, "Summary: ", data.answer, "\n")
    end
    for (i, r) in enumerate(get(data, :results, []))
        println(buf, "$(i). $(r.title)")
        println(buf, "   $(r.url)")
        println(buf, "   $(r.content)")
    end
    String(take!(buf))
end

# return_direct FAQ lookup — demonstrates short-circuit tool result
@tool return_direct=true function lookup_faq(topic::String)
    "Look up a frequently asked question. Returns a definitive answer directly."
    faqs = Dict(
        "refund" => "Refunds are processed within 5–7 business days.",
        "shipping" => "Standard shipping: 3–5 days. Express: 1–2 days.",
        "password" => "Click 'Forgot password' on the login page to reset.",
    )
    get(faqs, lowercase(topic), "No FAQ found for: $(topic)")
end

# ── Agents ────────────────────────────────────────────────────────────────────

# Plain chat agent — no tools, just conversation
chat_agent = Agent(;
    name="ChatBot",
    instructions="You are a helpful assistant. Answer questions clearly and concisely.",
    model=EXAMPLE_MODEL,
)

# Research agent — real web search via Tavily
research_agent = Agent(;
    name="ResearchBot",
    instructions="""
  You are a research assistant with access to real-time web search.
  Today's date is $(Dates.format(Dates.today(), "yyyy-mm-dd")).

  You have three tools:
  - search_web: find relevant URLs for a general query.
  - fetch_webpage: read the full text content of a specific URL.
  - github_trending: get today's trending GitHub repositories (supports
    filtering by language and time window: daily/weekly/monthly).

  For GitHub trending questions always use github_trending, not search_web.

  Always cite the URLs you used. Critically evaluate retrieved content —
  some pages contain AI-generated or cached text that may be outdated or
  fabricated. Synthesize across sources rather than reproducing content verbatim.
  """,
    tools=[search_web_tool, fetch_webpage_tool, github_trending_tool],
    model=EXAMPLE_MODEL,
)

# Filesystem agent — reads and explores files on disk (HITL before writes)
fs_agent = Agent(;
    name="FilesystemBot",
    instructions="""
  You are a filesystem assistant. You can read files, list directories,
  and search for content. Always show the user what you find.
  """,
    tools=[read_file_tool, list_dir_tool, glob_tool, grep_tool],
    model=EXAMPLE_MODEL,
)

# Support agent — demonstrates return_direct: FAQ hits bypass the LLM entirely
support_agent = Agent(;
    name="SupportBot",
    instructions="""
  You are a customer support assistant. For known topics (refund, shipping,
  password) use lookup_faq — the answer is returned directly without further
  processing. For anything else, use search_web.
  """,
    tools=[lookup_faq_tool, search_web_tool],
    model=EXAMPLE_MODEL,
)

# ── Launch ────────────────────────────────────────────────────────────────────

serve([chat_agent, research_agent, fs_agent, support_agent]; port=8080)
