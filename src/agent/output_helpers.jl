###############################################################################
# agent/output_helpers.jl — finalization, streaming, and structured output
###############################################################################

# Run output guardrails on a string result. Returns either the (possibly
# modified) string, or the block reason if a guardrail fires.
function _apply_output_guardrails(
    result,
    agent::Agent,
    turn,
    t_start,
    session,
    conversation,
    n_seeded,
    hooks,
    store,
    verbose,
)
    result isa String || return result   # only applies to string outputs
    isempty(agent.guardrails) && return result
    try
        _run_guardrails(agent.guardrails, :output, result, agent.name, verbose)
    catch e
        e isa GuardrailBlocked || rethrow()
        e.reason
    end
end

# Finalise a turn: stamp elapsed time, save to session, fire on_complete, return result.
function _finish!(
    result,
    turn::TurnEvent,
    t_start::Float64,
    session,
    conversation,
    n_seeded::Int,
    hooks::AgentHooks,
    agent::Agent,
    store::Union{AbstractSessionStore,Nothing}=nothing,
)
    turn.output = result
    turn.elapsed = time() - t_start

    if !isnothing(session)
        lock(session.lock) do
            _save_history!(session, conversation, n_seeded)
            push!(session.events, turn)
        end
        # Auto-persist if a store is configured
        !isnothing(store) && save!(store, session)
    end

    _fire(hooks.on_complete, agent, result)
    return result
end

# Stream the final LLM response token-by-token.
# Uses a Channel as the StreamCallback sink — PT writes each token chunk into it,
# a background task drains the channel and calls on_token for each chunk.
# Returns the completed conversation (same shape as the blocking aitools call).
function _stream_final!(conversation, agent::Agent, all_tools, on_token::Function)
    ch = Channel{String}(256)
    # Drain the channel in a background task so PT can keep writing without blocking
    drain = Threads.@spawn begin
        for tok in ch
            ;
            on_token(tok);
        end
    end
    cb = StreamCallback(ch)

    # aitools does not support streamcallback — use aigenerate for the final
    # streaming pass (tool calls have already been resolved by this point).
    cache_kw = isnothing(agent.cache) ? (;) : (; cache=agent.cache)
    _acquire_rate_limit!(agent.model)
    result = _with_retry(agent.retry, agent.name) do
        _run_aigenerate(
            conversation;
            model=agent.model,
            return_all=true,
            verbose=false,
            streamcallback=cb,
            agent.api_kwargs...,
            cache_kw...,
        )
    end

    close(ch)
    wait(drain)
    return result
end

function _extract_text_result(last_msg, agent_name::String)::Union{String,Nothing}
    if last_msg isa AIMessage
        return something(last_msg.content, "")
    end
    if last_msg isa AIToolRequest
        return something(last_msg.content, "")
    end
    println(stderr, "[$(agent_name)] unexpected message type: $(typeof(last_msg))")
    nothing
end

function _final_text_result!(
    conversation,
    agent::Agent,
    all_tools,
    on_token::Union{Function,Nothing},
    turn::TurnEvent,
)
    # If streaming is requested, re-run the final call with a StreamCallback so
    # tokens flow to on_token as they are generated. We drop the blocking final
    # message and redo the call in streaming mode.
    if !isnothing(on_token)
        conversation = _stream_final!(conversation[1:(end - 1)], agent, all_tools, on_token)
        turn.llm_calls += 1
        _accumulate_usage!(turn, conversation[end])
    end
    _extract_text_result(conversation[end], agent.name), conversation
end

function _fallback_text_result(conversation)::String
    for msg in Iterators.reverse(conversation)
        if msg isa AIMessage
            return something(msg.content, "")
        end
        if msg isa AIToolRequest && !isnothing(msg.content)
            return string(msg.content)
        end
    end
    ""
end

function _finish_after_max_iterations!(
    conversation,
    agent::Agent,
    verbose::Bool,
    turn::TurnEvent,
    t_start::Float64,
    session,
    n_seeded::Int,
    hooks::AgentHooks,
    store::Union{AbstractSessionStore,Nothing},
)
    if !isnothing(agent.output_type)
        result = _extract_output(agent, conversation, verbose)
        return _finish!(
            result, turn, t_start, session, conversation, n_seeded, hooks, agent, store
        )
    end
    _finish!(
        _fallback_text_result(conversation),
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

# Pass the full conversation to aiextract so the model has all context
# (including any tool results) when generating the structured response.
# On parse failure, feed the error back to the LLM and retry up to
# retry.max_parse_retries times before giving up.
function _extract_output(agent::Agent, conversation, verbose::Bool)
    verbose &&
        println("[$(agent.name)] extracting structured output as $(agent.output_type)")

    ctx = copy(conversation)

    cache_kw = isnothing(agent.cache) ? (;) : (; cache=agent.cache)
    for attempt in 1:(agent.retry.max_parse_retries + 1)
        _acquire_rate_limit!(agent.model)
        msg = _with_retry(agent.retry, agent.name) do
            _run_aiextract(
                ctx;
                return_type=agent.output_type,
                model=agent.model,
                verbose=false,
                agent.api_kwargs...,
                cache_kw...,
            )
        end

        # Success: content is the expected type
        if msg.content isa agent.output_type
            return msg.content
        end

        # Parse failed — content is nothing or wrong type
        parse_err = if isnothing(msg.content)
            "aiextract returned nothing — the response could not be parsed into $(agent.output_type)."
        else
            "aiextract returned a $(typeof(msg.content)) instead of the expected $(agent.output_type)."
        end

        if attempt > agent.retry.max_parse_retries
            error(
                "[$(agent.name)] structured output parse failed after $(attempt) attempt(s): $(parse_err)",
            )
        end

        verbose && println(
            "[$(agent.name)] parse attempt $(attempt) failed — re-prompting. $(parse_err)",
        )

        # Feed the error back so the model can correct its response
        push!(
            ctx,
            UserMessage(
                "Your previous response could not be parsed into the required format. " *
                "Error: $(parse_err)\n" *
                "Please respond again, strictly following the $(agent.output_type) schema.",
            ),
        )
    end
end
