```@raw html
---
layout: home

hero:
  name: NimbleAgents.jl
  text: Build AI Agents in Pure Julia
  tagline: A simple, lightweight framework for building AI agents with tool use, session management, and MCP support
  actions:
    - theme: brand
      text: Get Started
      link: /getting_started
    - theme: alt
      text: API Reference
      link: /reference
    - theme: alt
      text: View on GitHub
      link: https://github.com/whanyu1212/NimbleAgents.jl

features:
  - title: Tool System
    details: Define tools with a simple @tool macro. Automatic JSON schema generation from Julia function signatures.
    link: /guide/tools
  - title: Multi-Agent Orchestration
    details: Orchestrator-workers, triage routing, fan-out, collaborative loops, and chained handoffs with history filtering.
    link: /guide/multi_agent
  - title: Guardrails
    details: Validate inputs and outputs with composable guardrails. Block, pass, or modify content before it reaches the LLM or user.
    link: /guide/guardrails
  - title: Session Management
    details: Built-in session support with history, state, and event tracking. In-memory, JSON, and SQLite storage backends.
    link: /guide/sessions
  - title: Long-Term Memory
    details: Cross-session memory scoped by user and app. Agents recall relevant facts from past conversations automatically.
    link: /guide/agents#long-term-memory
  - title: Structured Output
    details: Parse LLM responses into Julia structs. Type-safe agent outputs with automatic schema inference.
    link: /guide/agents#structured-output
  - title: Cost Tracking
    details: Built-in pricing for 40+ models, including OpenAI and Gemini. Per-turn cost breakdown via Trace.
    link: /guide/agents#cost-tracking
  - title: MCP Support
    details: Native Model Context Protocol support. Connect to any MCP server and use their tools seamlessly.
    link: /guide/mcp
  - title: Streaming & Hooks
    details: Stream tokens in real-time. Hook into the agent lifecycle for logging, approval flows, and human-in-the-loop.
    link: /guide/agents#agent-hooks

---

<p style="margin-bottom:2cm"></p>

<div class="vp-doc" style="width:80%; margin:auto">
```

## Quick Example

```julia
using NimbleAgents

# Define a tool
@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end

# Create an agent
agent = Agent(
    name = "MathBot",
    instructions = "You are a helpful math assistant.",
    tools = [add_tool],
)

# Run it
result = run!(agent, "What is 42 + 17?")
```

## Why NimbleAgents?

NimbleAgents is designed to be **simple** and **Julia-native**:

- **No boilerplate** — tools are just Julia functions with docstrings
- **Type-safe** — leverage Julia's type system for tool schemas and output parsing
- **Lightweight** — native OpenAI-compatible provider layer, minimal dependencies
- **Extensible** — built-in support for MCP servers, skills, CLI tools, and custom hooks

## Why Julia for agents?

There are plenty of agent frameworks in Python. Here's why building in Julia feels worth it:

- **Types without a validation layer** — Julia's type system is enforced at runtime, so tool schemas and structured outputs fall out naturally from function signatures. No need for a separate validation library on top.
- **Multiple dispatch reduces boilerplate** — tool dispatch, hook callbacks, and output parsing all feel like a natural fit for a language where behaviour is selected by argument types. What would be `isinstance` chains or class hierarchies in Python becomes a few method definitions.
- **`@kwdef` structs are concise** — `Agent`, `Guardrail`, `Session` and friends get full keyword constructors for free. No dataclass decorator, no `__init__` boilerplate.
- **Macros do the heavy lifting** — `@tool` generates the JSON schema, wrapper struct, and callable from one annotated function. The equivalent in Python requires a decorator that inspects type hints at runtime, or writing the schema by hand.
- **No `self` everywhere** — functions are not tied to classes, which removes a lot of visual noise from method signatures and bodies.
- **Straightforward parallelism** — `fan_out` and `spawn_subagents` use real threads. For workloads that go beyond waiting on LLM responses, this can be useful.
- **REPL-first iteration** — with Revise.jl, you can redefine tools and agent behaviour without restarting your process. The feedback loop for experimentation is tight.

That said, the Python ecosystem for LLM tooling is much larger and more mature. If your team is already in Python, or you need broad library coverage, that's a real consideration.

Ready to get started? Check out the [Getting Started](@ref) guide.

```@raw html
</div>
```
