###############################################################################
# agent/tool_execution/sequential.jl — sequential tool execution path
###############################################################################

function _execute_sequential_tool_calls!(
    conversation,
    last_msg::AIToolRequest,
    agent::Agent,
    hooks::AgentHooks,
    tool_map,
    turn::TurnEvent,
    t_start::Float64,
    session,
    n_seeded::Int,
    store::Union{AbstractSessionStore,Nothing},
    verbose::Bool,
)
    for tool_msg in last_msg.tool_calls
        verbose && println("[$(agent.name)] calling tool: $(tool_msg.name)")
        _fire(hooks.on_tool_call, agent, tool_msg.name, tool_msg.args)

        result = nothing
        err = nothing
        try
            result = dispatch_tool(tool_map, tool_msg.name, tool_msg.args)
        catch e
            err = sprint(showerror, e)
            result = "Error: $(err)"
        end

        push!(
            turn.tool_calls,
            if isnothing(err)
                ToolEvent(
                    tool_msg.name, something(tool_msg.args, Dict{Symbol,Any}()), result
                )
            else
                ToolEvent(
                    tool_msg.name, something(tool_msg.args, Dict{Symbol,Any}()); error=err
                )
            end,
        )

        _fire(hooks.on_tool_result, agent, tool_msg.name, result)

        tool_obj = get(tool_map, tool_msg.name, nothing)
        result_str = if result isa Handoff
            if isempty(result.message)
                "Handed off to $(result.target.name)."
            else
                "Handed off to $(result.target.name): $(result.message)"
            end
        else
            string(result)
        end
        limit = if isnothing(tool_obj)
            agent.max_tool_output
        else
            _effective_max_output(tool_obj, agent)
        end
        tool_msg.raw = result
        tool_msg.content = _trim_tool_output(result_str, limit)
        push!(conversation, tool_msg)

        # Handoff: persist the matching tool result message before surfacing so
        # downstream OpenAI-compatible providers see a valid assistant tool-call /
        # tool-result pair in history.
        if result isa Handoff
            _finish!(
                result, turn, t_start, session, conversation, n_seeded, hooks, agent, store
            )
            return (status=:return, value=result)
        end

        # return_artifact: register result as a session artifact
        if !isnothing(tool_obj) &&
            _is_return_artifact(tool_obj) &&
            isnothing(err) &&
            !isnothing(session) &&
            result isa AbstractString &&
            isfile(result)
            register_artifact!(
                session,
                string(result);
                metadata=Dict{String,Any}("tool" => tool_msg.name),
                store=store,
            )
        end

        # return_direct: skip the next LLM call and return immediately.
        if !isnothing(tool_obj) && _is_return_direct(tool_obj) && isnothing(err)
            verbose && println(
                "[$(agent.name)] return_direct — short-circuiting after $(tool_msg.name)",
            )
            return (
                status=:return,
                value=_finish!(
                    result,
                    turn,
                    t_start,
                    session,
                    conversation,
                    n_seeded,
                    hooks,
                    agent,
                    store,
                ),
            )
        end
    end

    (status=:continue, value=nothing)
end
