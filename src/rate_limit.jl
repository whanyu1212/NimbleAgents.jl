###############################################################################
# rate_limit.jl — Token-bucket rate limiter for LLM API calls
#
# Provides per-model request throttling to prevent 429 errors when running
# multiple agents concurrently (fan_out, spawn_subagents, web server).
#
# Usage:
#
#   # Set a global limit: max 10 requests per second for gpt-5.4-mini
#   set_rate_limit!("gpt-5.4-mini", 10)
#
#   # Or set a default for all models
#   set_rate_limit!(:default, 20)
#
#   # The agent loop calls acquire! before each LLM call — it blocks
#   # until a token is available.
#
#   # Remove a limit
#   remove_rate_limit!("gpt-5.4-mini")
#   remove_rate_limit!(:default)
###############################################################################

"""
    RateLimiter

Token-bucket rate limiter. Allows up to `rate` requests per second,
with a burst capacity equal to `rate`.
"""
mutable struct RateLimiter
    rate::Float64       # tokens per second
    tokens::Float64       # current available tokens
    last_time::Float64       # last refill timestamp (seconds since epoch)
    lock::ReentrantLock
end

function RateLimiter(rate::Real)
    RateLimiter(Float64(rate), Float64(rate), time(), ReentrantLock())
end

"""
    acquire!(limiter::RateLimiter)

Block until a token is available, then consume one. Returns immediately
if tokens are available.
"""
function acquire!(limiter::RateLimiter)
    while true
        lock(limiter.lock) do
            now = time()
            elapsed = now - limiter.last_time
            limiter.tokens = min(limiter.rate, limiter.tokens + elapsed * limiter.rate)
            limiter.last_time = now
        end

        taken = lock(limiter.lock) do
            if limiter.tokens >= 1.0
                limiter.tokens -= 1.0
                true
            else
                false
            end
        end
        taken && return nothing

        # Wait a short interval before retrying. Sleep time is proportional
        # to how long until the next token refills.
        wait_time = lock(limiter.lock) do
            (1.0 - limiter.tokens) / limiter.rate
        end
        sleep(min(wait_time, 0.1))
    end
end

# ── Global registry ──────────────────────────────────────────────────────────

const _rate_limiters = Dict{String,RateLimiter}()
const _rate_limiters_lock = ReentrantLock()

"""
    set_rate_limit!(model::String, requests_per_second::Real)
    set_rate_limit!(::Symbol, requests_per_second::Real)

Set a rate limit for a specific model (e.g. `"gpt-5.4-mini"`) or for all
models (`:default`). The limiter allows up to `requests_per_second` LLM
calls per second with short bursts up to that same number.

# Example
```julia
# Limit gpt-5.4-mini to 10 requests/second
set_rate_limit!("gpt-5.4-mini", 10)

# Limit all models to 20 requests/second (unless overridden per-model)
set_rate_limit!(:default, 20)
```
"""
function set_rate_limit!(model::String, rps::Real)
    rps > 0 || error("requests_per_second must be positive, got $(rps)")
    lock(_rate_limiters_lock) do
        _rate_limiters[model] = RateLimiter(rps)
    end
    nothing
end

function set_rate_limit!(key::Symbol, rps::Real)
    key === :default || error("Only :default is supported, got :$(key)")
    set_rate_limit!("__default__", rps)
end

"""
    remove_rate_limit!(model::String)
    remove_rate_limit!(::Symbol)

Remove a previously set rate limit.
"""
function remove_rate_limit!(model::String)
    lock(_rate_limiters_lock) do
        delete!(_rate_limiters, model)
    end
    nothing
end

function remove_rate_limit!(key::Symbol)
    key === :default || error("Only :default is supported, got :$(key)")
    remove_rate_limit!("__default__")
end

"""
    _acquire_rate_limit!(model::String)

Internal: called by the agent loop before each LLM call. If a rate limit
is set for this model (or a default limit exists), blocks until a token
is available. If no limit is set, returns immediately.
"""
function _acquire_rate_limit!(model::String)
    limiter = lock(_rate_limiters_lock) do
        get(_rate_limiters, model, get(_rate_limiters, "__default__", nothing))
    end
    isnothing(limiter) && return nothing
    acquire!(limiter)
end
