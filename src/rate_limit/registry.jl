###############################################################################
# rate_limit/registry.jl — global limiter registry and public API
###############################################################################

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
