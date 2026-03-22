###############################################################################
# tracer.jl — Lightweight trace capture and export
#
# A Trace is a thin view over a Session's event log, with aggregate helpers
# and export utilities. No new data is collected — everything comes from
# TurnEvent / ToolEvent already recorded by run!.
#
# Usage:
#
#   session = Session(app_name="MyApp", user_id="alice")
#   run!(agent, "What is 2+2?"; session=session)
#
#   trace = Trace(session)
#   print_trace(trace)
#   save_trace(trace, "trace.json")
###############################################################################

# ── Trace ─────────────────────────────────────────────────────────────────────

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
- `total_tokens::Int`: `total_input_tokens + total_output_tokens`.
- `total_cost::Float64`: Estimated total USD cost across all turns.
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
    total_tokens::Int
    total_cost::Float64
    total_llm_calls::Int
    total_tool_calls::Int
    duration::Float64
    agents::Vector{String}
end

function Trace(turns::Vector{TurnEvent})
    isempty(turns) && return Trace(turns, 0, 0, 0, 0.0, 0, 0, 0.0, String[])

    total_in = sum(t.input_tokens for t in turns)
    total_out = sum(t.output_tokens for t in turns)
    total_cost = sum(t.cost for t in turns)
    total_llm = sum(t.llm_calls for t in turns)
    total_tool = sum(length(t.tool_calls) for t in turns)
    duration = sum(t.elapsed for t in turns)

    seen = Set{String}()
    agents = String[]
    for t in turns
        t.agent in seen && continue
        push!(seen, t.agent)
        push!(agents, t.agent)
    end

    Trace(
        turns,
        total_in,
        total_out,
        total_in + total_out,
        total_cost,
        total_llm,
        total_tool,
        duration,
        agents,
    )
end

Trace(session::Session) = Trace(copy(session.events))

# ── print_trace ───────────────────────────────────────────────────────────────

"""
    print_trace(trace; io=stdout)

Print a human-readable summary of a `Trace` to `io`.

```
━━━ Trace ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Turns      : 2
  Agents     : MathBot
  Duration   : 3.42s
  LLM calls  : 3
  Tool calls : 2
  Tokens     : 312 in / 88 out / 400 total

  Turn 1 — MathBot  [1.8s | 2 llm | 1 tool | 210 tok]
    input  : What is 2 + 2?
    output : The answer is 4.
    tools  : add(x=2, y=2) → 4

  Turn 2 — MathBot  [1.6s | 1 llm | 1 tool | 190 tok]
    input  : Now multiply by 3.
    output : The result is 12.
    tools  : multiply(x=4, y=3) → 12
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
"""
function print_trace(trace::Trace; io::IO=stdout)
    bar = "━" ^ 42
    println(io, bar)
    println(io, "  Turns      : $(length(trace.turns))")
    println(io, "  Agents     : $(join(trace.agents, ", "))")
    println(io, "  Duration   : $(round(trace.duration; digits=2))s")
    println(io, "  LLM calls  : $(trace.total_llm_calls)")
    println(io, "  Tool calls : $(trace.total_tool_calls)")
    println(
        io,
        "  Tokens     : $(trace.total_input_tokens) in / " *
        "$(trace.total_output_tokens) out / $(trace.total_tokens) total",
    )
    if trace.total_cost > 0
        println(io, "  Cost       : \$$(round(trace.total_cost; digits=4))")
    end

    for (i, turn) in enumerate(trace.turns)
        tok = turn.input_tokens + turn.output_tokens
        cost_str = turn.cost > 0 ? " | \$$(round(turn.cost; digits=4))" : ""
        println(io)
        println(
            io,
            "  Turn $(i) — $(turn.agent)  " *
            "[$(round(turn.elapsed; digits=2))s | " *
            "$(turn.llm_calls) llm | " *
            "$(length(turn.tool_calls)) tool | " *
            "$(tok) tok$(cost_str)]",
        )
        println(io, "    input  : $(turn.input)")
        out = isnothing(turn.output) ? "(none)" : string(turn.output)
        println(io, "    output : $(length(out) > 120 ? out[1:120] * "…" : out)")
        for te in turn.tool_calls
            args_str = join(["$(k)=$(repr(v))" for (k, v) in te.args], ", ")
            result_str = if !isnothing(te.error)
                "ERROR: $(te.error)"
            else
                r = repr(te.result)
                length(r) > 80 ? r[1:80] * "…" : r
            end
            println(io, "    tool   : $(te.name)($(args_str)) → $(result_str)")
        end
    end

    println(io)
    println(io, bar)
end

# ── save_trace ────────────────────────────────────────────────────────────────

"""
    save_trace(trace, path)

Serialise a `Trace` to a JSON file at `path`.

The JSON structure mirrors the `Trace` fields — suitable for offline analysis,
feeding into an evaluation script, or archiving agent runs.
"""
function save_trace(trace::Trace, path::String)
    data = Dict{String,Any}(
        "total_input_tokens" => trace.total_input_tokens,
        "total_output_tokens" => trace.total_output_tokens,
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

# ── load_trace ────────────────────────────────────────────────────────────────

"""
    load_trace(path) -> Dict{String, Any}

Load a previously saved trace from a JSON file.
Returns the raw parsed Dict — useful for offline analysis or evaluation scripts.
"""
function load_trace(path::String)::Dict{String,Any}
    isfile(path) || error("Trace file not found: $(path)")
    Dict{String,Any}(JSON3.read(read(path, String), Dict{String,Any}))
end
