# NimbleAgents.jl

A simple, lightweight framework for building AI agents in pure Julia.

Built on [PromptingTools.jl](https://github.com/svilupp/PromptingTools.jl). Supports OpenAI, Anthropic, Google Gemini, and any OpenAI-compatible endpoint.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/whanyu1212/NimbleAgents.jl")
```

Requires Julia 1.12+. Set your API key in `.env` or as an environment variable before use.

## Quick Start

```julia
using NimbleAgents

@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end

agent = Agent(
    name         = "MathBot",
    instructions = "You are a helpful math assistant.",
    tools        = [add_tool],
)

result = run!(agent, "What is 42 + 17?")
```

The `@tool` macro generates a JSON schema from the function signature automatically — no boilerplate.

## Features

| Feature | Description |
|---------|-------------|
| **Tool system** | `@tool` macro — plain Julia functions become LLM-callable tools |
| **Multi-agent** | Orchestrator-workers, triage/routing, fan-out, collaborative loops, chained handoffs |
| **Session management** | Conversation history, key-value state, event log; in-memory, JSON, and SQLite backends |
| **Long-term memory** | Cross-session memory scoped by user and app; auto-injected into the system prompt |
| **Guardrails** | Input/output validation — `Pass`, `Block`, or `Modify` content |
| **Structured output** | Parse LLM responses directly into Julia structs |
| **Streaming** | Real-time token streaming via `on_token` callback |
| **Hooks** | Lifecycle callbacks for logging, HITL approval flows, and message filtering |
| **Cost tracking** | Built-in pricing for 40+ models; per-turn cost via `Trace` |
| **MCP support** | Connect to Model Context Protocol servers (stdio + HTTP) |
| **Skills** | Filesystem-based instruction packages loaded on demand |
| **Rate limiting** | Token-bucket limiter per model or global default |
| **Web UI** | `serve([agents])` — browser chat interface with SSE streaming *(experimental)* |
| **Built-in tools** | Filesystem, shell, HTTP, Julia REPL, web search, artifact saving, memory |

## Multi-Agent Patterns

```julia
# Orchestrator delegates to specialists
pm = Agent(
    name  = "PM",
    tools = [agent_as_tool(coder; session), agent_as_tool(reviewer; session)],
)

# Triage routes to the right specialist
result = run_pipeline!(triage_agent, "I was charged twice"; session)

# Collaborative refinement loop
result = loop_pipeline!(
    [coder, reviewer], "Write a fibonacci function";
    stop_when = (_, r) -> occursin("APPROVED", string(r)),
)

# Fan-out: same agent, many inputs, parallel
summaries = fan_out(researcher, topics; parallel=true, session)
```

## Why Julia?

- **Types without a validation layer** — tool schemas and structured outputs fall naturally from Julia's type system
- **`@tool` does the heavy lifting** — one annotated function generates the schema, struct, and callable
- **Real threads** — `fan_out` and `spawn_subagents` use `Threads.@spawn`, not asyncio
- **REPL-first iteration** — Revise.jl lets you redefine tools and agents without restarting

## Documentation

[whanyu1212.github.io/NimbleAgents.jl](https://whanyu1212.github.io/NimbleAgents.jl/)
