###############################################################################
# agent/types/retry.jl — retry policy and backoff helpers
###############################################################################

"""
    RetryConfig(; max_retries, initial_delay, max_delay, multiplier, jitter,
                  retry_on_status, max_parse_retries)

Exponential-backoff retry policy for LLM API calls made inside `run!`.

# Fields
- `max_retries::Int`: Maximum number of retry attempts after the first failure (default: `3`).
- `initial_delay::Float64`: Seconds to wait before the first retry (default: `0.5`).
  Consensus across Anthropic SDK and LangGraph; fast enough for transient errors.
- `max_delay::Float64`: Maximum seconds to wait between retries (default: `60.0`).
  Chosen to match the standard 1-minute rate-limit reset window used by both
  OpenAI and Anthropic — capping here means later retries will wait long enough
  to clear a sustained 429 burst without hanging indefinitely.
- `multiplier::Float64`: Exponential growth factor (default: `2.0`). Universal
  across all reference SDKs (OpenAI, Anthropic, ADK, LangGraph).
- `jitter::Bool`: When `true`, multiplies each delay by a random factor in
  `[0.75, 1.0]` (Anthropic-style multiplicative jitter). Prevents thundering-herd
  when many parallel agents retry simultaneously (default: `true`).
- `retry_on_status::Vector{Int}`: HTTP status codes that warrant a retry.
  - `408` request timeout, `429` rate limit — always transient
  - `500/502/503/504` server-side errors — usually transient
  - `529` Anthropic-specific overload status
  4xx errors outside this list (401, 400, 403, 404) are permanent failures and
  are never retried regardless of this setting.
- `max_parse_retries::Int`: Maximum number of re-prompts when `output_type` parsing
  fails (default: `2`). On each failure the parse error is fed back to the LLM
  as a user message so it can correct its response. Set to `0` to disable.

# Example
```julia
agent = Agent(
    name   = "Bot",
    instructions = "...",
    retry  = RetryConfig(max_retries=5, max_delay=120.0),
)
```
"""
Base.@kwdef struct RetryConfig
    max_retries::Int = 3
    initial_delay::Float64 = 0.5
    # 60s matches the standard 1-minute rate-limit reset window for OpenAI and
    # Anthropic. Retries that reach this cap will wait long enough for the window
    # to clear before trying again, rather than giving up too early (32s) or
    # hanging excessively (ADK's 120s / LangGraph's 128s).
    max_delay::Float64 = 60.0
    multiplier::Float64 = 2.0
    jitter::Bool = true
    retry_on_status::Vector{Int} = [408, 429, 500, 502, 503, 504, 529]
    max_parse_retries::Int = 2
end

# Compute the wait time for attempt n (1-indexed), with optional jitter.
function _backoff_delay(cfg::RetryConfig, attempt::Int)::Float64
    delay = min(cfg.initial_delay * cfg.multiplier ^ (attempt - 1), cfg.max_delay)
    cfg.jitter ? delay * (0.75 + 0.25 * rand()) : delay
end

# Return true if the exception looks like a retryable HTTP error.
# Match "HTTP <code>" or "status <code>" patterns to avoid false positives
# from messages that happen to contain a status code number in other contexts.
function _retryable(cfg::RetryConfig, err)::Bool
    msg = sprint(showerror, err)
    any(
        occursin(Regex("(?:HTTP|status)\\s*" * string(code)), msg) for
        code in cfg.retry_on_status
    )
end

# Retry wrapper: calls f(), retrying on retryable errors up to cfg.max_retries times.
function _with_retry(f::Function, cfg::RetryConfig, agent_name::String)
    last_err = nothing
    for attempt in 1:(cfg.max_retries + 1)
        try
            return f()
        catch err
            last_err = err
            attempt > cfg.max_retries && break
            _retryable(cfg, err) || rethrow(err)
            delay = _backoff_delay(cfg, attempt)
            println(
                stderr,
                "[$(agent_name)] LLM call failed (attempt $(attempt)/$(cfg.max_retries + 1)), retrying in $(round(delay; digits=1))s: ",
                sprint(showerror, err),
            )
            sleep(delay)
        end
    end
    println(stderr, "[$(agent_name)] all $(cfg.max_retries) retries exhausted")
    rethrow(last_err)
end
