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

# ── Set up a memory service ──────────────────────────────────────────────────
# InMemoryMemoryService for this demo. For persistence across process restarts,
# use SQLiteMemoryService("memory.db") instead.
memory = InMemoryMemoryService()
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
