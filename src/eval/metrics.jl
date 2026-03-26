###############################################################################
# eval/metrics.jl — metric model, helpers, and built-in metrics
###############################################################################

"""
    NamedMetric(name, fn)

Wrapper for a metric closure (e.g. from a factory like `cost_budget`) that
carries a display name. Made callable: `(m::NamedMetric)(case, output, trace)`.
"""
struct NamedMetric
    name::String
    fn::Function
end

(m::NamedMetric)(case::EvalCase, output, trace) = m.fn(case, output, trace)

"""Extract a display name from a metric function or NamedMetric."""
_metric_name(f::Function) = string(nameof(f))
_metric_name(m::NamedMetric) = m.name

"""Levenshtein edit distance (single-row DP, no dependencies)."""
function _edit_distance(a::AbstractString, b::AbstractString)
    m, n = length(a), length(b)
    m == 0 && return n
    n == 0 && return m

    prev = collect(0:n)
    curr = Vector{Int}(undef, n + 1)

    for i in 1:m
        curr[1] = i
        for j in 1:n
            cost = a[i] == b[j] ? 0 : 1
            curr[j + 1] = min(
                prev[j + 1] + 1,   # deletion
                curr[j] + 1,       # insertion
                prev[j] + cost,    # substitution
            )
        end
        prev, curr = curr, prev
    end
    prev[n + 1]
end

"""
    exact_match(case, output, trace) -> Float64

Returns 1.0 if `string(output)` equals `case.expected` exactly, else 0.0.
Returns 1.0 if `case.expected` is `nothing` (no expectation).
"""
function exact_match(case::EvalCase, output, trace)
    isnothing(case.expected) && return 1.0
    string(output) == case.expected ? 1.0 : 0.0
end

"""
    fuzzy_match(case, output, trace) -> Float64

Returns 1.0 if `case.expected` is a case-insensitive substring of `output`.
Otherwise returns a normalised similarity score based on Levenshtein distance.
Returns 1.0 if `case.expected` is `nothing`.
"""
function fuzzy_match(case::EvalCase, output, trace)
    isnothing(case.expected) && return 1.0
    a = lowercase(string(output))
    b = lowercase(case.expected)
    occursin(b, a) && return 1.0
    max_len = max(length(a), length(b))
    max_len == 0 && return 1.0
    1.0 - _edit_distance(a, b) / max_len
end

"""
    tool_trajectory(case, output, trace) -> Float64

Returns 1.0 if the tool names called (in order) match `case.expected_tools` exactly.
Returns 1.0 if `case.expected_tools` is `nothing`.
"""
function tool_trajectory(case::EvalCase, output, trace)
    isnothing(case.expected_tools) && return 1.0
    isnothing(trace) && return 0.0
    actual = String[]
    for turn in trace.turns
        for te in turn.tool_calls
            push!(actual, te.name)
        end
    end
    actual == case.expected_tools ? 1.0 : 0.0
end

"""
    tool_coverage(case, output, trace) -> Float64

Returns the fraction of `case.expected_tools` that were actually called
(order-insensitive). Returns 1.0 if `case.expected_tools` is `nothing`.
"""
function tool_coverage(case::EvalCase, output, trace)
    isnothing(case.expected_tools) && return 1.0
    isempty(case.expected_tools) && return 1.0
    isnothing(trace) && return 0.0
    actual_set = Set{String}()
    for turn in trace.turns
        for te in turn.tool_calls
            push!(actual_set, te.name)
        end
    end
    matched = count(t -> t in actual_set, case.expected_tools)
    matched / length(case.expected_tools)
end

"""
    cost_budget(max_cost) -> NamedMetric

Factory: returns a metric that scores 1.0 if `trace.total_cost <= max_cost`, else 0.0.
"""
function cost_budget(max_cost::Real)
    NamedMetric("cost_budget($(max_cost))", function (case, output, trace)
        isnothing(trace) && return 0.0
        trace.total_cost <= max_cost ? 1.0 : 0.0
    end)
end

"""
    latency_budget(max_seconds) -> NamedMetric

Factory: returns a metric that scores 1.0 if `trace.duration <= max_seconds`, else 0.0.
"""
function latency_budget(max_seconds::Real)
    NamedMetric(
        "latency_budget($(max_seconds))", function (case, output, trace)
            isnothing(trace) && return 0.0
            trace.duration <= max_seconds ? 1.0 : 0.0
        end
    )
end
