# examples/repl_demo.jl
#
# Demonstrates the eval_julia_tool — a persistent Julia REPL sandbox
# that retains state across tool calls within a session.
#
# Run:
#   julia --project=. -t 4 examples/repl_demo.jl

using DotEnv
DotEnv.load!()

using NimbleAgents

agent = Agent(
    name         = "JuliaREPL",
    instructions = """
    You are a Julia programming assistant with access to a persistent Julia REPL.
    Use eval_julia to run code, perform calculations, and analyse data.
    State persists across calls — variables and imports carry over.
    Always show the code you ran and its output.
    """,
    tools = [eval_julia_tool],
    model = "gpt-5.4-nano-2026-03-17",
)

# ── Scenario 1: Stateful computation ──────────────────────────────────────────

println("=" ^ 60)
println("Scenario 1: Stateful computation across turns")
println("-" ^ 60)

session = Session(app_name="repl_demo", user_id="dev")

result1 = run!(agent,
    "Create a vector of the first 10 Fibonacci numbers and compute their sum.";
    session = session, verbose = false)
println(result1)
println()

result2 = run!(agent,
    "Now compute the mean and standard deviation of those Fibonacci numbers.";
    session = session, verbose = false)
println(result2)
println()

# ── Scenario 2: Data analysis ──────────────────────────────────────────────────

println("=" ^ 60)
println("Scenario 2: Data analysis with Statistics stdlib")
println("-" ^ 60)

session2 = Session(app_name="repl_demo", user_id="dev")

result3 = run!(agent, """
    Generate 100 random normal samples with mean=5 and std=2,
    then compute the sample mean, std, min, and max.
    """;
    session = session2, verbose = false)
println(result3)
println()

# ── Scenario 3: Function definition and reuse ─────────────────────────────────

println("=" ^ 60)
println("Scenario 3: Define and reuse functions")
println("-" ^ 60)

session3 = Session(app_name="repl_demo", user_id="dev")

result4 = run!(agent,
    "Define a function that checks if a number is prime, then find all primes under 50.";
    session = session3, verbose = false)
println(result4)
println()

result5 = run!(agent,
    "Using the prime function you just defined, find the sum of all primes under 100.";
    session = session3, verbose = false)
println(result5)
