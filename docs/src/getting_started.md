```@meta
CurrentModule = NimbleAgents
```

# Getting Started

## Prerequisites

You need an API key for a supported LLM provider. NimbleAgents uses [PromptingTools.jl](https://github.com/svilupp/PromptingTools.jl) under the hood, which supports OpenAI, Anthropic, Google, Ollama, and more.

Set your API key as an environment variable:

```bash
export OPENAI_API_KEY="your-api-key"
```

Or set it in Julia before using NimbleAgents:

```julia
ENV["OPENAI_API_KEY"] = "your-api-key"
```

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/whanyu1212/NimbleAgents.jl")
```

## Your First Agent

```julia
using NimbleAgents

# Define a tool using the @tool macro
@tool function greet(name::String)
    "Greet a person by name."
    "Hello, $(name)! Nice to meet you."
end

# Create an agent
agent = Agent(
    name = "Greeter",
    instructions = "You are a friendly assistant that greets people.",
    tools = [greet_tool],
)

# Run the agent
result = run!(agent, "Greet Alice")
println(result)  # "Hello, Alice! Nice to meet you."
```

The `@tool` macro creates two things:
1. A normal Julia function `greet(name)` you can call directly
2. A `NimbleTool` object `greet_tool` with auto-generated JSON schema for the LLM

## Adding Session Memory

Sessions let your agent remember previous conversations:

```julia
session = Session(app_name="MyApp", user_id="alice")

# First interaction
run!(agent, "My name is Alice"; session)

# Later interaction — agent remembers the conversation
run!(agent, "What's my name?"; session)
```

## Structured Output

Parse LLM responses into Julia structs:

```julia
struct WeatherReport
    location::String
    temperature::Float64
    conditions::String
end

agent = Agent(
    name = "WeatherBot",
    instructions = "You provide weather reports.",
    output_type = WeatherReport,
)

report = run!(agent, "Weather in Tokyo: 22C, sunny")
# report.location == "Tokyo"
# report.temperature == 22.0
```

## Next Steps

- [Agents](guide/agents.md) — agent configuration, hooks, retry, structured output, and cost tracking
- [Tools](guide/tools.md) — defining tools, CLI tools, and built-in tools
- [Sessions & Artifacts](guide/sessions.md) — session persistence, artifact tracking, and web UI
- [Multi-Agent Patterns](guide/multi_agent.md) — orchestration, routing, fan-out, loops, and handoff filtering
- [Guardrails](guide/guardrails.md) — input/output validation and content filtering
- [MCP](guide/mcp.md) — connecting to MCP servers
- [Skills](guide/skills.md) — filesystem-based capability packages
- [Tracer](guide/tracer.md) — token usage, cost, and timing analysis
- [Examples](examples.md) — runnable examples covering all major features
- [Reference](reference.md) — full API reference
