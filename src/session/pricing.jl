###############################################################################
# session/pricing.jl — turn-level token/cost accounting
###############################################################################

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
