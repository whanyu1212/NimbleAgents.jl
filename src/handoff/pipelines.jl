###############################################################################
# handoff/pipelines.jl — handoff and round-robin orchestration loops
###############################################################################

"""
    run_pipeline!(agent, input; session, verbose, max_handoffs) -> Any

Like `run!` but with automatic handoff support. When a tool returns a
`Handoff`, the pipeline transparently re-runs with the target agent and the
forwarded message. The loop stops when the active agent returns a plain result
(not a `Handoff`) or `max_handoffs` is reached.

# Arguments
- `agent::Agent`: The starting agent.
- `input::String`: The initial user message.
- `session`: Optional shared `Session` across all agents in the pipeline.
- `verbose::Bool`: Print handoff transitions (default `true`).
- `max_handoffs::Int`: Safety cap on the number of handoffs (default `10`).

# Example
```julia
result = run_pipeline!(triage_agent, "I need help with my bill";
                       session=session)
```
"""
function run_pipeline!(
    agent::Agent,
    input::String;
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=true,
    max_handoffs::Int=10,
)
    current_agent = agent
    current_input = input
    handoff_count = 0

    while true
        result = run!(current_agent, current_input; session=session, verbose=verbose)

        # Not a handoff — we're done
        result isa Handoff || return result

        handoff_count += 1
        if handoff_count > max_handoffs
            println(stderr, "[run_pipeline!] reached max_handoffs ($max_handoffs); stopping.")
            return result.message
        end

        verbose && println("[run_pipeline!] handoff: $(current_agent.name) → $(result.target.name)")

        # Apply history filter before handing off
        if !isnothing(session) && result.history_filter.kind != :all
            session.history = _apply_handoff_filter(result.history_filter, session.history)
        end

        current_agent = result.target
        current_input = isempty(result.message) ? current_input : result.message
    end
end

"""
    loop_pipeline!(agents, input; stop_when, max_rounds, session, verbose) -> Any

Run `agents` in round-robin order, feeding each agent's output as the next
agent's input, until `stop_when` returns `true` or `max_rounds` is reached.

Each "round" consists of one pass through all agents in order. After every
individual agent run, `stop_when(agent, result)` is checked — if it returns
`true`, the loop ends immediately and that result is returned.

# Arguments
- `agents::Vector{Agent}`: Agents to cycle through in order.
- `input::String`: The initial user message.
- `stop_when`: A function `(agent, result) -> Bool` that signals termination.
  Default: always `false` (loop runs until `max_rounds`).
- `max_rounds::Int`: Safety cap on the number of full rounds (default `5`).
- `session`: Optional shared `Session` across all agents.
- `verbose::Bool`: Print round/agent transitions (default `true`).

# Example
```julia
coder    = Agent(name="Coder",    instructions="Write code based on the task.")
reviewer = Agent(name="Reviewer", instructions="Review code. Say APPROVED if good.")

result = loop_pipeline!(
    [coder, reviewer],
    "Write a fibonacci function";
    max_rounds = 5,
    stop_when  = (agent, result) -> occursin("APPROVED", string(result)),
    session    = Session(),
)
```
"""
function loop_pipeline!(
    agents::Vector{Agent},
    input::String;
    stop_when=(agent, result) -> false,
    max_rounds::Int=5,
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=true,
)
    isempty(agents) && error("loop_pipeline!: agents list must not be empty")

    current_input = input

    for round in 1:max_rounds
        verbose && println("[loop_pipeline!] round $round/$max_rounds")

        for agent in agents
            result = run!(agent, current_input; session=session, verbose=verbose)

            if stop_when(agent, result)
                verbose && println(
                    "[loop_pipeline!] stop_when triggered by $(agent.name) in round $round",
                )
                return result
            end

            current_input = string(result)
        end
    end

    verbose && println(
        stderr,
        "[loop_pipeline!] reached max_rounds ($max_rounds); returning last result.",
    )
    # Return the result of the last agent in the last round
    return current_input
end
