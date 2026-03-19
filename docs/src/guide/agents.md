```@meta
CurrentModule = NimbleAgents
```

# Agents

The [`Agent`](@ref) struct is the core of NimbleAgents. It encapsulates an AI assistant with a specific role, tools, and behavior.

## Basic Agent

```julia
agent = Agent(
    name = "Assistant",
    instructions = "You are a helpful assistant.",
)
```

## Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `String` | required | Human-readable name |
| `instructions` | `String` | required | System prompt |
| `tools` | `Vector{<:AbstractTool}` | `[]` | Tools the agent can call |
| `model` | `String` | `"gpt-4o-mini"` | LLM model identifier |
| `max_iterations` | `Int` | `10` | Max LLM calls per run |
| `output_type` | `Type` or `Nothing` | `nothing` | Struct to parse response into |
| `hooks` | `AgentHooks` | all no-ops | Lifecycle callbacks |
| `sub_agents` | `Vector{Agent}` | `[]` | Child agents for handoffs |
| `retry` | `RetryConfig` | default | Retry policy for API calls |
| `context` | `ContextConfig` | default | Context window management |
| `skills` | `Vector{Skill}` | `[]` | Attached skills |
| `skill_dirs` | `Vector{String}` | `[]` | Directories to discover skills |
| `mcp_servers` | `Vector{MCPServer}` | `[]` | MCP servers to connect |

## Running an Agent

```julia
# Simple run
result = run!(agent, "Hello!")

# With session
session = Session(app_name="MyApp", user_id="alice")
result = run!(agent, "Hello!"; session)

# With streaming
result = run!(agent, "Write a poem"; on_token = token -> print(token))

# With a session store for persistence
store = JSONSessionStore("./sessions")
result = run!(agent, "Hello!"; session, store)
```

## Structured Output

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

result = run!(agent, "What's the weather in Tokyo?")
# result isa WeatherReport
```

## Agent Hooks

Hook into the agent lifecycle for logging, monitoring, or approval flows:

```julia
hooks = AgentHooks(
    on_llm_call    = (agent, iter) -> println("LLM call #$iter"),
    on_llm_result  = (agent, iter, resp) -> println("Got response"),
    on_tool_call   = (agent, name, args) -> println("Calling: $name"),
    on_tool_result = (agent, name, result) -> println("Result: $result"),
    on_complete    = (agent, result) -> println("Done!"),
)

agent = Agent(name="Bot", instructions="...", hooks=hooks)
```

### Approval Flow

Use `should_interrupt` to require human approval for specific tools:

```julia
hooks = AgentHooks(
    should_interrupt = (tool_name, args) -> tool_name == "delete_file",
)
```

When `should_interrupt` returns `true`, the agent pauses and waits for approval via the `approval_channel`.

## Retry Configuration

Configure exponential backoff for transient API errors (429, 500, 503, etc.):

```julia
retry = RetryConfig(
    max_retries   = 5,
    initial_delay = 1.0,
    max_delay     = 120.0,
    jitter        = true,
)

agent = Agent(name="Bot", instructions="...", retry=retry)
```

## Multi-Agent Handoffs

Route tasks between specialized agents:

```julia
coder = Agent(name="Coder", instructions="You write code.")
reviewer = Agent(name="Reviewer", instructions="You review code.")

orchestrator = Agent(
    name = "Orchestrator",
    instructions = "Route coding tasks to Coder and review tasks to Reviewer.",
    sub_agents = [coder, reviewer],
)

result = run!(orchestrator, "Write a fibonacci function")
```

The orchestrator gets auto-generated `handoff_to_Coder` and `handoff_to_Reviewer` tools.
