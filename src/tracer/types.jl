###############################################################################
# tracer/types.jl — Trace type and high-level semantics
###############################################################################

"""
    Trace(session)
    Trace(turns::Vector{TurnEvent})

A lightweight view over a session's event log.

Aggregates token usage, cost, elapsed time, and tool call statistics across all turns.
No new data is collected — everything comes from `TurnEvent` / `ToolEvent`
already recorded by `run!`.

# Fields
- `turns::Vector{TurnEvent}`: All turns in order.
- `total_input_tokens::Int`: Sum of input tokens across all turns.
- `total_output_tokens::Int`: Sum of output tokens across all turns.
- `total_cache_read_tokens::Int`: Sum of tokens read from prompt cache.
- `total_cache_write_tokens::Int`: Sum of tokens written to prompt cache.
- `total_tokens::Int`: `total_input_tokens + total_output_tokens`.
- `total_cost::Float64`: Estimated total USD cost across all turns (cache-adjusted).
- `total_llm_calls::Int`: Total number of LLM requests made.
- `total_tool_calls::Int`: Total number of tool calls made.
- `duration::Float64`: Wall-clock seconds from first turn start to last turn end.
- `agents::Vector{String}`: Unique agent names that handled turns (in order of first appearance).

# Example
```julia
session = Session(app_name="MyApp", user_id="alice")
run!(agent, "What is 2 + 2?"; session=session)

trace = Trace(session)
println("Cost: \$", round(trace.total_cost; digits=4))
print_trace(trace)
save_trace(trace, "trace.json")
```
"""
struct Trace
    turns::Vector{TurnEvent}
    total_input_tokens::Int
    total_output_tokens::Int
    total_cache_read_tokens::Int
    total_cache_write_tokens::Int
    total_tokens::Int
    total_cost::Float64
    total_llm_calls::Int
    total_tool_calls::Int
    duration::Float64
    agents::Vector{String}
end
