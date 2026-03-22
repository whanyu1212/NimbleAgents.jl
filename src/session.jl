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
- `history::Vector{PT.AbstractMessage}`: Accumulated message history.
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
    history::Vector{PT.AbstractMessage}
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
        PT.AbstractMessage[],
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
        msg isa PT.SystemMessage && continue
        push!(session.history, msg)
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# Cost tracking — per-model pricing registry
# ──────────────────────────────────────────────────────────────────────────────

# Pricing is per 1M tokens (USD). Users can register custom pricing for any
# model. Built-in defaults cover popular models at list price as of March 2026.
# Prices sourced from official provider pricing pages.

const _model_pricing = Dict{String,@NamedTuple{input::Float64,output::Float64}}()
const _model_pricing_lock = ReentrantLock()

"""
    set_model_pricing!(model, input_per_million, output_per_million)

Register USD pricing for a model.

`input_per_million` and `output_per_million` are the cost per 1 million tokens.

# Example
```julia
set_model_pricing!("gpt-5.4-mini", 0.40, 1.60)
set_model_pricing!("claude-sonnet-4-6", 3.00, 15.00)
```
"""
function set_model_pricing!(model::String, input_pm::Real, output_pm::Real)
    lock(_model_pricing_lock) do
        _model_pricing[model] = (input=Float64(input_pm), output=Float64(output_pm))
    end
    nothing
end

"""
    get_model_pricing(model) -> Union{NamedTuple{(:input,:output)}, Nothing}

Look up pricing for a model. Returns `nothing` if no pricing is registered.
"""
function get_model_pricing(model::String)
    lock(_model_pricing_lock) do
        get(_model_pricing, model, nothing)
    end
end

"""
    remove_model_pricing!(model)

Remove a previously registered pricing entry.
"""
function remove_model_pricing!(model::String)
    lock(_model_pricing_lock) do
        delete!(_model_pricing, model)
    end
    nothing
end

# Compute cost in USD from token counts and model pricing.
function _compute_cost(model::String, input_tokens::Int, output_tokens::Int)::Float64
    pricing = get_model_pricing(model)
    isnothing(pricing) && return 0.0
    (input_tokens * pricing.input + output_tokens * pricing.output) / 1_000_000
end

# Register defaults for widely-used models (prices as of March 2026).
# Users can override any of these with set_model_pricing!.
function _register_default_pricing!()
    defaults = [
        # ── OpenAI ──────────────────────────────────────────────────────────
        # GPT-4o
        ("gpt-4o", 2.50, 10.00),
        ("gpt-4o-2024-08-06", 2.50, 10.00),
        ("gpt-4o-mini", 0.15, 0.60),
        # GPT-4.1
        ("gpt-4.1", 2.00, 8.00),
        ("gpt-4.1-mini", 0.40, 1.60),
        ("gpt-4.1-nano", 0.10, 0.40),
        # GPT-5.4 (estimated from 4.1 tier pricing — update when official)
        ("gpt-5.4-mini", 0.40, 1.60),
        ("gpt-5.4-nano", 0.10, 0.40),
        ("gpt-5.4-nano-2026-03-17", 0.10, 0.40),
        # o-series reasoning models
        ("o1", 15.00, 60.00),
        ("o1-mini", 1.10, 4.40),
        ("o1-pro", 150.00, 600.00),
        ("o3", 10.00, 40.00),
        ("o3-mini", 1.10, 4.40),
        ("o3-pro", 20.00, 80.00),
        ("o4-mini", 1.10, 4.40),
        # Legacy
        ("gpt-4-turbo", 10.00, 30.00),
        ("gpt-3.5-turbo", 0.50, 1.50),
        # ── Anthropic ───────────────────────────────────────────────────────
        # Claude 4.6 (latest)
        ("claude-opus-4-6", 5.00, 25.00),
        ("claude-sonnet-4-6", 3.00, 15.00),
        # Claude 4.5
        ("claude-opus-4-5-20251101", 5.00, 25.00),
        ("claude-opus-4-5", 5.00, 25.00),
        ("claude-sonnet-4-5-20250929", 3.00, 15.00),
        ("claude-sonnet-4-5", 3.00, 15.00),
        # Claude 4.1
        ("claude-opus-4-1-20250805", 15.00, 75.00),
        ("claude-opus-4-1", 15.00, 75.00),
        # Claude 4.0
        ("claude-sonnet-4-20250514", 3.00, 15.00),
        ("claude-sonnet-4-0", 3.00, 15.00),
        ("claude-opus-4-20250514", 15.00, 75.00),
        ("claude-opus-4-0", 15.00, 75.00),
        # Claude 3.5 / 3
        ("claude-haiku-4-5-20251001", 1.00, 5.00),
        ("claude-haiku-4-5", 1.00, 5.00),
        ("claude-3-5-sonnet-20241022", 3.00, 15.00),
        ("claude-3-haiku-20240307", 0.25, 1.25),
        # ── Google Gemini ───────────────────────────────────────────────────
        # Gemini 3.x (preview)
        ("gemini-3.1-pro-preview", 2.00, 12.00),
        ("gemini-3.1-flash-lite-preview", 0.25, 1.50),
        ("gemini-3-flash-preview", 0.50, 3.00),
        # Gemini 2.5
        ("gemini-2.5-pro", 1.25, 10.00),
        ("gemini-2.5-pro-preview-05-06", 1.25, 10.00),
        ("gemini-2.5-flash", 0.30, 2.50),
        ("gemini-2.5-flash-preview-05-20", 0.15, 0.60),
        ("gemini-2.5-flash-lite", 0.10, 0.40),
        # Gemini 2.0
        ("gemini-2.0-flash", 0.10, 0.40),
        ("gemini-2.0-flash-lite", 0.075, 0.30),
        # Gemini 1.5
        ("gemini-1.5-pro", 1.25, 5.00),
        ("gemini-1.5-flash", 0.075, 0.30),
    ]
    for (model, inp, out) in defaults
        set_model_pricing!(model, inp, out)
    end
end

_register_default_pricing!()

# Accumulate token usage from a PT response message into a TurnEvent.
# Uses PT's cache-adjusted cost when available (TokenUsage.cost > 0),
# otherwise falls back to our model pricing registry.
function _accumulate_usage!(turn::TurnEvent, msg)
    usage = msg.usage
    isnothing(usage) && return nothing
    in_tok = something(usage.input_tokens, 0)
    out_tok = something(usage.output_tokens, 0)
    turn.input_tokens += in_tok
    turn.output_tokens += out_tok

    # Cache token tracking
    if hasproperty(usage, :cache_read_tokens)
        turn.cache_read_tokens += something(usage.cache_read_tokens, 0)
    end
    if hasproperty(usage, :cache_write_tokens)
        turn.cache_write_tokens += something(usage.cache_write_tokens, 0)
    end

    # Prefer PT's cost (includes cache discounts) when available
    pt_cost = hasproperty(usage, :cost) ? something(usage.cost, 0.0) : 0.0
    turn.cost += pt_cost > 0.0 ? pt_cost : _compute_cost(turn.model, in_tok, out_tok)
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

    summary_msg = PT.aigenerate(
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
    summary_placeholder = PT.UserMessage(
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
