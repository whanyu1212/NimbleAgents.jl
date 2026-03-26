###############################################################################
# eval/persistence.jl — save/load eval report snapshots
###############################################################################

"""
    save_eval(report, path)

Serialise an `EvalReport` to a JSON file.
"""
function save_eval(report::EvalReport, path::String)
    data = Dict{String,Any}(
        "pass_rate" => report.pass_rate,
        "mean_scores" => report.mean_scores,
        "total_cost" => report.total_cost,
        "total_duration" => report.total_duration,
        "timestamp" => report.timestamp,
        "results" => map(report.results) do r
            trace_summary = if isnothing(r.trace)
                nothing
            else
                Dict{String,Any}(
                    "total_cost" => r.trace.total_cost,
                    "duration" => r.trace.duration,
                    "total_tokens" => r.trace.total_tokens,
                    "agents" => r.trace.agents,
                )
            end
            Dict{String,Any}(
                "input" => r.case.input,
                "expected" => r.case.expected,
                "expected_tools" => r.case.expected_tools,
                "tags" => r.case.tags,
                "output" => isnothing(r.output) ? nothing : string(r.output),
                "scores" => r.scores,
                "passed" => r.passed,
                "error" => r.error,
                "elapsed" => r.elapsed,
                "trace" => trace_summary,
            )
        end,
    )

    dir = dirname(path)
    isempty(dir) || mkpath(dir)
    write(path, JSON3.write(data))
    println("Eval report saved to: $(path)")
    path
end

"""
    load_eval(path) -> Dict{String, Any}

Load a previously saved eval report from a JSON file.
"""
function load_eval(path::String)::Dict{String,Any}
    isfile(path) || error("Eval file not found: $(path)")
    Dict{String,Any}(JSON3.read(read(path, String), Dict{String,Any}))
end
