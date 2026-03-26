###############################################################################
# agent/run_setup_helpers.jl — run! setup and conversation seeding helpers
###############################################################################

function _build_run_tools(agent::Agent)
    # Merge explicit tools with auto-generated handoff tools from sub_agents
    sub_tools = Tool[handoff_tool(sa) for sa in agent.sub_agents]
    all_tools = isempty(sub_tools) ? agent.tools : vcat(agent.tools, sub_tools)

    # Discover and merge skills (explicit + scanned dirs), inject read_skill tool
    all_skills = vcat(agent.skills, discover_skills(agent.skill_dirs))
    if !isempty(all_skills)
        all_tools = vcat(all_tools, [_read_skill_tool(all_skills)])
    end
    all_tools, all_skills
end

function _attach_mcp_tools(agent::Agent, all_tools)
    mcp_clients = AnyMCPClient[]
    if !isempty(agent.mcp_servers)
        mcp_tools, mcp_clients = _connect_mcp_servers(agent.mcp_servers)
        all_tools = vcat(all_tools, mcp_tools)
    end
    all_tools, mcp_clients
end

function _set_task_local_run_state(
    session::Union{Session,Nothing},
    store::Union{AbstractSessionStore,Nothing},
    memory::Union{AbstractMemoryService,Nothing},
)
    task_local_storage(:_repl_session_state, isnothing(session) ? nothing : session.state)
    task_local_storage(:_current_session, session)
    task_local_storage(:_current_store, store)
    task_local_storage(:_current_memory, memory)
    nothing
end

function _seed_conversation(agent::Agent, session, effective_input::String, all_skills)
    # Seed the conversation: system prompt (+ skill metadata + memory) + session history + user message
    system_prompt =
        _resolve_instructions(agent.instructions, session, agent) *
        _skills_prompt(all_skills) *
        _memory_prompt(agent.memory, effective_input, session)
    AbstractMessage[
        SystemMessage(system_prompt),
        (isnothing(session) ? AbstractMessage[] : session.history)...,
        UserMessage(effective_input),
    ]
end
