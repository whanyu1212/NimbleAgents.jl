###############################################################################
# handoff/core.jl — handoff signal and tool wrappers
###############################################################################

"""
    Handoff

A signal returned by an agent indicating that control should transfer to another
agent. Use `handoff_tool(agent)` to create a `Tool` that an agent can call to
trigger the transfer.

# Fields
- `target::Agent`: The agent to hand off to.
- `message::String`: The message to pass to the target agent (defaults to the
  current user input if empty).
- `history_filter::HandoffFilter`: How to transform conversation history on handoff.

The orchestrator loop in `run_pipeline!` detects `Handoff` results and
re-runs with the new agent automatically.
"""
struct Handoff
    target::Agent
    message::String
    history_filter::HandoffFilter
end

# Backward-compatible 2-arg constructor
Handoff(target::Agent, message::String) = Handoff(target, message, HandoffFilter())

"""
    handoff_tool(target; name, description, history_filter) -> Tool

Create a `Tool` that, when called by an agent, signals a handoff to `target`.
The LLM passes a `message` argument containing what to forward to the next agent.

# Arguments
- `target::Agent`: The agent to hand off to.
- `name::String`: Tool name (default: `"handoff_to_\$(target.name)"`).
- `description::String`: Tool description.
- `history_filter::HandoffFilter`: How to transform conversation history before
  the receiving agent sees it. Default: `HandoffFilter()` (pass full history).

# Example
```julia
billing_agent = Agent(name="Billing", instructions="Handle billing questions.")
support_agent = Agent(
    name         = "Support",
    instructions = "Triage customer requests.",
    tools        = [
        handoff_tool(billing_agent; history_filter=HandoffFilter(:strip_tools)),
    ],
)
```
"""
function handoff_tool(
    target::Agent;
    name::String="handoff_to_$(target.name)",
    description::String="Transfer the conversation to the $(target.name) agent.",
    history_filter::HandoffFilter=HandoffFilter(),
)
    params = Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "message" => Dict{String,Any}(
                "type" => "string",
                "description" => "The message or context to pass to the $(target.name) agent.",
            ),
        ),
        "required" => ["message"],
    )

    Tool(;
        name=name,
        description=description,
        parameters=params,
        callable=(message::String) -> Handoff(target, message, history_filter),
    )
end

"""
    agent_as_tool(agent; name, description, session) -> Tool

Wrap `agent` as a `Tool` that a parent (orchestrator) agent can call. The
subagent runs a full `run!` loop for each call and its result is returned as a
string back to the orchestrator.

The shared `session` is threaded through so the subagent's turns appear in the
same event log.

# Example
```julia
math_agent = Agent(name="Math", instructions="Do arithmetic.", tools=[add_tool])

orchestrator = Agent(
    name         = "Orchestrator",
    instructions = "Route requests to specialist agents.",
    tools        = [agent_as_tool(math_agent)],
)

run!(orchestrator, "What is 3 + 4?")
```
"""
function agent_as_tool(
    agent::Agent;
    name::String=agent.name,
    description::String="Call the $(agent.name) agent with a task and get its response.",
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=false,
)
    params = Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "task" => Dict{String,Any}(
                "type" => "string",
                "description" => "The task or question to send to the $(agent.name) agent.",
            ),
        ),
        "required" => ["task"],
    )

    Tool(;
        name=name,
        description=description,
        parameters=params,
        callable=(task::String) -> begin
            result = run!(agent, task; session=session, verbose=verbose)
            string(result)
        end,
    )
end
