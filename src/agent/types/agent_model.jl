###############################################################################
# agent/types/agent_model.jl — Agent configuration model
###############################################################################

"""
    Agent(; name, instructions, tools, model, max_iterations, output_type, hooks)

A configured AI agent with a system prompt, a set of tools, and a model.

# Fields
- `name::String`: Human-readable name for the agent.
- `instructions::Union{String, Function}`: The system prompt — what the agent does and
  how it behaves. Can be a static `String` or a callable `(session, agent) -> String`
  for dynamic prompts (e.g. per-user context, RAG injection, time-aware instructions).
- `tools::Vector{Tool}`: Tools the agent can call.
- `model::String`: Model identifier (default: `"gpt-5.4-mini"`).
- `max_iterations::Int`: Maximum number of LLM calls before the loop stops (default: `10`).
- `output_type::Union{Type, Nothing}`: When set, the final response is parsed into this
  Julia struct instead of returned as a plain `String`.
- `api_kwargs::NamedTuple`: Extra keyword arguments passed through to every internal
  LLM call (`aitools`, `aigenerate`, `aiextract`). Use this for model-specific features
  like OpenAI or Gemini reasoning config (default: `NamedTuple()`).
- `hooks::AgentHooks`: Optional lifecycle callbacks (default: all no-ops).
- `sub_agents::Vector{Agent}`: Child agents the LLM can hand off to. A `handoff_tool` is
  generated automatically for each one — no manual wiring needed.
- `retry::RetryConfig`: Exponential-backoff retry policy for LLM API calls (default: 3
  retries, 0.5s–60s window). Set `retry=RetryConfig(max_retries=0)` to disable.
- `context::ContextConfig`: Context-window management policy. When `session.history`
  exceeds `context.compact_threshold × context.context_window` tokens, older messages
  are summarised and replaced, keeping the most recent `context.keep_last` messages
  verbatim.
- `skills::Vector{Skill}`: Explicitly attached skills. Metadata is injected into the
  system prompt; full instructions are loaded on demand via the built-in `read_skill` tool.
- `skill_dirs::Vector{String}`: Directories to scan for skill subdirectories at run time.
  Discovered skills are merged with any explicitly listed in `skills`.
- `max_tool_output::Int`: Global character limit for tool result strings inserted into
  the conversation (default: `0` = unlimited). When a tool result exceeds this limit, it
  is trimmed with head+tail preservation and an informative gap marker. Per-tool limits
  (`NimbleTool.max_output`) override this when set.
- `cache::Union{Nothing, Symbol}`: Reserved for provider-specific prompt caching
  strategies. Cached tokens are tracked in `TurnEvent.cache_read_tokens` and
  `cache_write_tokens` when the provider returns them.

# Example — plain text output
```julia
@tool function add(x::Int, y::Int)
    "Add two integers."
    x + y
end

agent = Agent(
    name         = "MathBot",
    instructions = "You are a helpful assistant that can do arithmetic.",
    tools        = [add_tool],
)

result = run!(agent, "What is 3 + 4?")  # String
```

# Example — with session memory
```julia
session = Session(app_name="MyApp", user_id="alice")
run!(agent, "What is 8 + 14?"; session=session)
run!(agent, "Now multiply that by 3"; session=session)  # remembers 22
```
"""
Base.@kwdef struct Agent
    name::String
    instructions::Union{String,Function}
    tools::Vector{<:AbstractTool} = NimbleTool[]
    model::String = "gpt-5.4-mini"
    max_iterations::Int = 10
    output_type::Union{Type,Nothing} = nothing
    api_kwargs::NamedTuple = NamedTuple()
    hooks::AgentHooks = AgentHooks()
    sub_agents::Vector{Agent} = Agent[]
    retry::RetryConfig = RetryConfig()
    context::ContextConfig = ContextConfig()
    skills::Vector{Skill} = Skill[]
    skill_dirs::Vector{String} = String[]
    mcp_servers::Vector{MCPServer} = MCPServer[]
    guardrails::Vector{Guardrail} = Guardrail[]
    memory::Union{AbstractMemoryService,Nothing} = nothing
    max_tool_output::Int = 0  # 0 = unlimited
    cache::Union{Nothing,Symbol} = nothing  # prompt caching: :all, :system, :last, :tools, etc.
end
