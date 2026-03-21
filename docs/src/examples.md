```@meta
CurrentModule = NimbleAgents
```

# Examples

All examples are self-contained and can be run from the repo root:

```bash
julia --project examples/<category>/<file>.jl
```

API keys go in a `.env` file at the repo root — loaded automatically by `DotEnv.load!()`.

## Multi-Agent Orchestration

### Agent-as-Tool + Handoff Pipeline

Two core patterns for coordinating specialists: an orchestrator that calls agents as tools, and a triage agent that hands off control.

```julia
# Pattern 1: agent_as_tool — orchestrator delegates to specialists
math_agent = Agent(
    name         = "MathAgent",
    instructions = "You are a math specialist. Always use tools to compute.",
    tools        = [add_tool, multiply_tool],
)
text_agent = Agent(
    name         = "TextAgent",
    instructions = "You are a text processing specialist.",
    tools        = [word_count_tool, reverse_words_tool],
)
session = Session(app_name="MultiAgentDemo")
orchestrator = Agent(
    name         = "Orchestrator",
    instructions = "Delegate math to MathAgent and text tasks to TextAgent.",
    tools        = [
        agent_as_tool(math_agent; session),
        agent_as_tool(text_agent; session),
    ],
)
run!(orchestrator, "What is 12 multiplied by 7?"; session)
```

```julia
# Pattern 2: run_pipeline! — triage with handoff_tool
billing = Agent(name="BillingAgent", instructions="Handle billing questions.")
tech    = Agent(name="TechAgent",    instructions="Handle technical support.")
triage = Agent(
    name         = "TriageAgent",
    instructions = "Route billing questions to BillingAgent, tech to TechAgent.",
    tools        = [handoff_tool(billing), handoff_tool(tech)],
)
run_pipeline!(triage, "I was charged twice this month.";
              session=Session(), max_handoffs=5)
```

> **File:** [`examples/multi_agent/multi_agent.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/multi_agent/multi_agent.jl)

### Research Pipeline

A full multi-agent pipeline using all three coordination primitives — `spawn_subagents` for query planning, `fan_out` for parallel research, and sequential drafter/editor pipeline:

```julia
# Step 1: spawn_subagents — plan one sharp query per sub-topic
planned_queries = spawn_subagents(
    [(query_planner, topic) for topic in sub_topics];
    parallel=true, session,
)
# Step 2: fan_out — research all queries in parallel
tasks = [Threads.@spawn run!(researcher, q; session) for q in planned_queries]
results = fetch.(tasks)
# Step 3: sequential pipeline — draft then edit
draft = spawn_subagents([(drafter, combined_research)]; session)
final = spawn_subagents([(editor, draft[1])]; session)
```

> **File:** [`examples/multi_agent/research_pipeline.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/multi_agent/research_pipeline.jl)

### Claude Code as a Sub-Agent

Use Claude Code (or any external CLI agent) as a tool with real-time progress streaming via `ExternalAgentTool`:

```julia
coder = claude_code_tool(
    working_dir = "/path/to/repo",
    model       = "sonnet",
    timeout     = 120.0,
    on_output   = line -> begin
        try
            event = JSON3.read(line)
            if get(event, :type, "") == "assistant"
                for block in event.message.content
                    text = get(block, :text, nothing)
                    !isnothing(text) && println("[claude] ", text)
                end
            end
        catch; end
    end,
)
pm = Agent(
    name         = "PM",
    instructions = "Delegate implementation tasks to claude_code.",
    tools        = [coder],
)
run!(pm, "Write a fibonacci function with tests.")
```

Session continuity is supported — pass `session_id` to resume a previous Claude Code conversation, or `resume=true` to continue the most recent one.

!!! note "Authentication"
    Claude Code must be authenticated before use. Either run `claude login` once in your terminal, or set `ANTHROPIC_API_KEY` in your `.env` file.

> **File:** [`examples/multi_agent/claude_code_agent.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/multi_agent/claude_code_agent.jl)

## Human-in-the-Loop

Three patterns for injecting human approval into the agent loop, from simplest to most flexible.

### Pattern 1: `should_interrupt` (Recommended)

A declarative gate — return `true` to pause before a dangerous tool executes:

```julia
agent = Agent(
    name  = "OpsBot",
    tools = [send_email_tool, delete_file_tool, read_file_tool],
    hooks = AgentHooks(
        should_interrupt = (name, args) -> name in ["send_email", "delete_file"],
    ),
)
# Safe tools execute normally; dangerous tools throw HumanInterrupt
try
    run!(agent, "Delete /tmp/backup.log"; session)
catch e::HumanInterrupt
    # Inspect e.tool_calls, ask for approval, then:
    resume!(session, "Approved. Please proceed.")
    run!(agent, ""; session)  # continues from where it left off
end
```

> **File:** [`examples/human_in_the_loop/hitl_should_interrupt.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/human_in_the_loop/hitl_should_interrupt.jl)

### Pattern 2: `after_llm_call` Hook

Inspect the full LLM response before tools are dispatched:

```julia
hooks = AgentHooks(
    after_llm_call = (agent, iter, response) -> begin
        # Log, filter, or modify the response before tool dispatch
        println("LLM wants to call: ", [tc.name for tc in response.tool_calls])
    end,
)
```

> **File:** [`examples/human_in_the_loop/hitl_after_llm_call.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/human_in_the_loop/hitl_after_llm_call.jl)

### Pattern 3: `approval_channel` (Async)

Non-blocking approval via a `Channel` — the agent suspends until a value is sent:

```julia
approval_ch = Channel{String}(1)
# In another task (e.g., web UI, Slack bot):
@async begin
    # Wait for user input...
    put!(approval_ch, "approve")
end
run!(agent, "Send email to boss@co.com"; approval_channel=approval_ch)
```

> **File:** [`examples/human_in_the_loop/hitl_channel.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/human_in_the_loop/hitl_channel.jl)

## Guardrails

### Input Guardrails

Block or sanitize user input before the LLM sees it:

```julia
agent = Agent(
    name       = "SafeBot",
    guardrails = [
        Guardrail(phase=:input, check=(input, _) -> begin
            occursin(r"\d{3}-\d{2}-\d{4}", input) ? Block("SSN detected") : Pass()
        end),
        Guardrail(phase=:input, check=(input, _) -> begin
            Modify(replace(input, r"<[^>]+>" => ""))  # strip HTML
        end),
    ],
)
```

> **File:** [`examples/guardrails/input_guardrails.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/guardrails/input_guardrails.jl)

### Output Guardrails

Filter or transform the agent's response before returning it to the user:

```julia
Guardrail(phase=:output, check=(output, _) -> begin
    occursin(r"https?://", output) ? Block("External links not allowed") : Pass()
end)
```

> **File:** [`examples/guardrails/output_guardrails.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/guardrails/output_guardrails.jl)

## Streaming

Real-time token streaming with the `on_token` callback:

```julia
agent = Agent(name="StreamBot", instructions="Be concise.")
# Tokens print as they arrive
run!(agent, "Write a haiku about Julia.";
     on_token = token -> print(token))
# Or collect into a buffer
buf = IOBuffer()
run!(agent, "Explain monads in one sentence.";
     on_token = token -> print(buf, token))
collected = String(take!(buf))
```

Streaming works with tool calls too — tool rounds execute normally, then the final text response streams.

> **File:** [`examples/agents/streaming.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/agents/streaming.jl)

## Tools

### Built-in Tool Library

NimbleAgents ships with ready-to-use tools for common tasks:

```julia
# Filesystem agent
agent = Agent(
    name  = "CodingAssistant",
    tools = [read_file_tool, list_dir_tool, glob_tool, grep_tool, find_files_tool],
)
# HTTP agent
agent = Agent(
    name  = "WebAgent",
    tools = [http_get_tool, fetch_webpage_tool, github_trending_tool],
)
# Shell agent (pair with should_interrupt for safety)
agent = Agent(
    name  = "ShellAgent",
    tools = [bash_tool],
    hooks = AgentHooks(should_interrupt = (name, _) -> name == "bash"),
)
```

Available built-in tools: `read_file_tool`, `write_file_tool`, `edit_file_tool`, `list_dir_tool`, `glob_tool`, `delete_file_tool`, `grep_tool`, `find_files_tool`, `bash_tool`, `http_get_tool`, `http_post_tool`, `fetch_webpage_tool`, `github_trending_tool`, `eval_julia_tool`, `save_artifact_tool`, `save_memory_tool`, `recall_memory_tool`.

> **File:** [`examples/tools/builtin_tools_demo.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/tools/builtin_tools_demo.jl)

### CLI Tools

Wrap any shell command as an agent tool — arguments are never interpolated into a shell string, so injection is structurally impossible:

```julia
jq_tool = CLITool(
    name        = "jq",
    description = "Query JSON with jq.",
    command     = ["jq", "{filter}", "{file}"],
    args        = [
        "filter" => CLIArg(String, "jq filter expression"),
        "file"   => CLIArg(String, "Path to JSON file"),
    ],
)
```

> **File:** [`examples/tools/cli_tools_demo.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/tools/cli_tools_demo.jl)

## Cross-Session Memory

Agents can store and retrieve facts across sessions using `AbstractMemoryService`:

```julia
memory = InMemoryMemoryService()
# memory = SQLiteMemoryService("memory.db")  # persistent
agent = Agent(
    name         = "MemoryBot",
    instructions = "Store user preferences with save_memory, retrieve with recall_memory.",
    tools        = [save_memory_tool, recall_memory_tool],
    memory       = memory,
)
# Session 1: teach the agent
session1 = Session(app_name="Demo", user_id="alice")
run!(agent, "Remember: my favorite color is blue."; session=session1)
# Session 2: new session, memories persist
session2 = Session(app_name="Demo", user_id="alice")
run!(agent, "What's my favorite color?"; session=session2)
```

Relevant memories are also automatically injected into the system prompt at the start of each `run!` call.

> **File:** [`examples/agents/memory_demo.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/agents/memory_demo.jl)

## Web UI

Serve agents over HTTP with SSE streaming and a built-in browser interface:

```julia
chat   = Agent(name="ChatBot",     instructions="You are helpful.")
search = Agent(name="ResearchBot", instructions="...", tools=[search_web_tool])
files  = Agent(name="FilesBot",    instructions="...", tools=[read_file_tool, glob_tool])
serve([chat, search, files]; port=8080)
# Open http://localhost:8080
```

Features: real-time token streaming via SSE, agent selection, tool call/result display, human-in-the-loop approval flow, and session persistence.

```bash
# Requires multiple threads for background agent tasks
julia --project -t 4 examples/web/web_ui.jl
```

> **File:** [`examples/web/web_ui.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/web/web_ui.jl)

## Tracing & Cost Tracking

Inspect what happened after a run — token usage, tool calls, timing, and estimated cost:

```julia
session = Session()
run!(agent, "Summarize this document"; session)
trace = Trace(session)
print_trace(trace)
println("Total cost: \$", round(trace.total_cost; digits=4))
save_trace(trace, "trace.json")  # export for analysis
```

> **File:** [`examples/agents/tracing_demo.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/agents/tracing_demo.jl)

## Agent Hooks

Full lifecycle hooks for logging, monitoring, or transforming messages:

```julia
hooks = AgentHooks(
    before_llm_call = (agent, iter, msgs) -> begin
        println("LLM call #\$iter with \$(length(msgs)) messages")
        msgs  # return (possibly modified) messages
    end,
    after_llm_call  = (agent, iter, resp) -> println("Got response"),
    on_tool_call    = (agent, name, args) -> println("Calling: \$name(\$args)"),
    on_tool_result  = (agent, name, result) -> println("Result: \$result"),
    on_complete     = (agent, result) -> println("Done: \$result"),
)
agent = Agent(name="Bot", instructions="...", hooks=hooks)
```

> **File:** [`examples/agents/hooks_walkthrough.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/agents/hooks_walkthrough.jl)

## MCP (Model Context Protocol)

Connect agents to external MCP servers for tool discovery:

```julia
agent = Agent(
    name         = "DocBot",
    instructions = "Search documentation using MCP tools.",
    mcp_servers  = [
        MCPServer(command="uvx", args=["mcpdoc", "--urls", "https://docs.example.com"]),
    ],
)
# MCP tools are discovered at agent startup and merged with explicit tools
run!(agent, "How do I configure authentication?")
```

Supports both **stdio** (subprocess) and **HTTP** (remote server) transports.

> **File:** [`examples/mcp/langchain_docs.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/mcp/langchain_docs.jl)
