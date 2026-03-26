###############################################################################
# web/server/handlers/chat.jl — /chat handler
###############################################################################

function _agent_with_web_hooks(base_agent::Agent, run::RunState)
    web_hooks = _web_hooks(run)

    # Merge web hooks with any user-defined hooks on the agent
    merged_hooks = AgentHooks(;
        before_llm_call=base_agent.hooks.before_llm_call,
        after_llm_call=base_agent.hooks.after_llm_call,
        should_interrupt=base_agent.hooks.should_interrupt,
        on_tool_call=(ag, name, args) -> begin
            isnothing(base_agent.hooks.on_tool_call) ||
                base_agent.hooks.on_tool_call(ag, name, args)
            web_hooks.on_tool_call(ag, name, args)
        end,
        on_tool_result=(ag, name, result) -> begin
            isnothing(base_agent.hooks.on_tool_result) ||
                base_agent.hooks.on_tool_result(ag, name, result)
            web_hooks.on_tool_result(ag, name, result)
        end,
        on_complete=base_agent.hooks.on_complete,
    )

    Agent(;
        name=base_agent.name,
        instructions=base_agent.instructions,
        tools=base_agent.tools,
        model=base_agent.model,
        max_iterations=base_agent.max_iterations,
        output_type=base_agent.output_type,
        api_kwargs=base_agent.api_kwargs,
        sub_agents=base_agent.sub_agents,
        retry=base_agent.retry,
        context=base_agent.context,
        hooks=merged_hooks,
        skills=base_agent.skills,
        skill_dirs=base_agent.skill_dirs,
        mcp_servers=base_agent.mcp_servers,
        guardrails=base_agent.guardrails,
        memory=base_agent.memory,
        max_tool_output=base_agent.max_tool_output,
        cache=base_agent.cache,
    )
end

function _spawn_web_chat!(
    run::RunState,
    run_id::String,
    agent::Agent,
    input::String,
    session::Session,
    store::AbstractSessionStore,
)
    # Collect tokens into buffer for streaming
    token_buf = IOBuffer()

    run.task = Threads.@spawn begin
        try
            result = run!(
                agent,
                input;
                session=session,
                store=store,
                verbose=false,
                approval_channel=run.approval_channel,
                on_token=tok -> begin
                    print(token_buf, tok)
                    _push_event(run, "token", tok)
                end,
            )
            run.result = string(result)
            run.status = :done
            println(
                "[NimbleAgents] run=$(run_id) — done, result length=$(length(run.result))"
            )
            _push_event(run, "done", Dict("result" => run.result))
        catch e
            if e isa ApprovalTimeout
                run.status = :error
                msg = "Approval timed out after $(e.timeout)s"
                println("[NimbleAgents] run=$(run_id) — approval timeout")
                _push_event(run, "error", Dict("message" => msg))
            else
                run.status = :error
                msg = sprint(showerror, e)
                println("[NimbleAgents] run=$(run_id) — error: $(msg)")
                println(stderr, sprint(Base.show_backtrace, catch_backtrace()))
                _push_event(run, "error", Dict("message" => msg))
            end
        finally
            close(run.event_channel)
        end
    end
    nothing
end

function _handle_chat(req::HTTP.Request)
    body = JSON3.read(String(req.body), Dict{String,Any})

    agent_id = something(get(body, "agent_id", nothing), "")
    session_id = something(get(body, "session_id", nothing), "")
    input = something(get(body, "input", nothing), "")

    haskey(_agents, agent_id) || return HTTP.Response(400, "Unknown agent: $(agent_id)")
    isempty(input) && return HTTP.Response(400, "input is required")

    # Resolve or create session
    store = _store[]
    session = if isempty(session_id)
        nothing
    else
        load(store, session_id)
    end
    if isnothing(session)
        session = Session(; app_name=agent_id, user_id="web")
        session_id = session.id
        save!(store, session)
    end

    run_id = string(uuid4())
    run = RunState(session_id)
    _runs[run_id] = run
    println(
        "[NimbleAgents] run=$(run_id) session=$(session_id) agent=$(agent_id) — starting"
    )

    agent = _agent_with_web_hooks(_agents[agent_id], run)
    _spawn_web_chat!(run, run_id, agent, input, session, store)

    HTTP.Response(
        200,
        ["Content-Type" => "application/json"];
        body=JSON3.write(Dict("run_id" => run_id, "session_id" => session_id)),
    )
end
