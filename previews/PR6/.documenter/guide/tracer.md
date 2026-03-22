


# Tracer {#Tracer}

The tracer gives you a structured view of everything that happened during an agent run — token usage, tool calls, LLM call counts, and timing — without any upfront instrumentation.

All trace data comes from `TurnEvent` and `ToolEvent` objects already recorded by `run!` into the `Session`. The `Trace` is just a clean aggregation layer on top.

## Basic Usage {#Basic-Usage}

```julia
session = Session(app_name="MyApp", user_id="alice")

run!(agent, "What is 6 + 7?"; session=session)
run!(agent, "Now multiply that by 3."; session=session)

# Build a trace after the fact — no upfront setup needed
trace = Trace(session)

print_trace(trace)
```


## What&#39;s in a Trace {#What's-in-a-Trace}

|                 Field |                                     Description |
| ---------------------:| -----------------------------------------------:|
|               `turns` | `Vector{TurnEvent}` — one entry per `run!` call |
|  `total_input_tokens` |            Sum of input tokens across all turns |
| `total_output_tokens` |           Sum of output tokens across all turns |
|        `total_tokens` |                            Combined token total |
|     `total_llm_calls` |                         Total LLM requests made |
|    `total_tool_calls` |                           Total tool calls made |
|            `duration` |  Sum of elapsed time across all turns (seconds) |
|              `agents` | Unique agent names in order of first appearance |


Each `TurnEvent` in `trace.turns` carries:

|                            Field |                                                              Description |
| --------------------------------:| ------------------------------------------------------------------------:|
|                          `agent` |                                                               Agent name |
|                          `input` |                                               User message for this turn |
|                         `output` |                                                           Final response |
|                     `tool_calls` | `Vector{ToolEvent}` — each tool call with args, result, error, timestamp |
|                      `llm_calls` |                                                   LLM requests this turn |
| `input_tokens` / `output_tokens` |                                                    Token usage this turn |
|                        `elapsed` |                                         Wall-clock seconds for this turn |


## Programmatic Inspection {#Programmatic-Inspection}

```julia
trace = Trace(session)

# Aggregate stats
println(trace.total_tokens)     # total tokens across all turns
println(trace.total_tool_calls) # how many tools were called
println(trace.duration)         # total wall time in seconds

# Per-turn detail
for (i, turn) in enumerate(trace.turns)
    println("Turn $(i): $(turn.input) → $(turn.output)")
    for te in turn.tool_calls
        println("  $(te.name)($(te.args)) → $(te.result)")
    end
end
```


## Printing a Summary {#Printing-a-Summary}

`print_trace` produces a human-readable summary:

```julia
print_trace(trace)
```


```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Turns      : 2
  Agents     : MathBot
  Duration   : 3.42s
  LLM calls  : 3
  Tool calls : 2
  Tokens     : 312 in / 88 out / 400 total

  Turn 1 — MathBot  [1.8s | 2 llm | 1 tool | 210 tok]
    input  : What is 6 + 7?
    output : The answer is 13.
    tool   : add(x=6, y=7) → 13

  Turn 2 — MathBot  [1.6s | 1 llm | 1 tool | 190 tok]
    input  : Now multiply that by 3.
    output : The result is 39.
    tool   : multiply(x=13, y=3) → 39
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```


You can also write to any `IO`:

```julia
open("run_summary.txt", "w") do f
    print_trace(trace; io=f)
end
```


## Saving and Loading {#Saving-and-Loading}

```julia
# Save to JSON
save_trace(trace, "traces/run_001.json")

# Load back for offline analysis or evaluation
data = load_trace("traces/run_001.json")

# Check which tools were called
for turn in data["turns"]
    for tc in turn["tool_calls"]
        println(tc["name"], " → ", tc["result"])
    end
end
```


The JSON structure mirrors the `Trace` fields directly — easy to process with any script or feed into an evaluation pipeline.

## Runnable Example {#Runnable-Example}

A complete multi-turn tracing demo with math tools, `print_trace`, and JSON export:

```julia
# examples/agents/tracing_demo.jl
using DotEnv; DotEnv.load!()
using NimbleAgents

@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end

@tool function multiply(x::Int, y::Int)
    "Multiply two integers together."
    x * y
end

agent   = Agent(name="MathBot", instructions="Use the tools to compute answers.",
                tools=[add_tool, multiply_tool])
session = Session(app_name="TracingDemo", user_id="alice")

run!(agent, "What is 6 + 7?";            session=session)
run!(agent, "Now multiply that by 3.";   session=session)

trace = Trace(session)
print_trace(trace)

# Per-turn breakdown
for (i, turn) in enumerate(trace.turns)
    println("Turn $(i): \"$(turn.input)\" → $(turn.output)")
    for te in turn.tool_calls
        println("  $(te.name)($(te.args)) → $(te.result)")
    end
end

save_trace(trace, "trace_output.json")
```


```bash
julia --project examples/agents/tracing_demo.jl
```


## Without a Session {#Without-a-Session}

If you ran the agent without a `Session`, you can build a trace from raw `TurnEvent` objects by collecting them via hooks:

```julia
turns = TurnEvent[]

agent = Agent(
    name  = "Bot",
    hooks = AgentHooks(
        on_complete = (ag, result) -> nothing,   # result already in turn
    ),
    ...
)

# Or just use a session — it's the simplest path
session = Session()
run!(agent, input; session=session)
trace = Trace(session)
```


The recommended approach is always to pass a `Session` — it accumulates everything automatically.
