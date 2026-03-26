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

include("rate_limit/types.jl")
include("rate_limit/registry.jl")
include("rate_limit/acquire.jl")
