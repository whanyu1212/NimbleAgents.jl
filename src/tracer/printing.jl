###############################################################################
# tracer/printing.jl — pretty-print trace summaries
###############################################################################

"""
    print_trace(trace; io=stdout)

Print a human-readable summary of a `Trace` to `io`.

# Arguments
- `trace::Trace`: Trace to render.
- `io::IO`: Output stream (default: `stdout`).

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
    if trace.total_cache_read_tokens > 0 || trace.total_cache_write_tokens > 0
        println(
            io,
            "  Cache      : $(trace.total_cache_read_tokens) read / " *
            "$(trace.total_cache_write_tokens) write",
        )
    end
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
