# examples/streaming.jl
#
# Demonstrates on_token streaming in run!.
#
# Run from the project root:
#   julia --project=. examples/streaming.jl

using DotEnv
DotEnv.load!()

using NimbleAgents
import Term: Panel, tprintln

@tool function add(x::Int, y::Int)
    "Add two integers."
    x + y
end

agent = Agent(
    name         = "StreamBot",
    instructions = "You are a helpful assistant. Be concise.",
    tools        = [add_tool],
)

# ── Example 1: stream to stdout ───────────────────────────────────────────────

print(Panel("Stream to stdout — tokens appear as they are generated";
            title="Example 1", style="cyan", width=60))
println()

run!(agent, "Write a 3-sentence description of the Julia programming language.";
     verbose   = false,
     on_token  = token -> print(token))

println("\n")

# ── Example 2: stream through tools then final response ───────────────────────

print(Panel("Tool call first, then streamed final response";
            title="Example 2", style="yellow", width=60))
println()

tprintln("{dim}(tool rounds are blocking; only the final text response streams){/dim}")
println()

run!(agent, "What is 42 + 58? Then write one sentence about why that number is interesting.";
     verbose  = false,
     on_token = token -> print(token))

println("\n")

# ── Example 3: collect tokens into a buffer ───────────────────────────────────

print(Panel("Collect tokens into a buffer";
            title="Example 3", style="magenta", width=60))
println()

buf = IOBuffer()
result = run!(agent, "Name three Julia packages in one sentence each.";
              verbose  = false,
              on_token = token -> print(buf, token))

collected = String(take!(buf))
tprintln("  Collected {bold}$(length(collected)){/bold} chars, {bold}$(length(split(collected)))){/bold} words")
println()
