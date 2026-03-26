###############################################################################
# rate_limit/types.jl — token bucket core type and acquire primitive
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
