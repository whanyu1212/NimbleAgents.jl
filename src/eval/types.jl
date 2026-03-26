###############################################################################
# eval/types.jl — eval case/result/report data models
###############################################################################

"""
    EvalCase(; input, expected, expected_tools, reference, tags)

A single evaluation test case.

# Fields
- `input::String`: User message to send to the agent.
- `expected::Union{String, Nothing}`: Expected answer text (for text-matching metrics).
- `expected_tools::Union{Vector{String}, Nothing}`: Expected tool call names in order.
- `reference::Union{Dict{String,Any}, Nothing}`: Arbitrary ground-truth metadata.
- `tags::Vector{String}`: Tags for filtering/grouping results.
"""
struct EvalCase
    input::String
    expected::Union{String,Nothing}
    expected_tools::Union{Vector{String},Nothing}
    reference::Union{Dict{String,Any},Nothing}
    tags::Vector{String}
end

function EvalCase(;
    input::String,
    expected::Union{String,Nothing}=nothing,
    expected_tools::Union{Vector{String},Nothing}=nothing,
    reference::Union{Dict{String,Any},Nothing}=nothing,
    tags::Vector{String}=String[],
)
    EvalCase(input, expected, expected_tools, reference, tags)
end

"""
    EvalResult

Result for a single eval case.

# Fields
- `case::EvalCase`: The original test case.
- `output::Any`: Actual agent response.
- `trace::Union{Trace, Nothing}`: Full trace from `run!`.
- `scores::Dict{String, Float64}`: Metric name => score (0.0–1.0).
- `passed::Bool`: Whether all scores met the pass threshold.
- `error::Union{String, Nothing}`: Error message if `run!` threw.
- `elapsed::Float64`: Wall-clock time for this case.
"""
struct EvalResult
    case::EvalCase
    output::Any
    trace::Union{Trace,Nothing}
    scores::Dict{String,Float64}
    passed::Bool
    error::Union{String,Nothing}
    elapsed::Float64
end

"""
    EvalReport(results)

Aggregate report over all eval results. Computes pass rate, mean scores,
total cost, and total duration from the individual results.

# Fields
- `results::Vector{EvalResult}`: All individual results.
- `pass_rate::Float64`: Fraction of cases that passed.
- `mean_scores::Dict{String, Float64}`: Mean score per metric across all cases.
- `total_cost::Float64`: Sum of trace costs.
- `total_duration::Float64`: Sum of elapsed times.
- `timestamp::Float64`: When the report was created.
"""
struct EvalReport
    results::Vector{EvalResult}
    pass_rate::Float64
    mean_scores::Dict{String,Float64}
    total_cost::Float64
    total_duration::Float64
    timestamp::Float64
end

function EvalReport(results::Vector{EvalResult})
    n = length(results)
    if n == 0
        return EvalReport(results, 0.0, Dict{String,Float64}(), 0.0, 0.0, time())
    end

    pass_rate = count(r -> r.passed, results) / n

    # Collect all metric names
    all_keys = Set{String}()
    for r in results
        union!(all_keys, keys(r.scores))
    end
    mean_scores = Dict{String,Float64}()
    for k in all_keys
        vals = [get(r.scores, k, 0.0) for r in results]
        mean_scores[k] = sum(vals) / n
    end

    total_cost = sum(r -> isnothing(r.trace) ? 0.0 : r.trace.total_cost, results)
    total_duration = sum(r -> r.elapsed, results)

    EvalReport(results, pass_rate, mean_scores, total_cost, total_duration, time())
end
