###############################################################################
# handoff/parallel.jl — fan-out and multi-agent parallel execution helpers
###############################################################################

"""
    fan_out(agent, inputs; reducer, parallel, session, verbose) -> Any

Run `agent` against each element of `inputs`, then combine the results.

- `parallel = false` (default): runs each input serially in order.
- `parallel = true`: spawns each run on the Julia thread pool (`Threads.@spawn`);
  result order matches `inputs` order regardless.
- `reducer`: an optional two-argument function `(accumulator, result) -> accumulator`
  applied via `reduce`. Defaults to `nothing`, which returns `Vector{Any}`.
- Each run shares the same `session` if provided; concurrent writes are protected
  by `session.lock`.

# Example — serial, default reducer
```julia
summaries = fan_out(summarizer, ["chunk 1", "chunk 2", "chunk 3"])
# => Vector{Any} of three responses
```

# Example — parallel with a string-join reducer
```julia
report = fan_out(research_agent, topics;
                 parallel = true,
                 reducer  = (acc, x) -> acc * "\\n\\n" * x)
```
"""
function fan_out(
    agent::Agent,
    inputs::Vector{String};
    reducer=nothing,
    parallel::Bool=false,
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=false,
)
    isempty(inputs) &&
        return isnothing(reducer) ? Any[] : error("fan_out: cannot reduce empty inputs")

    results = if parallel
        tasks = [
            Threads.@spawn run!(agent, inp; session=session, verbose=verbose) for inp in inputs
        ]
        Any[fetch(t) for t in tasks]
    else
        Any[run!(agent, inp; session=session, verbose=verbose) for inp in inputs]
    end

    isnothing(reducer) ? results : reduce(reducer, results)
end

"""
    spawn_subagents(pairs; parallel, session, verbose) -> Vector{Any}

Run a list of `(agent, input)` pairs and return their results in the same order.

- `parallel = false` (default): executes each pair serially.
- `parallel = true`: spawns each pair concurrently on the Julia thread pool;
  result order is preserved.
- Each run shares the same `session` if provided; concurrent writes are protected
  by `session.lock`.

# Example — serial
```julia
results = spawn_subagents([
    (researcher_agent, "Find facts about X"),
    (analyst_agent,    "Analyse the market for X"),
    (writer_agent,     "Draft an intro for X"),
])
draft = run!(editor_agent, join(results, "\\n\\n"))
```

# Example — parallel
```julia
results = spawn_subagents([
    (researcher_agent, "Topic A"),
    (researcher_agent, "Topic B"),
]; parallel = true, session = session)
```
"""
function spawn_subagents(
    pairs::Vector{<:Tuple{Agent,String}};
    parallel::Bool=false,
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=false,
)
    isempty(pairs) && return Any[]

    if parallel
        tasks = [
            Threads.@spawn run!(ag, inp; session=session, verbose=verbose) for (ag, inp) in pairs
        ]
        return Any[fetch(t) for t in tasks]
    else
        return Any[run!(ag, inp; session=session, verbose=verbose) for (ag, inp) in pairs]
    end
end
