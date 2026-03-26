###############################################################################
# agent/types/hooks.jl — lifecycle hook config and utilities
###############################################################################

"""
    AgentHooks(; before_llm_call, after_llm_call, should_interrupt, on_tool_call, on_tool_result, on_complete)

Optional lifecycle callbacks for an `Agent`. All fields default to `nothing`
(no-op). Provide a function to observe or log that event.

# Callbacks

| Field | Signature | Fired |
|---|---|---|
| `before_llm_call` | `(agent, iteration, messages) -> messages` | Before each LLM request — can modify the messages vector |
| `after_llm_call` | `(agent, iteration, response)` | After each LLM response — before any tool executes |
| `should_interrupt` | `(tool_name, args) -> Bool` | Before each tool executes — return `true` to pause and require human approval |
| `on_tool_call` | `(agent, tool_name, args)` | Before each tool is executed (after approval) |
| `on_tool_result` | `(agent, tool_name, result)` | After each tool returns |
| `on_complete` | `(agent, result)` | When `run!` is about to return |

`should_interrupt` is the recommended way to gate dangerous tools. When it returns `true`
for any pending tool call, the framework collects all flagged calls, throws a `HumanInterrupt`,
and no tools execute. Call `resume!(session, response)` then re-run `run!` to continue.

# Example — gate dangerous tools
```julia
hooks = AgentHooks(
    should_interrupt = (name, args) -> name in ["send_email", "delete_file"]
)
agent = Agent(name="Bot", instructions="...", hooks=hooks)

try
    run!(agent, "Send an email and delete the log"; session=session)
catch e
    e isa HumanInterrupt || rethrow(e)
    println(e.message)           # "About to call: send_email, delete_file"
    resume!(session, readline()) # inject human response
    run!(agent, "Send an email and delete the log"; session=session)
end
```

# Example — observability only
```julia
hooks = AgentHooks(
    on_tool_call   = (ag, name, args)   -> println("calling \$name with \$args"),
    on_tool_result = (ag, name, result) -> println("\$name returned \$result"),
    on_complete    = (ag, result)       -> println("done: \$result"),
)
```
"""
Base.@kwdef struct AgentHooks
    before_llm_call::Union{Function,Nothing} = nothing  # (agent, iteration, messages) -> messages
    after_llm_call::Union{Function,Nothing} = nothing  # (agent, iteration, response)
    should_interrupt::Union{Function,Nothing} = nothing  # (tool_name, args) -> Bool
    on_tool_call::Union{Function,Nothing} = nothing  # (agent, tool_name, args)
    on_tool_result::Union{Function,Nothing} = nothing  # (agent, tool_name, result)
    on_complete::Union{Function,Nothing} = nothing  # (agent, result)
end

# Helper — call a hook only if it is set
_fire(::Nothing, args...) = nothing
_fire(f::Function, args...) = f(args...)

"""Resolve agent instructions — static string or dynamic callable."""
_resolve_instructions(s::String, session, agent) = s
_resolve_instructions(f::Function, session, agent) = f(session, agent)::String
