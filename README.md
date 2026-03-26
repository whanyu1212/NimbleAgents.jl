<div align="center">

# NimbleAgents.jl

**A lightweight framework for building AI agents in pure Julia.**

[![Dev Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://whanyu1212.github.io/NimbleAgents.jl/dev/)
[![CI](https://github.com/whanyu1212/NimbleAgents.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/whanyu1212/NimbleAgents.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/whanyu1212/NimbleAgents.jl/branch/develop/graph/badge.svg)](https://codecov.io/gh/whanyu1212/NimbleAgents.jl)
[![Julia 1.10+](https://img.shields.io/badge/Julia-1.10%2B-9558B2?logo=julia)](https://julialang.org/)

Built on NimbleAgents' own OpenAI-compatible provider layer — supports OpenAI and Google Gemini.

</div>

---

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/whanyu1212/NimbleAgents.jl")
```

Set your API key as an environment variable before use (`OPENAI_API_KEY` or `GOOGLE_API_KEY`).

## Quick Start

```julia
using NimbleAgents

# Define a tool — the @tool macro generates the JSON schema automatically
@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end

# Create an agent with tools
agent = Agent(
    name         = "MathBot",
    instructions = "You are a helpful math assistant.",
    tools        = [add_tool],
)

# Run it
result = run!(agent, "What is 42 + 17?")
```

## Features

**Core** — `@tool` macro with auto-generated schemas | structured output into Julia structs | real-time token streaming | input/output guardrails (`Pass`, `Block`, `Modify`) | lifecycle hooks for logging, HITL approval, and message filtering

**Multi-Agent** — agent handoffs with history filtering | `run_pipeline!` and `loop_pipeline!` for chained workflows | `fan_out` and `spawn_subagents` with real OS threads

**Persistence** — session management with in-memory, JSON, and SQLite backends | cross-session long-term memory scoped by user/app | session TTL with `cleanup!`

**Observability** — cost tracking for 40+ models via `Trace` | tool output trimming | per-model rate limiting

**Integrations** — MCP server support (stdio + HTTP) | filesystem-based skills | 15+ built-in tools (filesystem, shell, HTTP, REPL, search, memory) | web UI with SSE streaming

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

Full guides, examples, and API reference at **[whanyu1212.github.io/NimbleAgents.jl/dev/](https://whanyu1212.github.io/NimbleAgents.jl/dev/)**
