# examples/research_pipeline.jl
#
# A full multi-agent research pipeline illustrating all three subagent primitives:
#
#   1. spawn_subagents — QueryPlanner generates one sharp search query per sub-topic
#   2. fan_out         — TopicResearcher runs in parallel using the planned queries
#   3. spawn_subagents — Drafter → Editor sequential writing pipeline
#   (bonus) sub_agents — TriageAgent wiring shown at the end
#
# Requires OPENAI_API_KEY and TAVILY_API_KEY in .env
#
# Run from the project root:
#   julia --project=. examples/research_pipeline.jl

using DotEnv
DotEnv.load!()

using NimbleAgents
using HTTP, JSON3

import Term: Panel, tprintln
import Term.Progress: ProgressBar, addjob!, update!, with
import Term.Tables: Table

# ── Tavily search (advanced depth for richer results) ─────────────────────────

function _tavily_search(query::String; max_results::Int = 3)::String
    api_key = get(ENV, "TAVILY_API_KEY", "")
    isempty(api_key) && error("TAVILY_API_KEY not set in environment")

    body = JSON3.write(Dict(
        "api_key"        => api_key,
        "query"          => query,
        "search_depth"   => "advanced",
        "max_results"    => max_results,
        "include_answer" => true,
    ))

    resp = HTTP.post(
        "https://api.tavily.com/search",
        ["Content-Type" => "application/json"],
        body,
    )

    data = JSON3.read(resp.body)
    parts = String[]
    if haskey(data, :answer) && !isempty(data.answer)
        push!(parts, "Summary: $(data.answer)")
    end
    for r in data.results
        push!(parts, "• $(r.title): $(r.content[1:min(end,400)])")
    end
    join(parts, "\n")
end

@tool function search(query::String)
    "Search the web for up-to-date information. Use a specific, targeted query for best results."
    _tavily_search(query)
end

# ── Term helpers ──────────────────────────────────────────────────────────────

function agent_panel(title::String, content::String; style::String = "cyan")
    print(Panel(content; title=title, style=style, title_style="bold $style",
                width=80, justify=:left))
    println()
end

function section(title::String)
    println()
    tprintln("{bold blue}$(repeat('━', 78)){/bold blue}")
    tprintln("{bold blue}  $title{/bold blue}")
    tprintln("{bold blue}$(repeat('━', 78)){/bold blue}")
    println()
end

# ── Hooks ─────────────────────────────────────────────────────────────────────

function make_hooks(label::String, color::String)
    AgentHooks(
        before_llm_call = (ag, iter, msgs) ->
            (tprintln("{dim}  [$(label)] LLM call #$(iter){/dim}"); msgs),
        on_tool_call = (ag, name, args) ->
            tprintln("  {$(color)}[$(label)]{/$(color)} → {bold}$(name){/bold}: $(get(args, :query, get(args, :task, "…")))"),
        on_complete  = (ag, result) ->
            tprintln("  {$(color)}[$(label)]{/$(color)} {green}✓{/green} ($(length(string(result))) chars)"),
    )
end

# ── Agents ────────────────────────────────────────────────────────────────────

# Turns a vague sub-topic into one precise, targeted search query
query_planner = Agent(
    name           = "QueryPlanner",
    instructions   = """You are a search query specialist. Given a research sub-topic,
produce exactly ONE highly specific search query that will return the most relevant,
up-to-date results. Include relevant year (2024 or 2025), specific metrics or
entities where applicable, and avoid generic terms. Reply with the query string only
— no explanation, no quotes, no punctuation at the end.""",
    max_iterations = 1,
    hooks          = make_hooks("planner", "blue"),
)

# Researches one sub-topic using a pre-planned query — searches exactly once
topic_researcher = Agent(
    name           = "TopicResearcher",
    instructions   = """You are a research assistant. You will receive a targeted search
query. Call the search tool exactly once with that query, then write a concise
2–3 paragraph summary of the key findings. Be factual and cite specifics from
the results.""",
    tools          = [search_tool],
    max_iterations = 3,
    hooks          = make_hooks("researcher", "cyan"),
)

drafter = Agent(
    name         = "Drafter",
    instructions = """You are a report writer. Given research summaries, write a
well-structured report with an introduction, one section per sub-topic, and a
conclusion. Use clear, professional prose. Aim for 400–600 words.""",
    hooks        = make_hooks("drafter", "yellow"),
)

editor = Agent(
    name         = "Editor",
    instructions = """You are a professional editor. Improve clarity, flow, and
conciseness of the given draft without changing facts or structure. Return the
polished final report only — no commentary.""",
    hooks        = make_hooks("editor", "magenta"),
)

# TriageAgent with sub_agents — handoff tools auto-generated
triage = Agent(
    name         = "Triage",
    instructions = """You are a request router. Hand off research requests to
TopicResearcher and writing requests to Drafter. Always hand off.""",
    sub_agents   = [topic_researcher, drafter],
    hooks        = make_hooks("triage", "red"),
)

# ── Pipeline ──────────────────────────────────────────────────────────────────

TOPIC = "the current state of offshore wind energy"

SUB_TOPICS = [
    "offshore wind energy capacity and growth in 2024",
    "challenges and costs of offshore wind energy",
    "offshore wind energy policy and investment trends",
]

session = Session(app_name="ResearchPipeline", user_id="demo")

# ── Header ────────────────────────────────────────────────────────────────────

print(Panel(
    "  {bold}Topic:{/bold}    $TOPIC\n" *
    "  {bold}Agents:{/bold}   QueryPlanner · TopicResearcher · Drafter · Editor\n" *
    "  {bold}Features:{/bold} spawn_subagents · fan_out (parallel) · sub_agents";
    title="NimbleAgents — Research Pipeline", title_style="bold white",
    style="white", width=80,
))
println()

# ── Step 1: spawn_subagents — plan one sharp query per sub-topic ──────────────

section("Step 1 · spawn_subagents — QueryPlanner refines each sub-topic into a targeted search query")

planned_queries_raw = spawn_subagents(
    [(query_planner, topic) for topic in SUB_TOPICS];
    parallel = true,
    session  = session,
    verbose  = false,
)
planned_queries = string.(planned_queries_raw)

for (topic, query) in zip(SUB_TOPICS, planned_queries)
    tprintln("  {dim}$(topic){/dim}")
    tprintln("    {bold cyan}↳ $(query){/bold cyan}")
    println()
end

# ── Step 2: fan_out — research all planned queries in parallel ────────────────

section("Step 2 · fan_out — TopicResearcher runs in parallel on each planned query")

research_results = Vector{Any}(undef, length(planned_queries))

pbar = ProgressBar()
job  = addjob!(pbar; N=length(planned_queries), description="Researching")

with(pbar) do
    tasks = [Threads.@spawn begin
                result = run!(topic_researcher, planned_queries[i];
                              session=session, verbose=false)
                update!(job)
                result
             end
             for i in eachindex(planned_queries)]
    for (i, t) in enumerate(tasks)
        research_results[i] = fetch(t)
    end
end

println()
for (i, (topic, result)) in enumerate(zip(SUB_TOPICS, research_results))
    agent_panel("Research $i · $topic", string(result); style="cyan")
end

# ── Step 3: spawn_subagents — Drafter then Editor ────────────────────────────

section("Step 3 · spawn_subagents — Drafter then Editor (sequential pipeline)")

combined = join(
    ["### $(SUB_TOPICS[i])\n$(research_results[i])" for i in eachindex(SUB_TOPICS)],
    "\n\n",
)

draft_out = spawn_subagents(
    [(drafter, "Write a report on \"$TOPIC\" using this research:\n\n$combined")];
    session=session, verbose=false,
)
draft = string(draft_out[1])
agent_panel("Drafter — Draft", draft; style="yellow")

edit_out = spawn_subagents(
    [(editor, "Polish this draft:\n\n$draft")];
    session=session, verbose=false,
)
final_report = string(edit_out[1])

# ── Bonus: sub_agents wiring ──────────────────────────────────────────────────

section("Bonus · sub_agents — auto-generated handoff tools on TriageAgent")

auto_tools   = [handoff_tool(sa) for sa in triage.sub_agents]
sub_names    = join([sa.name for sa in triage.sub_agents], ", ")
tool_names   = join([t.name  for t  in auto_tools],        ", ")
tprintln("  sub_agents = [{bold}$(sub_names){/bold}]")
tprintln("  auto-generated tools: {bold cyan}$(tool_names){/bold cyan}")
println()

# ── Final report ──────────────────────────────────────────────────────────────

section("Final Report")
agent_panel("Editor — Polished Report", final_report; style="magenta")

# ── Session audit ─────────────────────────────────────────────────────────────

section("Session Audit")

total_input  = sum(e.input_tokens   for e in session.events)
total_output = sum(e.output_tokens  for e in session.events)
total_llm    = sum(e.llm_calls      for e in session.events)
total_tools  = sum(length(e.tool_calls) for e in session.events)

print(Panel(
    "  Turns recorded : $(length(session.events))\n" *
    "  LLM calls      : $total_llm\n"               *
    "  Tool calls     : $total_tools\n"              *
    "  Input tokens   : $total_input\n"              *
    "  Output tokens  : $total_output";
    title="Summary", title_style="bold white", style="white", width=50,
))
println()

function _tools_summary(e)
    isempty(e.tool_calls) && return "—"
    count = length(e.tool_calls)
    name  = e.tool_calls[1].name
    count == 1 ? name : "$name ×$count"
end

tbl = Table(Dict(
    "#"       => string.(1:length(session.events)),
    "Agent"   => [e.agent                for e in session.events],
    "LLM"     => string.([e.llm_calls    for e in session.events]),
    "In tok"  => string.([e.input_tokens for e in session.events]),
    "Out tok" => string.([e.output_tokens for e in session.events]),
    "Tools"   => [_tools_summary(e)      for e in session.events],
))
print(tbl)
println()
