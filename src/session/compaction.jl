###############################################################################
# session/compaction.jl — context-window management
###############################################################################

# ──────────────────────────────────────────────────────────────────────────────
# Context-window management (hybrid summarise-and-compress)
# ──────────────────────────────────────────────────────────────────────────────

# Estimate tokens for a single message.
# Uses the real token count from the PT response when available (accurate),
# and falls back to the standard ~4 chars/token heuristic for unprocessed msgs.
function _estimate_tokens(msg::AbstractMessage)::Int
    # Only AIMessage and AIToolRequest carry a real token count from the API
    if hasproperty(msg, :tokens)
        t = msg.tokens
        if !isnothing(t) && t != (0, 0)
            return sum(t)
        end
    end
    # ~4 chars per token — OpenAI's own recommended estimation heuristic
    ceil(Int, length(something(msg.content, "")) / 4)
end

# Total estimated tokens across the full history.
function _history_tokens(session::Session)
    sum(_estimate_tokens(m) for m in session.history; init=0)
end

"""
    compact!(session, agent) -> Bool

Check whether `session.history` is approaching the model's context limit and,
if so, compress older messages into a summary while keeping the most recent
`agent.context.keep_last` messages verbatim.

Returns `true` if compaction was performed, `false` otherwise.

The hybrid strategy:
- Recent messages (`keep_last`) are always preserved — they carry the
  immediate context the model needs.
- Older messages are replaced by a single LLM-generated summary injected
  as a `UserMessage` tagged `[Conversation Summary]`.

Compaction is triggered when estimated token usage exceeds
`context_window × compact_threshold` (default: 80% of 400k = 320k tokens).
"""
function compact!(session::Session, agent)
    cfg = agent.context
    threshold = floor(Int, cfg.context_window * cfg.compact_threshold)

    total = _history_tokens(session)
    total < threshold && return false

    history = session.history
    n = length(history)

    # Not enough messages to split — nothing useful to summarise
    n <= cfg.keep_last && return false

    old_msgs = history[1:(n - cfg.keep_last)]
    keep_msgs = history[(n - cfg.keep_last + 1):end]

    println(
        "[$(agent.name)] context compaction triggered: estimated_tokens=$(total) threshold=$(threshold) old=$(length(old_msgs)) kept=$(length(keep_msgs))",
    )

    # Build a plain-text transcript of the older messages for the summariser
    transcript = join(
        ["$(nameof(typeof(m))): $(something(m.content, ""))" for m in old_msgs], "\n"
    )

    summary_model = something(cfg.summary_model, agent.model)

    summary_msg = _run_aigenerate(
        """You are a conversation summariser. Produce a concise but complete summary
of the following conversation history. Preserve all key facts, decisions, tool
results, and context that would be needed to continue the conversation coherently.

Conversation to summarise:
$(transcript)

Write the summary in third person, past tense. Be thorough — omitting important
details defeats the purpose.""";
        model=summary_model,
        verbose=false,
    )

    summary_text = something(summary_msg.content, "")

    # Replace history: summary placeholder + recent verbatim messages
    summary_placeholder = UserMessage(
        "[Conversation Summary — $(length(old_msgs)) messages compressed]\n\n$(summary_text)",
    )

    lock(session.lock) do
        empty!(session.history)
        push!(session.history, summary_placeholder)
        append!(session.history, keep_msgs)
    end

    println(
        "[$(agent.name)] compaction complete: new_history_length=$(length(session.history))"
    )
    return true
end
