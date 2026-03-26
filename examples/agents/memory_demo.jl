###############################################################################
# memory_demo.jl — Cross-session memory example
#
# Demonstrates how agents can store and retrieve facts across sessions using
# the InMemoryMemoryService (or SQLiteMemoryService for persistence).
#
# Run:  julia --project examples/agents/memory_demo.jl
###############################################################################

using DotEnv
DotEnv.load!()

using NimbleAgents

function example_model(; tier::Symbol=:mini)
    if isempty(get(ENV, "GOOGLE_API_KEY", "")) && !isempty(get(ENV, "GEMINI_API_KEY", ""))
        ENV["GOOGLE_API_KEY"] = ENV["GEMINI_API_KEY"]
    end

    override = strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_MODEL", ""))
    !isempty(override) && return override

    openai_model, gemini_model = tier === :nano ?
        ("gpt-5.4-nano-2026-03-17", "gemini-2.5-flash-lite") :
        ("gpt-5.4-mini", "gemini-2.5-flash")

    provider = lowercase(strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_PROVIDER", "")))
    provider == "openai" && return openai_model
    provider == "gemini" && return gemini_model
    !isempty(provider) && error(
        "Unsupported NIMBLEAGENTS_EXAMPLE_PROVIDER=$(provider). Use 'openai' or 'gemini'.",
    )

    !isempty(get(ENV, "OPENAI_API_KEY", "")) && return openai_model
    !isempty(get(ENV, "GOOGLE_API_KEY", "")) && return gemini_model

    error(
        "Set OPENAI_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY, or set NIMBLEAGENTS_EXAMPLE_MODEL.",
    )
end

const EXAMPLE_MODEL = example_model()

# ── Set up a memory service ──────────────────────────────────────────────────
# InMemoryMemoryService for this demo. For persistence across process restarts,
# use SQLiteMemoryService("memory.db") instead.
memory = InMemoryMemoryService()
# using SQLite  # enable SQLiteMemoryService extension
# memory = SQLiteMemoryService("memory.db")  # persistent across process restarts

# ── Create an agent with memory ──────────────────────────────────────────────
agent = Agent(;
    name="MemoryBot",
    instructions="""You are a helpful assistant with long-term memory.
When the user tells you a preference or fact about themselves, use the
save_memory tool to store it. When answering questions, use recall_memory
to check if you have relevant stored knowledge.""",
    tools=[save_memory_tool, recall_memory_tool],
    memory=memory,
    model=EXAMPLE_MODEL,
)

# ── Session 1: Store some facts ──────────────────────────────────────────────
println("=" ^ 60)
println("SESSION 1 — Teaching the agent")
println("=" ^ 60)

session1 = Session(; app_name="MemoryDemo", user_id="alice")

result = run!(
    agent,
    "Remember that my favorite color is blue and I'm allergic to peanuts.";
    session=session1,
)
println("\nAgent: ", result)

# ── Session 2: New session, same user — memories persist ─────────────────────
println("\n", "=" ^ 60)
println("SESSION 2 — New session, recalling memories")
println("=" ^ 60)

session2 = Session(; app_name="MemoryDemo", user_id="alice")

result = run!(agent, "What do you know about my preferences?"; session=session2)
println("\nAgent: ", result)

# ── Show stored memories directly ────────────────────────────────────────────
println("\n", "=" ^ 60)
println("Stored memories for alice:")
println("=" ^ 60)
for entry in list_memories(memory; user_id="alice", app_name="MemoryDemo")
    println("  - [$(entry.id[1:8])...] $(entry.content)")
end
