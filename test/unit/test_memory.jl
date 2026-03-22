###############################################################################
# test_memory.jl — unit tests for MemoryEntry, InMemoryMemoryService, scoring
###############################################################################

@testset "MemoryEntry — construction" begin
    entry = MemoryEntry(content="User likes dark mode", user_id="alice", app_name="App")
    @test !isempty(entry.id)
    @test entry.content == "User likes dark mode"
    @test entry.user_id == "alice"
    @test entry.app_name == "App"
    @test isempty(entry.metadata)
    @test isnothing(entry.source_session_id)
    @test entry.created_at > 0.0
end

@testset "MemoryEntry — custom metadata and session_id" begin
    meta = Dict{String,Any}("category" => "preference")
    entry = MemoryEntry(
        content="Prefers tabs",
        user_id="bob",
        app_name="IDE",
        metadata=meta,
        source_session_id="sess-123",
    )
    @test entry.metadata["category"] == "preference"
    @test entry.source_session_id == "sess-123"
end

@testset "_keyword_score" begin
    # Perfect match
    @test NimbleAgents._keyword_score("dark mode", "dark mode") >= 0.9

    # No match
    @test NimbleAgents._keyword_score("dark mode", "sunny day outside") == 0.0

    # Partial overlap
    score = NimbleAgents._keyword_score("dark mode preference", "user prefers dark theme")
    @test score > 0.0
    @test score < 1.0

    # Case insensitivity
    @test NimbleAgents._keyword_score("Dark Mode", "dark mode enabled") > 0.0

    # Exact substring boost
    score_exact = NimbleAgents._keyword_score("dark mode", "the user likes dark mode a lot")
    score_words = NimbleAgents._keyword_score("dark mode", "mode is dark")
    @test score_exact >= score_words

    # Empty query
    @test NimbleAgents._keyword_score("", "anything") == 0.0
end

@testset "InMemoryMemoryService — add and retrieve" begin
    mem = InMemoryMemoryService()
    entry = add_memory!(mem, "User prefers dark mode"; user_id="alice", app_name="App")
    @test entry.content == "User prefers dark mode"
    @test entry.user_id == "alice"

    results = search_memory(mem, "dark mode"; user_id="alice", app_name="App")
    @test length(results) == 1
    @test results[1].content == "User prefers dark mode"
end

@testset "InMemoryMemoryService — search keyword matching" begin
    mem = InMemoryMemoryService()
    add_memory!(mem, "User prefers dark mode"; user_id="u", app_name="a")
    add_memory!(mem, "User is allergic to peanuts"; user_id="u", app_name="a")
    add_memory!(mem, "User works at Acme Corp"; user_id="u", app_name="a")

    results = search_memory(mem, "dark mode"; user_id="u", app_name="a")
    @test length(results) >= 1
    @test results[1].content == "User prefers dark mode"

    results = search_memory(mem, "allergy food"; user_id="u", app_name="a")
    # "allergic" won't match "allergy" exactly, but may or may not match
    # depending on stemming. Just verify we get something reasonable.
    @test results isa Vector{MemoryEntry}
end

@testset "InMemoryMemoryService — user/app scoping" begin
    mem = InMemoryMemoryService()
    add_memory!(mem, "Alice fact"; user_id="alice", app_name="App1")
    add_memory!(mem, "Bob fact"; user_id="bob", app_name="App1")
    add_memory!(mem, "Alice App2 fact"; user_id="alice", app_name="App2")

    # Alice in App1 only sees her App1 memories
    results = search_memory(mem, "fact"; user_id="alice", app_name="App1")
    @test length(results) == 1
    @test results[1].content == "Alice fact"

    # Bob in App1 only sees his memories
    results = search_memory(mem, "fact"; user_id="bob", app_name="App1")
    @test length(results) == 1
    @test results[1].content == "Bob fact"
end

@testset "InMemoryMemoryService — delete" begin
    mem = InMemoryMemoryService()
    entry = add_memory!(mem, "temp fact"; user_id="u", app_name="a")
    @test length(list_memories(mem; user_id="u", app_name="a")) == 1

    delete_memory!(mem, entry.id)
    @test length(list_memories(mem; user_id="u", app_name="a")) == 0
end

@testset "InMemoryMemoryService — list filtering" begin
    mem = InMemoryMemoryService()
    add_memory!(mem, "A"; user_id="alice", app_name="App1")
    add_memory!(mem, "B"; user_id="bob", app_name="App1")
    add_memory!(mem, "C"; user_id="alice", app_name="App2")

    @test length(list_memories(mem)) == 3
    @test length(list_memories(mem; user_id="alice")) == 2
    @test length(list_memories(mem; app_name="App1")) == 2
    @test length(list_memories(mem; user_id="alice", app_name="App1")) == 1
    @test length(list_memories(mem; user_id="charlie")) == 0
end

@testset "InMemoryMemoryService — close! is no-op" begin
    mem = InMemoryMemoryService()
    add_memory!(mem, "fact"; user_id="u", app_name="a")
    close!(mem)  # should not error
    # Still accessible after close (in-memory)
    @test length(list_memories(mem; user_id="u")) == 1
end

@testset "InMemoryMemoryService — top_k limits results" begin
    mem = InMemoryMemoryService()
    for i in 1:10
        add_memory!(mem, "fact number $i about testing"; user_id="u", app_name="a")
    end
    results = search_memory(mem, "fact testing"; user_id="u", app_name="a", top_k=3)
    @test length(results) <= 3
end

@testset "_memory_prompt" begin
    import PromptingTools as PT

    # nil memory
    @test NimbleAgents._memory_prompt(nothing, "hello", nothing) == ""

    # nil session
    mem = InMemoryMemoryService()
    @test NimbleAgents._memory_prompt(mem, "hello", nothing) == ""

    # No matching results
    session = Session(app_name="App", user_id="alice")
    @test NimbleAgents._memory_prompt(mem, "hello", session) == ""

    # With matching results
    add_memory!(mem, "User prefers dark mode"; user_id="alice", app_name="App")
    prompt = NimbleAgents._memory_prompt(mem, "dark mode", session)
    @test occursin("Relevant Memories", prompt)
    @test occursin("dark mode", prompt)
end
