###############################################################################
# handoff.jl — Multi-agent primitives: agent_as_tool, handoff, loop_pipeline!
###############################################################################

import PromptingTools as PT

# ──────────────────────────────────────────────────────────────────────────────
# HandoffFilter — history transformation on handoff
# ──────────────────────────────────────────────────────────────────────────────

"""
    HandoffFilter

Controls how conversation history is transformed when handing off to the next
agent. Pass a `HandoffFilter` to `handoff_tool` or `run_pipeline!` to filter
the session history before the receiving agent sees it.

# Built-in filters (symbols)
- `:all`          — pass full history unchanged (default)
- `:none`         — clear history; receiving agent starts fresh
- `:strip_tools`  — remove all tool-call and tool-result messages
- `:last_n`       — keep only the last N messages (use `HandoffFilter(:last_n, 5)`)

# Custom filter (function)
Pass a function `(history::Vector{PT.AbstractMessage}) -> Vector{PT.AbstractMessage}`
for full control over what the receiving agent sees.

# Examples
```julia
# Strip tool messages on handoff
handoff_tool(billing; history_filter = HandoffFilter(:strip_tools))

# Keep only last 3 messages
handoff_tool(billing; history_filter = HandoffFilter(:last_n, 3))

# Custom function
handoff_tool(billing; history_filter = HandoffFilter(msgs -> filter(m -> m isa PT.UserMessage, msgs)))
```
"""
struct HandoffFilter
    kind::Symbol
    n::Int
    func::Union{Function,Nothing}
end

HandoffFilter() = HandoffFilter(:all, 0, nothing)
HandoffFilter(kind::Symbol) = HandoffFilter(kind, 0, nothing)
HandoffFilter(kind::Symbol, n::Int) = HandoffFilter(kind, n, nothing)
HandoffFilter(f::Function) = HandoffFilter(:custom, 0, f)

function _apply_handoff_filter(filter::HandoffFilter, history::Vector{<:PT.AbstractMessage})
    kind = filter.kind
    kind == :all && return history

    if kind == :none
        return PT.AbstractMessage[]
    elseif kind == :strip_tools
        return PT.AbstractMessage[
            m for m in history if !(m isa PT.ToolMessage || m isa PT.AIToolRequest)
        ]
    elseif kind == :last_n
        n = max(filter.n, 0)
        return n >= length(history) ? history : history[(end - n + 1):end]
    elseif kind == :custom && !isnothing(filter.func)
        return filter.func(history)
    else
        return history
    end
end

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
- `history_filter::HandoffFilter`: How to transform conversation history on handoff.

The orchestrator loop in `run_pipeline!` detects `Handoff` results and
re-runs with the new agent automatically.
"""
struct Handoff
    target::Agent
    message::String
    history_filter::HandoffFilter
end

# Backward-compatible 2-arg constructor
Handoff(target::Agent, message::String) = Handoff(target, message, HandoffFilter())

"""
    handoff_tool(target; name, description, history_filter) -> Tool

Create a `Tool` that, when called by an agent, signals a handoff to `target`.
The LLM passes a `message` argument containing what to forward to the next agent.

# Arguments
- `target::Agent`: The agent to hand off to.
- `name::String`: Tool name (default: `"handoff_to_\$(target.name)"`).
- `description::String`: Tool description.
- `history_filter::HandoffFilter`: How to transform conversation history before
  the receiving agent sees it. Default: `HandoffFilter()` (pass full history).

# Example
```julia
billing_agent = Agent(name="Billing", instructions="Handle billing questions.")
support_agent = Agent(
    name         = "Support",
    instructions = "Triage customer requests.",
    tools        = [
        handoff_tool(billing_agent; history_filter=HandoffFilter(:strip_tools)),
    ],
)
```
"""
function handoff_tool(
    target::Agent;
    name::String="handoff_to_$(target.name)",
    description::String="Transfer the conversation to the $(target.name) agent.",
    history_filter::HandoffFilter=HandoffFilter(),
)
    params = Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "message" => Dict{String,Any}(
                "type" => "string",
                "description" => "The message or context to pass to the $(target.name) agent.",
            ),
        ),
        "required" => ["message"],
    )

    Tool(;
        name=name,
        description=description,
        parameters=params,
        callable=(message::String) -> Handoff(target, message, history_filter),
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
    agent::Agent;
    name::String=agent.name,
    description::String="Call the $(agent.name) agent with a task and get its response.",
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=false,
)
    params = Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "task" => Dict{String,Any}(
                "type" => "string",
                "description" => "The task or question to send to the $(agent.name) agent.",
            ),
        ),
        "required" => ["task"],
    )

    Tool(;
        name=name,
        description=description,
        parameters=params,
        callable=(task::String) -> begin
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
    agent::Agent,
    input::String;
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=true,
    max_handoffs::Int=10,
)
    current_agent = agent
    current_input = input
    handoff_count = 0

    while true
        result = run!(current_agent, current_input; session=session, verbose=verbose)

        # Not a handoff — we're done
        result isa Handoff || return result

        handoff_count += 1
        if handoff_count > max_handoffs
            println(
                stderr, "[run_pipeline!] reached max_handoffs ($max_handoffs); stopping."
            )
            return result.message
        end

        verbose && println(
            "[run_pipeline!] handoff: $(current_agent.name) → $(result.target.name)"
        )

        # Apply history filter before handing off
        if !isnothing(session) && result.history_filter.kind != :all
            session.history = _apply_handoff_filter(result.history_filter, session.history)
        end

        current_agent = result.target
        current_input = isempty(result.message) ? current_input : result.message
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# loop_pipeline! — round-robin agent loop with termination condition
# ──────────────────────────────────────────────────────────────────────────────

"""
    loop_pipeline!(agents, input; stop_when, max_rounds, session, verbose) -> Any

Run `agents` in round-robin order, feeding each agent's output as the next
agent's input, until `stop_when` returns `true` or `max_rounds` is reached.

Each "round" consists of one pass through all agents in order. After every
individual agent run, `stop_when(agent, result)` is checked — if it returns
`true`, the loop ends immediately and that result is returned.

# Arguments
- `agents::Vector{Agent}`: Agents to cycle through in order.
- `input::String`: The initial user message.
- `stop_when`: A function `(agent, result) -> Bool` that signals termination.
  Default: always `false` (loop runs until `max_rounds`).
- `max_rounds::Int`: Safety cap on the number of full rounds (default `5`).
- `session`: Optional shared `Session` across all agents.
- `verbose::Bool`: Print round/agent transitions (default `true`).

# Example
```julia
coder    = Agent(name="Coder",    instructions="Write code based on the task.")
reviewer = Agent(name="Reviewer", instructions="Review code. Say APPROVED if good.")

result = loop_pipeline!(
    [coder, reviewer],
    "Write a fibonacci function";
    max_rounds = 5,
    stop_when  = (agent, result) -> occursin("APPROVED", string(result)),
    session    = Session(),
)
```
"""
function loop_pipeline!(
    agents::Vector{Agent},
    input::String;
    stop_when=(agent, result) -> false,
    max_rounds::Int=5,
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=true,
)
    isempty(agents) && error("loop_pipeline!: agents list must not be empty")

    current_input = input

    for round in 1:max_rounds
        verbose && println("[loop_pipeline!] round $round/$max_rounds")

        for agent in agents
            result = run!(agent, current_input; session=session, verbose=verbose)

            if stop_when(agent, result)
                verbose && println(
                    "[loop_pipeline!] stop_when triggered by $(agent.name) in round $round",
                )
                return result
            end

            current_input = string(result)
        end
    end

    verbose && println(
        stderr,
        "[loop_pipeline!] reached max_rounds ($max_rounds); returning last result.",
    )
    # Return the result of the last agent in the last round
    return current_input
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
            Threads.@spawn run!(agent, inp; session=session, verbose=verbose) for
            inp in inputs
        ]
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
    pairs::Vector{<:Tuple{Agent,String}};
    parallel::Bool=false,
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=false,
)
    isempty(pairs) && return Any[]

    if parallel
        tasks = [
            Threads.@spawn run!(ag, inp; session=session, verbose=verbose) for
            (ag, inp) in pairs
        ]
        return Any[fetch(t) for t in tasks]
    else
        return Any[run!(ag, inp; session=session, verbose=verbose) for (ag, inp) in pairs]
    end
end
