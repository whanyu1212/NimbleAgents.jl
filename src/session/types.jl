###############################################################################
# session/types.jl — session/event structures and core helpers
###############################################################################

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
    name::String
    args::Dict{Symbol,Any}
    result::Any
    error::Union{String,Nothing}
    timestamp::Float64
end

ToolEvent(name, args, result) = ToolEvent(name, args, result, nothing, time())
ToolEvent(name, args; error::String) = ToolEvent(name, args, nothing, error, time())

# ──────────────────────────────────────────────────────────────────────────────
# TurnEvent — record of one complete run! call
# ──────────────────────────────────────────────────────────────────────────────

"""
    TurnEvent

A record of one complete `run!` invocation — one "turn" in the conversation.

# Fields
- `agent::String`: Name of the agent that handled this turn.
- `model::String`: LLM model identifier used for this turn.
- `input::String`: The user message for this turn.
- `output::Any`: The final response returned by `run!`.
- `tool_calls::Vector{ToolEvent}`: All tool calls made during this turn, in order.
- `llm_calls::Int`: Number of LLM requests made.
- `input_tokens::Int`: Total input tokens used across all LLM calls this turn.
- `output_tokens::Int`: Total output tokens used across all LLM calls this turn.
- `cache_read_tokens::Int`: Tokens read from prompt cache (discounted cost).
- `cache_write_tokens::Int`: Tokens written to prompt cache (premium cost on Anthropic).
- `cost::Float64`: Estimated USD cost for this turn (cache-adjusted when available).
- `elapsed::Float64`: Wall-clock time in seconds for the whole turn.
- `timestamp::Float64`: `time()` when `run!` was called.
"""
mutable struct TurnEvent
    agent::String
    model::String
    input::String
    output::Any
    tool_calls::Vector{ToolEvent}
    llm_calls::Int
    input_tokens::Int
    output_tokens::Int
    cache_read_tokens::Int
    cache_write_tokens::Int
    cost::Float64
    elapsed::Float64
    timestamp::Float64
end

function TurnEvent(agent::String, model::String, input::String)
    TurnEvent(agent, model, input, nothing, ToolEvent[], 0, 0, 0, 0, 0, 0.0, 0.0, time())
end

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
- `history::Vector{AbstractMessage}`: Accumulated message history.
- `state::Dict{String,Any}`: Cross-turn key-value store.
- `events::Vector{TurnEvent}`: Ordered log of every completed turn.
- `created_at::Float64`: `time()` when the session was created.
- `updated_at::Float64`: `time()` when the session was last saved (used for TTL expiry).
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
    id::String
    app_name::String
    user_id::String
    history::Vector{AbstractMessage}
    state::Dict{String,Any}
    events::Vector{TurnEvent}
    artifacts::Vector{Any}   # Vector{Artifact} — typed after artifacts.jl loads
    created_at::Float64
    updated_at::Float64
    lock::ReentrantLock
end

function Session(;
    id::String=string(Base.UUID(rand(UInt128))),
    app_name::String="NimbleAgents",
    user_id::String="default",
)
    now = time()
    Session(
        id,
        app_name,
        user_id,
        AbstractMessage[],
        Dict{String,Any}(),
        TurnEvent[],
        Any[],
        now,
        now,
        ReentrantLock(),
    )
end

Base.length(s::Session) = length(s.history)
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
        msg isa SystemMessage && continue
        push!(session.history, msg)
    end
end
