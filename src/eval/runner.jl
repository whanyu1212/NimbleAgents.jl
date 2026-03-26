###############################################################################
# eval/runner.jl — eval execution loop
###############################################################################

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
function run_eval(
    agent::Agent,
    cases::Vector{EvalCase};
    metrics=[exact_match, tool_trajectory],
    verbose::Bool=false,
    pass_threshold::Float64=1.0,
)
    results = EvalResult[]

    for case in cases
        session = Session(; app_name="eval")
        t0 = time()
        output = nothing
        trace = nothing
        err = nothing
        scores = Dict{String,Float64}()

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
