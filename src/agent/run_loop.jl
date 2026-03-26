###############################################################################
# agent/run_loop.jl — main run! orchestration loop
###############################################################################

"""
    run!(agent, input; session, verbose, on_token, approval_channel, approval_timeout) -> Union{String, Any}

Run the agent loop on `input`.

- If `agent.output_type` is `nothing` → returns a `String`.
- If `agent.output_type` is set → returns an instance of that type.

# Arguments
- `session::Union{Session, Nothing}`: Pass a `Session` to retain conversation
  history, key-value state, and an event log across calls.
- `verbose::Bool`: Print iteration info (default `true`).
- `on_token::Union{Function, Nothing}`: When set, the **final** LLM response is
  streamed token-by-token. `on_token(token::String)` is called for each chunk as
  it arrives. Tool-call rounds are always blocking (streaming + tool calls are not
  supported by the underlying API). Pass `on_token = token -> print(token)` to
  stream directly to the terminal.
- `approval_channel::Union{Channel{String}, Nothing}`: When set alongside
  `should_interrupt`, the agent **pauses** mid-loop waiting for a response on
  this channel instead of throwing `HumanInterrupt`. Use this for non-blocking
  approval flows (web servers, notebooks, GUIs) where the human's response
  arrives asynchronously from another thread or HTTP handler.
  Put `"approve"` to proceed, any other string to redirect, or close the channel
  to abort. The agent holds all its state while waiting — no re-run needed.
- `approval_timeout::Float64`: Seconds to wait for a response on
  `approval_channel` before throwing an `ApprovalTimeout` error (default: `300.0`).

# Example — CLI (blocking, throw-based)
```julia
run!(agent, "Write a short poem"; on_token = token -> print(token))
```

# Example — async approval (non-blocking, channel-based)
```julia
ch   = Channel{String}(1)
task = Threads.@spawn run!(agent, input; session=session, approval_channel=ch)
# agent is paused waiting for approval — this thread is free
put!(ch, "approve")   # unblocks the agent from anywhere
result = fetch(task)
```
"""
function run!(
    agent::Agent,
    input::String;
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=true,
    on_token::Union{Function,Nothing}=nothing,
    approval_channel::Union{Channel{String},Nothing}=nothing,
    approval_timeout::Float64=300.0,
    store::Union{AbstractSessionStore,Nothing}=nothing,
)
    all_tools, all_skills = _build_run_tools(agent)
    all_tools, mcp_clients = _attach_mcp_tools(agent, all_tools)

    tool_map = build_tool_map(all_tools)
    hooks = agent.hooks
    t_start = time()

    # Expose session and store to built-in tools via task-local storage so
    # they can access per-session state without explicit parameter threading.
    _set_task_local_run_state(session, store, agent.memory)

    # Build a TurnEvent to accumulate per-turn metadata
    turn = TurnEvent(agent.name, agent.model, input)

    try

        # Compact session history if it is approaching the context window limit
        !isnothing(session) && compact!(session, agent)

        # ── Input guardrails ────────────────────────────────────────────────────
        effective_input = try
            _run_guardrails(agent.guardrails, :input, input, agent.name, verbose)
        catch e
            e isa GuardrailBlocked || rethrow()
            resolved = _resolve_instructions(agent.instructions, session, agent)
            return _finish!(
                e.reason,
                turn,
                t_start,
                session,
                AbstractMessage[SystemMessage(resolved), UserMessage(input)],
                2,
                hooks,
                agent,
                store,
            )
        end

        conversation = _seed_conversation(agent, session, effective_input, all_skills)
        n_seeded = length(conversation)

        for iteration in 1:agent.max_iterations
            verbose && println("[$(agent.name)] iteration $iteration")

            # ── Structured output with no tools: skip tool loop entirely ───────
            if isnothing(agent.output_type) || !isempty(all_tools)
                if !isnothing(hooks.before_llm_call)
                    conversation = hooks.before_llm_call(agent, iteration, conversation)
                end
                _acquire_rate_limit!(agent.model)

                cache_kw = isnothing(agent.cache) ? (;) : (; cache=agent.cache)
                conversation = _with_retry(agent.retry, agent.name) do
                    _run_aitools(
                        conversation;
                        tools=all_tools,
                        model=agent.model,
                        return_all=true,
                        verbose=false,
                        agent.api_kwargs...,
                        cache_kw...,
                    )
                end

                last_msg = conversation[end]
                turn.llm_calls += 1
                _accumulate_usage!(turn, last_msg)
                _fire(hooks.after_llm_call, agent, iteration, last_msg)

                # Tool call response → execute each tool, append results, loop.
                if last_msg isa AIToolRequest && !isempty(last_msg.tool_calls)
                    outcome = _process_tool_calls!(
                        conversation,
                        last_msg,
                        agent,
                        hooks,
                        tool_map,
                        turn,
                        t_start,
                        session,
                        n_seeded,
                        approval_channel,
                        approval_timeout,
                        store,
                        verbose,
                    )
                    outcome.status === :return && return outcome.value
                    continue
                end
            end

            # ── Final response reached ─────────────────────────────────────────
            if !isnothing(agent.output_type)
                result = _extract_output(agent, conversation, verbose)
                return _finish!(
                    result,
                    turn,
                    t_start,
                    session,
                    conversation,
                    n_seeded,
                    hooks,
                    agent,
                    store,
                )
            end

            result, conversation = _final_text_result!(
                conversation, agent, all_tools, on_token, turn
            )
            isnothing(result) && break

            result = _apply_output_guardrails(
                result,
                agent,
                turn,
                t_start,
                session,
                conversation,
                n_seeded,
                hooks,
                store,
                verbose,
            )
            return _finish!(
                result, turn, t_start, session, conversation, n_seeded, hooks, agent, store
            )
        end

        println(stderr, "[$(agent.name)] reached max_iterations ($(agent.max_iterations))")
        return _finish_after_max_iterations!(
            conversation, agent, verbose, turn, t_start, session, n_seeded, hooks, store
        )

    finally
        _close_mcp_clients(mcp_clients)
    end
end
