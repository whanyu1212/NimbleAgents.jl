```@meta
CurrentModule = NimbleAgents
```

# Getting Started

## Prerequisites

You need an API key for a supported LLM provider. NimbleAgents currently ships native support for OpenAI (`OPENAI_API_KEY`) and Google Gemini (`GOOGLE_API_KEY`).

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

## Deterministic Doctested Examples

These examples are fully local and run during documentation doctests.

```jldoctest tool_dispatch_smoke
julia> using NimbleAgents

julia> @tool function add_docs(x::Int, y::Int)
           "Add two integers."
           x + y
       end;

julia> tool_map = build_tool_map([add_docs_tool]);

julia> dispatch_tool(tool_map, "add_docs", Dict(:x => 2, :y => 3))
5
```

```jldoctest session_state_smoke
julia> using NimbleAgents

julia> session = Session(app_name="Docs", user_id="alice");

julia> length(session)
0

julia> session.state["topic"] = "agents"; session.state["topic"]
"agents"

julia> reset!(session) === session
true

julia> length(session)
0

julia> isempty(session.state)
true
```

```jldoctest trace_smoke
julia> using NimbleAgents

julia> turn = TurnEvent("DocsBot", "mock-model", "hello");

julia> turn.output = "hi"; turn.input_tokens = 5; turn.output_tokens = 2;

julia> session = Session(app_name="Docs", user_id="alice");

julia> push!(session.events, turn);

julia> trace = Trace(session);

julia> trace.total_tokens
7
```

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
