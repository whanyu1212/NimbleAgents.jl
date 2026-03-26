###############################################################################
# tracer/io.jl — trace persistence helpers
###############################################################################

"""
    save_trace(trace, path)

Serialise a `Trace` to a JSON file at `path`.

The JSON structure mirrors the `Trace` fields — suitable for offline analysis,
feeding into an evaluation script, or archiving agent runs.

# Arguments
- `trace::Trace`: Trace data to persist.
- `path::String`: Destination file path.

# Returns
- `String`: The same `path` that was written.
"""
function save_trace(trace::Trace, path::String)
    data = Dict{String,Any}(
        "total_input_tokens" => trace.total_input_tokens,
        "total_output_tokens" => trace.total_output_tokens,
        "total_cache_read_tokens" => trace.total_cache_read_tokens,
        "total_cache_write_tokens" => trace.total_cache_write_tokens,
        "total_tokens" => trace.total_tokens,
        "total_cost" => trace.total_cost,
        "total_llm_calls" => trace.total_llm_calls,
        "total_tool_calls" => trace.total_tool_calls,
        "duration" => trace.duration,
        "agents" => trace.agents,
        "turns" => map(trace.turns) do t
            Dict{String,Any}(
                "agent" => t.agent,
                "model" => t.model,
                "input" => t.input,
                "output" => isnothing(t.output) ? nothing : string(t.output),
                "llm_calls" => t.llm_calls,
                "input_tokens" => t.input_tokens,
                "output_tokens" => t.output_tokens,
                "cache_read_tokens" => t.cache_read_tokens,
                "cache_write_tokens" => t.cache_write_tokens,
                "cost" => t.cost,
                "elapsed" => t.elapsed,
                "timestamp" => t.timestamp,
                "tool_calls" => map(t.tool_calls) do te
                    Dict{String,Any}(
                        "name" => te.name,
                        "args" => Dict(string(k) => v for (k, v) in te.args),
                        "result" => isnothing(te.result) ? nothing : string(te.result),
                        "error" => te.error,
                        "timestamp" => te.timestamp,
                    )
                end,
            )
        end,
    )

    dir = dirname(path)
    isempty(dir) || mkpath(dir)
    write(path, JSON3.write(data))
    println("Trace saved to: $(path)")
    path
end

"""
    load_trace(path) -> Dict{String, Any}

Load a previously saved trace from a JSON file.
Returns the raw parsed Dict — useful for offline analysis or evaluation scripts.

# Arguments
- `path::String`: Path to a JSON file produced by `save_trace`.

# Returns
- `Dict{String,Any}`: Parsed trace payload.
"""
function load_trace(path::String)::Dict{String,Any}
    isfile(path) || error("Trace file not found: $(path)")
    Dict{String,Any}(JSON3.read(read(path, String), Dict{String,Any}))
end
