###############################################################################
# agent/tool_execution/process.jl — top-level tool execution routing
###############################################################################

function _process_tool_calls!(
    conversation,
    last_msg::AIToolRequest,
    agent::Agent,
    hooks::AgentHooks,
    tool_map,
    turn::TurnEvent,
    t_start::Float64,
    session,
    n_seeded::Int,
    approval_channel::Union{Channel{String},Nothing},
    approval_timeout::Float64,
    store::Union{AbstractSessionStore,Nothing},
    verbose::Bool,
)
    _handle_tool_interrupts!(
        conversation, last_msg, agent, hooks, approval_channel, approval_timeout, verbose
    ) || return (status=:continue, value=nothing)

    # return_direct and Handoff require immediate short-circuit, so
    # any batch containing those tools falls back to sequential.
    has_special = any(last_msg.tool_calls) do t
        obj = get(tool_map, t.name, nothing)
        !isnothing(obj) && (_is_return_direct(obj) || !isempty(agent.sub_agents))
    end
    use_parallel = !has_special && length(last_msg.tool_calls) > 1

    if use_parallel
        _execute_parallel_tool_calls!(
            conversation, last_msg, agent, hooks, tool_map, turn, session, store, verbose
        )
        return (status=:continue, value=nothing)
    end

    _execute_sequential_tool_calls!(
        conversation,
        last_msg,
        agent,
        hooks,
        tool_map,
        turn,
        t_start,
        session,
        n_seeded,
        store,
        verbose,
    )
end
