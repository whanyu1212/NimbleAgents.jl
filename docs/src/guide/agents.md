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
| `instructions` | `String` or `Function` | required | System prompt (static or `(session, agent) -> String`) |
| `tools` | `Vector{<:AbstractTool}` | `[]` | Tools the agent can call |
| `model` | `String` | `"gpt-5.4-mini"` | LLM model identifier |
| `max_iterations` | `Int` | `10` | Max LLM calls per run |
| `output_type` | `Type` or `Nothing` | `nothing` | Struct to parse response into |
| `api_kwargs` | `NamedTuple` | `NamedTuple()` | Extra kwargs passed to every LLM call (reasoning, temperature, etc.) |
| `hooks` | `AgentHooks` | all no-ops | Lifecycle callbacks |
| `sub_agents` | `Vector{Agent}` | `[]` | Child agents for handoffs |
| `retry` | `RetryConfig` | default | Retry policy for API calls |
| `context` | `ContextConfig` | default | Context window management |
| `skills` | `Vector{Skill}` | `[]` | Attached skills |
| `skill_dirs` | `Vector{String}` | `[]` | Directories to discover skills |
| `mcp_servers` | `Vector{MCPServer}` | `[]` | MCP servers to connect |
| `guardrails` | `Vector{Guardrail}` | `[]` | Input/output guardrails |
| `memory` | `AbstractMemoryService` or `Nothing` | `nothing` | Cross-session long-term memory |

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
    before_llm_call = (agent, iter, msgs) -> (println("LLM call #$iter"); msgs),
    after_llm_call  = (agent, iter, resp) -> println("Got response"),
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

### Structured Output Parse Retries

When `output_type` is set, the LLM response is parsed into the target struct. If parsing fails (the model returned malformed output), the error is automatically fed back to the LLM as a correction prompt and the extraction is retried — up to `max_parse_retries` times (default: 2).

```julia
retry = RetryConfig(
    max_parse_retries = 3,   # retry parsing up to 3 times (default: 2)
)

agent = Agent(
    name         = "StructBot",
    instructions = "Extract data.",
    output_type  = MyStruct,
    retry        = retry,
)
```

Set `max_parse_retries = 0` to disable and fail immediately on the first parse error.

## Parallel Tool Execution

When the LLM requests multiple tool calls in a single response, NimbleAgents executes them concurrently using `Threads.@spawn`. This reduces latency when tools involve I/O (HTTP requests, file operations, etc.).

```julia
# If the LLM calls search_web, fetch_webpage, and lookup_db in one response,
# all three execute in parallel. No configuration needed — it's automatic.
agent = Agent(
    name = "Researcher",
    instructions = "Research the topic thoroughly.",
    tools = [search_web_tool, fetch_webpage_tool, lookup_db_tool],
)
```

Parallel execution is **automatic** when:
- The LLM requests 2+ tool calls in one response
- None of the tools have `return_direct = true`
- The agent has no `sub_agents` (handoff tools require sequential ordering)

When any of those conditions aren't met, tools execute sequentially as before. Errors in individual tools are caught and reported back to the LLM without affecting other tools in the batch.

## Rate Limiting

Prevent 429 errors when running multiple agents concurrently by setting per-model or global rate limits:

```julia
# Limit a specific model to 10 requests/second
set_rate_limit!("gpt-5.4-mini", 10)

# Set a default for all models
set_rate_limit!(:default, 20)

# Remove a limit
remove_rate_limit!("gpt-5.4-mini")
remove_rate_limit!(:default)
```

The rate limiter uses a token-bucket algorithm. Before each LLM call (including tool-call rounds, streaming, and structured output extraction), the agent acquires a token from the bucket. If none are available, it blocks until one refills.

Model-specific limits take precedence over the default. If no limit is set for a model and no default exists, the call proceeds immediately with no throttling.

Rate limiting is especially useful with [`fan_out`](@ref), [`spawn_subagents`](@ref), and the web server, where many agents may call the same model concurrently.

## Cost Tracking

NimbleAgents automatically tracks estimated USD cost per turn when model pricing is registered. Default pricing is included for popular OpenAI, Anthropic, and Google models.

```julia
# Check cost after a run
session = Session()
run!(agent, "Summarize this document"; session)
trace = Trace(session)
println("Cost: \$", round(trace.total_cost; digits=4))

# Per-turn breakdown
for turn in trace.turns
    println("  $(turn.agent) ($(turn.model)): \$$(round(turn.cost; digits=4))")
end
```

### Custom Model Pricing

Register pricing for models not in the default list:

```julia
# Price per 1 million tokens (USD)
set_model_pricing!("my-custom-model", 1.00, 3.00)  # $1/M input, $3/M output

# Check current pricing
get_model_pricing("gpt-5.4-mini")  # (input = 0.4, output = 1.6)

# Remove pricing
remove_model_pricing!("my-custom-model")
```

Cost is computed incrementally as tokens are consumed — each LLM call adds to the turn's running total. If no pricing is registered for a model, cost is reported as `0.0`.

### Built-in Model Pricing

The following models have built-in pricing (USD per 1M tokens). Prices are sourced from official provider pricing pages as of March 2026.

#### OpenAI

| Model | Input | Output |
|-------|------:|-------:|
| `gpt-4o` | \$2.50 | \$10.00 |
| `gpt-4o-mini` | \$0.15 | \$0.60 |
| `gpt-4.1` | \$2.00 | \$8.00 |
| `gpt-4.1-mini` | \$0.40 | \$1.60 |
| `gpt-4.1-nano` | \$0.10 | \$0.40 |
| `o1` | \$15.00 | \$60.00 |
| `o1-mini` | \$1.10 | \$4.40 |
| `o1-pro` | \$150.00 | \$600.00 |
| `o3` | \$10.00 | \$40.00 |
| `o3-mini` | \$1.10 | \$4.40 |
| `o3-pro` | \$20.00 | \$80.00 |
| `o4-mini` | \$1.10 | \$4.40 |
| `gpt-4-turbo` | \$10.00 | \$30.00 |
| `gpt-3.5-turbo` | \$0.50 | \$1.50 |

#### Anthropic

| Model | Input | Output |
|-------|------:|-------:|
| `claude-opus-4-6` | \$5.00 | \$25.00 |
| `claude-sonnet-4-6` | \$3.00 | \$15.00 |
| `claude-haiku-4-5` | \$1.00 | \$5.00 |
| `claude-opus-4-5` | \$5.00 | \$25.00 |
| `claude-sonnet-4-5` | \$3.00 | \$15.00 |
| `claude-opus-4-1` | \$15.00 | \$75.00 |
| `claude-sonnet-4-0` / `claude-opus-4-0` | \$3.00 / \$15.00 | \$15.00 / \$75.00 |
| `claude-3-5-sonnet-20241022` | \$3.00 | \$15.00 |
| `claude-3-haiku-20240307` | \$0.25 | \$1.25 |

#### Google Gemini

| Model | Input | Output |
|-------|------:|-------:|
| `gemini-3.1-pro-preview` | \$2.00 | \$12.00 |
| `gemini-3.1-flash-lite-preview` | \$0.25 | \$1.50 |
| `gemini-3-flash-preview` | \$0.50 | \$3.00 |
| `gemini-2.5-pro` | \$1.25 | \$10.00 |
| `gemini-2.5-flash` | \$0.30 | \$2.50 |
| `gemini-2.5-flash-lite` | \$0.10 | \$0.40 |
| `gemini-2.0-flash` | \$0.10 | \$0.40 |
| `gemini-2.0-flash-lite` | \$0.075 | \$0.30 |
| `gemini-1.5-pro` | \$1.25 | \$5.00 |
| `gemini-1.5-flash` | \$0.075 | \$0.30 |

Dated variants (e.g. `claude-opus-4-5-20251101`, `gpt-4o-2024-08-06`) are also included with the same pricing as their aliases. Use `set_model_pricing!` to override any entry or add models not listed here.

## Dynamic Instructions

The `instructions` field can be a static string or a **function** that generates the system prompt dynamically at the start of each `run!` call:

```julia
# Static (default)
agent = Agent(name="Bot", instructions="You are a helpful assistant.")

# Dynamic — receives (session, agent) and must return a String
agent = Agent(
    name = "PersonalBot",
    instructions = (session, agent) -> """
        You are helping $(session.user_id).
        Their preferences: $(get(session.state, "prefs", "none set"))
        Today is $(Dates.today()).
    """,
)
```

Use cases:
- **Per-user personalization** — tailor the prompt based on `session.user_id` or `session.state`
- **RAG injection** — retrieve relevant documents and inject them into the prompt
- **Time-aware agents** — include the current date/time
- **State-dependent behavior** — switch between verbose/concise modes based on session state

When `session` is `nothing` (no session passed to `run!`), the function still receives `nothing` as the first argument — handle this in your function if needed.

## Extended Thinking & Reasoning

The `api_kwargs` field on `Agent` passes extra keyword arguments through to every PromptingTools LLM call (`aitools`, `aigenerate`, `aiextract`). This enables model-specific features like reasoning configuration.

### OpenAI Reasoning (works today)

For OpenAI o-series and reasoning-capable models, pass reasoning configuration via `api_kwargs`:

```julia
# Reasoning effort control (o3, o4-mini, etc.)
agent = Agent(
    name         = "Reasoner",
    instructions = "Think carefully and solve the problem step by step.",
    model        = "o3",
    api_kwargs   = (; reasoning = Dict("effort" => "high")),
)

result = run!(agent, "Prove that √2 is irrational.")
```

```julia
# With reasoning summary (Responses API schema)
agent = Agent(
    name         = "Analyst",
    instructions = "Analyze this data carefully.",
    model        = "o3",
    api_kwargs   = (; reasoning = Dict("effort" => "medium", "summary" => "concise")),
)
```

Reasoning tokens and reasoning content are captured in `extras[:reasoning_content]` and `extras[:reasoning_tokens]` on the response messages when using the OpenAI Responses API schema.

### Other api_kwargs Uses

`api_kwargs` works for any parameter that PromptingTools passes through to the LLM API:

```julia
# Temperature and top_p
agent = Agent(
    name         = "Creative",
    instructions = "Write creative stories.",
    model        = "gpt-5.4-mini",
    api_kwargs   = (; temperature = 1.2, top_p = 0.95),
)

# Max tokens
agent = Agent(
    name         = "Brief",
    instructions = "Be concise.",
    model        = "gpt-5.4-mini",
    api_kwargs   = (; max_tokens = 256),
)
```

### Anthropic Extended Thinking (limited support)

!!! warning "Current Limitation"
    Anthropic extended thinking is **not fully supported** due to PromptingTools.jl limitations:

    1. **Beta header blocked** — PT's Anthropic integration whitelists allowed beta headers. The required `interleaved-thinking-2025-05-14` header is not in the whitelist, so PT rejects it.
    2. **Thinking blocks discarded** — PT's response parser extracts only `:text` content blocks. Thinking blocks (which use a `:thinking` key) are silently dropped and never surfaced to the caller.
    3. **No raw response access** — PT returns parsed `AIMessage`/`AIToolRequest` objects, not the raw API response, so there is no way to retrieve thinking content after the fact.

    This will be resolved when PromptingTools.jl adds native extended thinking support. Track upstream progress for updates.

### Google Gemini

NimbleAgents includes `GeminiOpenAISchema` — a custom schema that calls the Gemini API via Google's [OpenAI-compatible endpoint](https://ai.google.dev/gemini-api/docs/openai). All Gemini models (`gemini-*`) are automatically routed through this schema.

```julia
# Just set model to any gemini-* model — it works out of the box
agent = Agent(
    name         = "GeminiBot",
    instructions = "You are a helpful assistant.",
    model        = "gemini-2.5-flash",
    tools        = [my_tool],  # tool calling works
)

result = run!(agent, "Hello!")
```

Supported features: chat completions, tool calling, structured output, streaming, and thinking/reasoning.

#### Gemini Thinking

Use `reasoning_effort` to enable Gemini's thinking mode:

```julia
agent = Agent(
    name         = "Thinker",
    instructions = "Think step by step.",
    model        = "gemini-2.5-flash",
    api_kwargs   = (; reasoning_effort = "medium"),
)
```

Valid values: `"none"`, `"minimal"`, `"low"`, `"medium"`, `"high"`.

Requires `GOOGLE_API_KEY` in your `.env` file or environment.

!!! note "Why GeminiOpenAISchema exists"
    PromptingTools.jl (v0.91.0) has a built-in `GoogleOpenAISchema`, but it has two bugs that prevent actual use:

    1. **Wrong base URL** — PT sends requests to `/v1beta/chat/completions` instead of `/v1beta/openai/chat/completions`. All requests 404.
    2. **No streaming** — PT's `GoogleOpenAISchema` does not forward the `streamcallback` parameter, so streaming always fails.

    `GeminiOpenAISchema` fixes both by overriding a single method (`OpenAI.create_chat`) with the correct URL and streaming support. Everything else — message rendering, tool calling, structured output, response parsing — is inherited from PT's `AbstractOpenAISchema`.

    This workaround will be removed once PromptingTools.jl fixes `GoogleOpenAISchema` upstream.

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

For a comprehensive guide to all multi-agent patterns — orchestrator-workers, triage/routing, fan-out, chained handoffs, and what's not yet supported — see [Multi-Agent Patterns](multi_agent.md).
