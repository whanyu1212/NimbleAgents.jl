###############################################################################
# test_sqlite_memory.jl — unit tests for SQLiteMemoryService
###############################################################################

@testset "SQLiteMemoryService — construction" begin
    path = joinpath(mktempdir(), "test_mem.db")
    mem = SQLiteMemoryService(path)
    @test isfile(path)
    close!(mem)
end

@testset "SQLiteMemoryService — add / search roundtrip" begin
    mem = SQLiteMemoryService(joinpath(mktempdir(), "test_mem.db"))

    entry = add_memory!(mem, "User prefers dark mode";
        user_id="alice", app_name="App")
    @test entry.content == "User prefers dark mode"
    @test entry.user_id == "alice"
    @test !isempty(entry.id)

    results = search_memory(mem, "dark mode"; user_id="alice", app_name="App")
    @test length(results) == 1
    @test results[1].content == "User prefers dark mode"
    @test results[1].id == entry.id

    close!(mem)
end

@testset "SQLiteMemoryService — metadata JSON roundtrip" begin
    mem = SQLiteMemoryService(joinpath(mktempdir(), "test_mem.db"))

    meta = Dict{String, Any}("category" => "preference", "priority" => 1)
    entry = add_memory!(mem, "Uses vim"; user_id="u", app_name="a", metadata=meta)

    results = search_memory(mem, "vim"; user_id="u", app_name="a")
    @test length(results) == 1
    @test results[1].metadata["category"] == "preference"
    @test results[1].metadata["priority"] == 1

    close!(mem)
end

@testset "SQLiteMemoryService — user/app scoping" begin
    mem = SQLiteMemoryService(joinpath(mktempdir(), "test_mem.db"))

    add_memory!(mem, "Alice fact"; user_id="alice", app_name="App1")
    add_memory!(mem, "Bob fact"; user_id="bob", app_name="App1")
    add_memory!(mem, "Alice App2 fact"; user_id="alice", app_name="App2")

    results = search_memory(mem, "fact"; user_id="alice", app_name="App1")
    @test length(results) == 1
    @test results[1].content == "Alice fact"

    results = search_memory(mem, "fact"; user_id="bob", app_name="App1")
    @test length(results) == 1
    @test results[1].content == "Bob fact"

    close!(mem)
end

@testset "SQLiteMemoryService — delete" begin
    mem = SQLiteMemoryService(joinpath(mktempdir(), "test_mem.db"))

    entry = add_memory!(mem, "temp"; user_id="u", app_name="a")
    @test length(list_memories(mem; user_id="u", app_name="a")) == 1

    delete_memory!(mem, entry.id)
    @test length(list_memories(mem; user_id="u", app_name="a")) == 0

    close!(mem)
end

@testset "SQLiteMemoryService — list filtering" begin
    mem = SQLiteMemoryService(joinpath(mktempdir(), "test_mem.db"))

    add_memory!(mem, "A"; user_id="alice", app_name="App1")
    add_memory!(mem, "B"; user_id="bob",   app_name="App1")
    add_memory!(mem, "C"; user_id="alice", app_name="App2")

    @test length(list_memories(mem)) == 3
    @test length(list_memories(mem; user_id="alice")) == 2
    @test length(list_memories(mem; app_name="App1")) == 2
    @test length(list_memories(mem; user_id="alice", app_name="App1")) == 1
    @test length(list_memories(mem; user_id="charlie")) == 0

    close!(mem)
end

@testset "SQLiteMemoryService — search with no results" begin
    mem = SQLiteMemoryService(joinpath(mktempdir(), "test_mem.db"))

    results = search_memory(mem, "anything"; user_id="u", app_name="a")
    @test isempty(results)

    close!(mem)
end

@testset "SQLiteMemoryService — close!" begin
    mem = SQLiteMemoryService(joinpath(mktempdir(), "test_mem.db"))
    add_memory!(mem, "fact"; user_id="u", app_name="a")
    close!(mem)
    # After close, operations should fail (DB is closed)
    @test_throws Exception add_memory!(mem, "another"; user_id="u", app_name="a")
end
