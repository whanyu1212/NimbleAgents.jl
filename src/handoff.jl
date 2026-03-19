###############################################################################
# handoff.jl — Multi-agent primitives: agent_as_tool and handoff
###############################################################################

# ──────────────────────────────────────────────────────────────────────────────
# Handoff
# ──────────────────────────────────────────────────────────────────────────────

"""
    Handoff

A signal returned by an agent indicating that control should transfer to another
agent. Use `handoff_tool(agent)` to create a `Tool` that an agent can call to
trigger the transfer.

# Fields
- `target::Agent`: The agent to hand off to.
- `message::String`: The message to pass to the target agent (defaults to the
  current user input if empty).

The orchestrator loop in `run_pipeline!` detects `Handoff` results and
re-runs with the new agent automatically.
"""
struct Handoff
    target ::Agent
    message::String
end

"""
    handoff_tool(target; name, description) -> Tool

Create a `Tool` that, when called by an agent, signals a handoff to `target`.
The LLM passes a `message` argument containing what to forward to the next agent.

# Example
```julia
billing_agent = Agent(name="Billing", instructions="Handle billing questions.", ...)
support_agent = Agent(
    name         = "Support",
    instructions = "Triage customer requests.",
    tools        = [handoff_tool(billing_agent)],
)
```
"""
function handoff_tool(
    target     ::Agent;
    name       ::String = "handoff_to_$(target.name)",
    description::String = "Transfer the conversation to the $(target.name) agent.",
)
    params = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "message" => Dict{String,Any}(
                "type"        => "string",
                "description" => "The message or context to pass to the $(target.name) agent.",
            ),
        ),
        "required" => ["message"],
    )

    Tool(;
        name        = name,
        description = description,
        parameters  = params,
        callable    = (message::String) -> Handoff(target, message),
    )
end

# ──────────────────────────────────────────────────────────────────────────────
# agent_as_tool
# ──────────────────────────────────────────────────────────────────────────────

"""
    agent_as_tool(agent; name, description, session) -> Tool

Wrap `agent` as a `Tool` that a parent (orchestrator) agent can call.  The
subagent runs a full `run!` loop for each call and its result is returned as a
string back to the orchestrator.

The shared `session` is threaded through so the subagent's turns appear in the
same event log.

# Example
```julia
math_agent = Agent(name="Math", instructions="Do arithmetic.", tools=[add_tool])

orchestrator = Agent(
    name         = "Orchestrator",
    instructions = "Route requests to specialist agents.",
    tools        = [agent_as_tool(math_agent)],
)

run!(orchestrator, "What is 3 + 4?")
```
"""
function agent_as_tool(
    agent      ::Agent;
    name       ::String = agent.name,
    description::String = "Call the $(agent.name) agent with a task and get its response.",
    session    ::Union{Session, Nothing} = nothing,
    verbose    ::Bool = false,
)
    params = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "task" => Dict{String,Any}(
                "type"        => "string",
                "description" => "The task or question to send to the $(agent.name) agent.",
            ),
        ),
        "required" => ["task"],
    )

    Tool(;
        name        = name,
        description = description,
        parameters  = params,
        callable    = (task::String) -> begin
            result = run!(agent, task; session=session, verbose=verbose)
            string(result)
        end,
    )
end

# ──────────────────────────────────────────────────────────────────────────────
# run_pipeline!  — orchestrator loop with handoff support
# ──────────────────────────────────────────────────────────────────────────────

"""
    run_pipeline!(agent, input; session, verbose, max_handoffs) -> Any

Like `run!` but with automatic handoff support.  When a tool returns a
`Handoff`, the pipeline transparently re-runs with the target agent and the
forwarded message.  The loop stops when the active agent returns a plain result
(not a `Handoff`) or `max_handoffs` is reached.

# Arguments
- `agent::Agent`: The starting agent.
- `input::String`: The initial user message.
- `session`: Optional shared `Session` across all agents in the pipeline.
- `verbose::Bool`: Print handoff transitions (default `true`).
- `max_handoffs::Int`: Safety cap on the number of handoffs (default `10`).

# Example
```julia
result = run_pipeline!(triage_agent, "I need help with my bill";
                       session=session)
```
"""
function run_pipeline!(
    agent        ::Agent,
    input        ::String;
    session      ::Union{Session, Nothing} = nothing,
    verbose      ::Bool = true,
    max_handoffs ::Int  = 10,
)
    current_agent   = agent
    current_input   = input
    handoff_count   = 0

    while true
        result = run!(current_agent, current_input;
                      session = session,
                      verbose = verbose)

        # Not a handoff — we're done
        result isa Handoff || return result

        handoff_count += 1
        if handoff_count > max_handoffs
            println(stderr, "[run_pipeline!] reached max_handoffs ($max_handoffs); stopping.")
            return result.message
        end

        verbose && println("[run_pipeline!] handoff: $(current_agent.name) → $(result.target.name)")

        current_agent = result.target
        current_input = isempty(result.message) ? current_input : result.message
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# fan_out — same agent, many inputs, results merged
# ──────────────────────────────────────────────────────────────────────────────

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
    agent   ::Agent,
    inputs  ::Vector{String};
    reducer          = nothing,
    parallel::Bool   = false,
    session ::Union{Session, Nothing} = nothing,
    verbose ::Bool   = false,
)
    isempty(inputs) && return isnothing(reducer) ? Any[] : error("fan_out: cannot reduce empty inputs")

    results = if parallel
        tasks = [Threads.@spawn run!(agent, inp; session=session, verbose=verbose)
                 for inp in inputs]
        Any[fetch(t) for t in tasks]
    else
        Any[run!(agent, inp; session=session, verbose=verbose) for inp in inputs]
    end

    isnothing(reducer) ? results : reduce(reducer, results)
end

# ──────────────────────────────────────────────────────────────────────────────
# spawn_subagents — different agents, different tasks, imperative pipeline
# ──────────────────────────────────────────────────────────────────────────────

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
    pairs   ::Vector{<:Tuple{Agent, String}};
    parallel::Bool = false,
    session ::Union{Session, Nothing} = nothing,
    verbose ::Bool = false,
)
    isempty(pairs) && return Any[]

    if parallel
        tasks = [Threads.@spawn run!(ag, inp; session=session, verbose=verbose)
                 for (ag, inp) in pairs]
        return Any[fetch(t) for t in tasks]
    else
        return Any[run!(ag, inp; session=session, verbose=verbose) for (ag, inp) in pairs]
    end
end
