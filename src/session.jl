###############################################################################
# session.jl — Session, state, and event log (inspired by Google ADK)
###############################################################################

import PromptingTools as PT

# ──────────────────────────────────────────────────────────────────────────────
# ToolEvent — record of a single tool call within a turn
# ──────────────────────────────────────────────────────────────────────────────

"""
    ToolEvent

A record of one tool call made during a `run!` turn.

# Fields
- `name::String`: Tool name.
- `args::Dict{Symbol,Any}`: Arguments passed to the tool.
- `result::Any`: Return value (or `nothing` if an error occurred).
- `error::Union{String,Nothing}`: Error message if the tool threw, otherwise `nothing`.
- `timestamp::Float64`: `time()` when the tool was called.
"""
struct ToolEvent
    name     ::String
    args     ::Dict{Symbol, Any}
    result   ::Any
    error    ::Union{String, Nothing}
    timestamp::Float64
end

ToolEvent(name, args, result) =
    ToolEvent(name, args, result, nothing, time())
ToolEvent(name, args; error::String) =
    ToolEvent(name, args, nothing, error, time())

# ──────────────────────────────────────────────────────────────────────────────
# TurnEvent — record of one complete run! call
# ──────────────────────────────────────────────────────────────────────────────

"""
    TurnEvent

A record of one complete `run!` invocation — one "turn" in the conversation.

# Fields
- `agent::String`: Name of the agent that handled this turn.
- `input::String`: The user message for this turn.
- `output::Any`: The final response returned by `run!`.
- `tool_calls::Vector{ToolEvent}`: All tool calls made during this turn, in order.
- `llm_calls::Int`: Number of LLM requests made.
- `input_tokens::Int`: Total input tokens used across all LLM calls this turn.
- `output_tokens::Int`: Total output tokens used across all LLM calls this turn.
- `elapsed::Float64`: Wall-clock time in seconds for the whole turn.
- `timestamp::Float64`: `time()` when `run!` was called.
"""
mutable struct TurnEvent
    agent        ::String
    input        ::String
    output       ::Any
    tool_calls   ::Vector{ToolEvent}
    llm_calls    ::Int
    input_tokens ::Int
    output_tokens::Int
    elapsed      ::Float64
    timestamp    ::Float64
end

TurnEvent(agent::String, input::String) =
    TurnEvent(agent, input, nothing, ToolEvent[], 0, 0, 0, 0.0, time())

# ──────────────────────────────────────────────────────────────────────────────
# Session
# ──────────────────────────────────────────────────────────────────────────────

"""
    Session(; id, app_name, user_id)

An in-memory session that persists conversation state across multiple `run!` calls.

Inspired by Google ADK's Session model. Holds three things:

- **`history`** — the message log the LLM sees on every turn
- **`state`** — a free-form key-value store for cross-turn variables
- **`events`** — an audit log of every turn (inputs, outputs, tool calls, token usage)

# Fields
- `id::String`: Unique session identifier (auto-generated UUID if not provided).
- `app_name::String`: Name of the application using this session.
- `user_id::String`: Identifier for the user (default `"default"`).
- `history::Vector{PT.AbstractMessage}`: Accumulated message history.
- `state::Dict{String,Any}`: Cross-turn key-value store.
- `events::Vector{TurnEvent}`: Ordered log of every completed turn.
- `created_at::Float64`: `time()` when the session was created.
- `lock::ReentrantLock`: Protects `history` and `events` for concurrent `fan_out` / `spawn_subagents` calls.

# Example
```julia
session = Session(app_name="MathApp", user_id="alice")

run!(agent, "What is 8 + 14?"; session=session)
run!(agent, "Now multiply that by 3"; session=session)

# Inspect history
length(session)           # number of messages
session.state["score"]    # cross-turn variable set by a tool or hook
session.events[1]         # TurnEvent for the first run! call
```
"""
mutable struct Session
    id          ::String
    app_name    ::String
    user_id     ::String
    history     ::Vector{PT.AbstractMessage}
    state       ::Dict{String, Any}
    events      ::Vector{TurnEvent}
    artifacts   ::Vector{Any}   # Vector{Artifact} — typed after artifacts.jl loads
    created_at  ::Float64
    lock        ::ReentrantLock
end

function Session(;
    id       ::String = string(Base.UUID(rand(UInt128))),
    app_name ::String = "NimbleAgents",
    user_id  ::String = "default",
)
    Session(id, app_name, user_id, PT.AbstractMessage[], Dict{String,Any}(),
            TurnEvent[], Any[], time(), ReentrantLock())
end

Base.length(s::Session)  = length(s.history)
Base.isempty(s::Session) = isempty(s.history)

"""
    reset!(session)

Clear history, state, and events from the session. Preserves id/app_name/user_id.
"""
function reset!(s::Session)
    empty!(s.history)
    empty!(s.state)
    empty!(s.events)
    empty!(s.artifacts)
    return s
end

# ──────────────────────────────────────────────────────────────────────────────
# Internal helpers called from agent.jl
# ──────────────────────────────────────────────────────────────────────────────

# Save new messages from this turn into session.history.
# Skips the system message (re-injected fresh each turn) and the messages that
# were already in the conversation when this turn started (n_seeded).
function _save_history!(session::Session, conversation, n_seeded::Int)
    for msg in conversation[(n_seeded + 1):end]
        msg isa PT.SystemMessage && continue
        push!(session.history, msg)
    end
end

# Accumulate token usage from a PT response message into a TurnEvent.
function _accumulate_usage!(turn::TurnEvent, msg)
    usage = msg.usage
    isnothing(usage) && return
    turn.input_tokens  += something(usage.input_tokens,  0)
    turn.output_tokens += something(usage.output_tokens, 0)
end

# ──────────────────────────────────────────────────────────────────────────────
# Context-window management (hybrid summarise-and-compress)
# ──────────────────────────────────────────────────────────────────────────────

# Estimate tokens for a single message.
# Uses the real token count from the PT response when available (accurate),
# and falls back to the standard ~4 chars/token heuristic for unprocessed msgs.
function _estimate_tokens(msg::PT.AbstractMessage)::Int
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
_history_tokens(session::Session) = sum(_estimate_tokens(m) for m in session.history; init=0)

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

    old_msgs  = history[1:(n - cfg.keep_last)]
    keep_msgs = history[(n - cfg.keep_last + 1):end]

    println("[$(agent.name)] context compaction triggered: estimated_tokens=$(total) threshold=$(threshold) old=$(length(old_msgs)) kept=$(length(keep_msgs))")

    # Build a plain-text transcript of the older messages for the summariser
    transcript = join(
        ["$(nameof(typeof(m))): $(something(m.content, ""))" for m in old_msgs],
        "\n",
    )

    summary_model = something(cfg.summary_model, agent.model)

    summary_msg = PT.aigenerate(
        """You are a conversation summariser. Produce a concise but complete summary
of the following conversation history. Preserve all key facts, decisions, tool
results, and context that would be needed to continue the conversation coherently.

Conversation to summarise:
$(transcript)

Write the summary in third person, past tense. Be thorough — omitting important
details defeats the purpose.""";
        model   = summary_model,
        verbose = false,
    )

    summary_text = something(summary_msg.content, "")

    # Replace history: summary placeholder + recent verbatim messages
    summary_placeholder = PT.UserMessage(
        "[Conversation Summary — $(length(old_msgs)) messages compressed]\n\n$(summary_text)"
    )

    lock(session.lock) do
        empty!(session.history)
        push!(session.history, summary_placeholder)
        append!(session.history, keep_msgs)
    end

    println("[$(agent.name)] compaction complete: new_history_length=$(length(session.history))")
    return true
end
