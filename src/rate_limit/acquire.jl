###############################################################################
# rate_limit/acquire.jl — internal model-level acquire hook
###############################################################################

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
