###############################################################################
# agent/tool_execution/parallel.jl — parallel tool execution path
###############################################################################

function _execute_parallel_tool_calls!(
    conversation,
    last_msg::AIToolRequest,
    agent::Agent,
    hooks::AgentHooks,
    tool_map,
    turn::TurnEvent,
    session,
    store::Union{AbstractSessionStore,Nothing},
    verbose::Bool,
)
    verbose && println(
        "[$(agent.name)] executing $(length(last_msg.tool_calls)) tools in parallel"
    )
    for t in last_msg.tool_calls
        _fire(hooks.on_tool_call, agent, t.name, t.args)
    end

    tasks = map(last_msg.tool_calls) do t
        Threads.@spawn begin
            try
                (dispatch_tool(tool_map, t.name, t.args), nothing)
            catch e
                err_str = sprint(showerror, e)
                ("Error: $(err_str)", err_str)
            end
        end
    end

    # Collect results in order
    for (i, tool_msg) in enumerate(last_msg.tool_calls)
        result, err = fetch(tasks[i])
        verbose && println("[$(agent.name)] tool done: $(tool_msg.name)")

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
        result_str = string(result)
        limit = if isnothing(tool_obj)
            agent.max_tool_output
        else
            _effective_max_output(tool_obj, agent)
        end
        tool_msg.content = _trim_tool_output(result_str, limit)
        push!(conversation, tool_msg)

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
    end
    nothing
end
