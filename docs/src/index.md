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
  - title: Session Management
    details: Built-in session support with history, state, and event tracking. In-memory and JSON storage backends.
  - title: MCP Support
    details: Native Model Context Protocol support. Connect to any MCP server and use their tools seamlessly.
  - title: Structured Output
    details: Parse LLM responses into Julia structs. Type-safe agent outputs with automatic schema inference.
  - title: Agent Handoffs
    details: Build multi-agent systems with handoffs, fan-out, and sub-agent spawning.
  - title: Streaming & Hooks
    details: Stream tokens in real-time. Hook into the agent lifecycle for logging, approval flows, and more.

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
- **Lightweight** — built on [PromptingTools.jl](https://github.com/svilupp/PromptingTools.jl), minimal dependencies
- **Extensible** — built-in support for MCP servers, skills, CLI tools, and custom hooks

Ready to get started? Check out the [Getting Started](@ref) guide.

```@raw html
</div>
```
