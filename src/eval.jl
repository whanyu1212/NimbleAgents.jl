###############################################################################
# eval.jl — Eval harness for testing agent behaviour against known cases
#
# Usage:
#
#   cases = [
#       EvalCase(input="What is 2+2?", expected="4",
#                expected_tools=["add"], tags=["math"]),
#   ]
#   report = run_eval(agent, cases; metrics=[exact_match, tool_trajectory])
#   print_eval(report)
#   save_eval(report, "eval_results.json")
###############################################################################

import JSON3

# ── Structs ──────────────────────────────────────────────────────────────────

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
    input          ::String
    expected       ::Union{String, Nothing}
    expected_tools ::Union{Vector{String}, Nothing}
    reference      ::Union{Dict{String, Any}, Nothing}
    tags           ::Vector{String}
end

function EvalCase(;
    input          ::String,
    expected       ::Union{String, Nothing}           = nothing,
    expected_tools ::Union{Vector{String}, Nothing}   = nothing,
    reference      ::Union{Dict{String, Any}, Nothing} = nothing,
    tags           ::Vector{String}                    = String[],
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
    case    ::EvalCase
    output  ::Any
    trace   ::Union{Trace, Nothing}
    scores  ::Dict{String, Float64}
    passed  ::Bool
    error   ::Union{String, Nothing}
    elapsed ::Float64
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
    results        ::Vector{EvalResult}
    pass_rate      ::Float64
    mean_scores    ::Dict{String, Float64}
    total_cost     ::Float64
    total_duration ::Float64
    timestamp      ::Float64
end

function EvalReport(results::Vector{EvalResult})
    n = length(results)
    if n == 0
        return EvalReport(results, 0.0, Dict{String, Float64}(),
                          0.0, 0.0, time())
    end

    pass_rate = count(r -> r.passed, results) / n

    # Collect all metric names
    all_keys = Set{String}()
    for r in results
        union!(all_keys, keys(r.scores))
    end
    mean_scores = Dict{String, Float64}()
    for k in all_keys
        vals = [get(r.scores, k, 0.0) for r in results]
        mean_scores[k] = sum(vals) / n
    end

    total_cost = sum(r -> isnothing(r.trace) ? 0.0 : r.trace.total_cost, results)
    total_duration = sum(r -> r.elapsed, results)

    EvalReport(results, pass_rate, mean_scores, total_cost, total_duration, time())
end

# ── NamedMetric ──────────────────────────────────────────────────────────────

"""
    NamedMetric(name, fn)

Wrapper for a metric closure (e.g. from a factory like `cost_budget`) that
carries a display name. Made callable: `(m::NamedMetric)(case, output, trace)`.
"""
struct NamedMetric
    name ::String
    fn   ::Function
end

(m::NamedMetric)(case::EvalCase, output, trace) = m.fn(case, output, trace)

# ── Internal helpers ─────────────────────────────────────────────────────────

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

# ── Built-in metrics ────────────────────────────────────────────────────────

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
    NamedMetric("cost_budget($(max_cost))", function(case, output, trace)
        isnothing(trace) && return 0.0
        trace.total_cost <= max_cost ? 1.0 : 0.0
    end)
end

"""
    latency_budget(max_seconds) -> NamedMetric

Factory: returns a metric that scores 1.0 if `trace.duration <= max_seconds`, else 0.0.
"""
function latency_budget(max_seconds::Real)
    NamedMetric("latency_budget($(max_seconds))", function(case, output, trace)
        isnothing(trace) && return 0.0
        trace.duration <= max_seconds ? 1.0 : 0.0
    end)
end

# ── Runner ───────────────────────────────────────────────────────────────────

"""
    run_eval(agent, cases; metrics, verbose, pass_threshold) -> EvalReport

Run an agent against a vector of `EvalCase`s, score each with the given metrics,
and return an `EvalReport`.

# Arguments
- `agent::Agent`: The agent to evaluate.
- `cases::Vector{EvalCase}`: Test cases.
- `metrics`: Vector of metric functions `(EvalCase, output, Trace) -> Float64`.
  Default: `[exact_match, tool_trajectory]`.
- `verbose::Bool`: Whether to pass `verbose=true` to `run!`. Default: `false`.
- `pass_threshold::Float64`: Minimum score for each metric to count as passed.
  Default: `1.0`.
"""
function run_eval(agent::Agent, cases::Vector{EvalCase};
                  metrics = [exact_match, tool_trajectory],
                  verbose::Bool = false,
                  pass_threshold::Float64 = 1.0)
    results = EvalResult[]

    for case in cases
        session = Session(app_name="eval")
        t0 = time()
        output = nothing
        trace = nothing
        err = nothing
        scores = Dict{String, Float64}()

        try
            output = run!(agent, case.input; session=session, verbose=verbose)
            trace = Trace(session)
        catch e
            err = string(e)
            trace = isempty(session.events) ? nothing : Trace(session)
        end

        elapsed = time() - t0

        if isnothing(err)
            for metric in metrics
                name = _metric_name(metric)
                score = clamp(Float64(metric(case, output, trace)), 0.0, 1.0)
                scores[name] = score
            end
        else
            for metric in metrics
                scores[_metric_name(metric)] = 0.0
            end
        end

        passed = all(v >= pass_threshold for v in values(scores))
        # Empty scores dict → vacuously true, which is correct (no metrics = pass)

        push!(results, EvalResult(case, output, trace, scores, passed, err, elapsed))
    end

    EvalReport(results)
end

# ── Display ──────────────────────────────────────────────────────────────────

"""
    print_eval(report; io=stdout)

Print a human-readable summary of an `EvalReport`.
"""
function print_eval(report::EvalReport; io::IO=stdout)
    bar = "━" ^ 50
    println(io, bar)
    println(io, "  Eval Report")
    println(io, "  Cases      : $(length(report.results))")
    if !isempty(report.results)
        println(io, "  Pass rate  : $(round(report.pass_rate * 100; digits=1))%")
    end
    if report.total_cost > 0
        println(io, "  Total cost : \$$(round(report.total_cost; digits=4))")
    end
    println(io, "  Duration   : $(round(report.total_duration; digits=2))s")

    if !isempty(report.mean_scores)
        println(io)
        println(io, "  Mean scores:")
        for (k, v) in sort(collect(report.mean_scores); by=first)
            println(io, "    $(k) : $(round(v; digits=3))")
        end
    end

    for (i, r) in enumerate(report.results)
        status = if !isnothing(r.error)
            "ERR"
        elseif r.passed
            "PASS"
        else
            "FAIL"
        end

        println(io)
        input_short = length(r.case.input) > 60 ? r.case.input[1:60] * "…" : r.case.input
        println(io, "  Case $(i) [$(status)] — $(input_short)")

        if !isnothing(r.error)
            err_short = length(r.error) > 80 ? r.error[1:80] * "…" : r.error
            println(io, "    error  : $(err_short)")
        else
            out_str = string(something(r.output, "(nothing)"))
            out_short = length(out_str) > 80 ? out_str[1:80] * "…" : out_str
            println(io, "    output : $(out_short)")
        end

        for (k, v) in sort(collect(r.scores); by=first)
            println(io, "    $(k) : $(round(v; digits=3))")
        end
    end

    println(io)
    println(io, bar)
end

# ── Persistence ──────────────────────────────────────────────────────────────

"""
    save_eval(report, path)

Serialise an `EvalReport` to a JSON file.
"""
function save_eval(report::EvalReport, path::String)
    data = Dict{String, Any}(
        "pass_rate"      => report.pass_rate,
        "mean_scores"    => report.mean_scores,
        "total_cost"     => report.total_cost,
        "total_duration" => report.total_duration,
        "timestamp"      => report.timestamp,
        "results"        => map(report.results) do r
            trace_summary = if isnothing(r.trace)
                nothing
            else
                Dict{String, Any}(
                    "total_cost"   => r.trace.total_cost,
                    "duration"     => r.trace.duration,
                    "total_tokens" => r.trace.total_tokens,
                    "agents"       => r.trace.agents,
                )
            end
            Dict{String, Any}(
                "input"          => r.case.input,
                "expected"       => r.case.expected,
                "expected_tools" => r.case.expected_tools,
                "tags"           => r.case.tags,
                "output"         => isnothing(r.output) ? nothing : string(r.output),
                "scores"         => r.scores,
                "passed"         => r.passed,
                "error"          => r.error,
                "elapsed"        => r.elapsed,
                "trace"          => trace_summary,
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
function load_eval(path::String)::Dict{String, Any}
    isfile(path) || error("Eval file not found: $(path)")
    Dict{String, Any}(JSON3.read(read(path, String), Dict{String, Any}))
end
