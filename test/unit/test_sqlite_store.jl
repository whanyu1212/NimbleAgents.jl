###############################################################################
# test_sqlite_store.jl — unit tests for SQLiteSessionStore
###############################################################################

import PromptingTools as PT

@testset "SQLiteSessionStore — construction" begin
    path  = joinpath(mktempdir(), "test.db")
    store = SQLiteSessionStore(path)
    @test isfile(path)
    @test isdir(store_artifacts_dir(store))
    close!(store)
end

@testset "SQLiteSessionStore — save / load roundtrip" begin
    store = SQLiteSessionStore(joinpath(mktempdir(), "test.db"))

    s = Session(app_name="TestApp", user_id="alice")
    push!(s.history, PT.UserMessage("hello"))
    push!(s.history, PT.AIMessage("hi there"))
    s.state["score"] = 42

    save!(store, s)

    s2 = load(store, s.id)
    @test !isnothing(s2)
    @test s2.id       == s.id
    @test s2.app_name == "TestApp"
    @test s2.user_id  == "alice"
    @test length(s2.history) == 2
    @test s2.history[1] isa PT.UserMessage
    @test s2.history[1].content == "hello"
    @test s2.history[2] isa PT.AIMessage
    @test s2.history[2].content == "hi there"
    @test s2.state["score"] == 42

    close!(store)
end

@testset "SQLiteSessionStore — load missing returns nothing" begin
    store = SQLiteSessionStore(joinpath(mktempdir(), "test.db"))
    @test isnothing(load(store, "nonexistent-id"))
    close!(store)
end

@testset "SQLiteSessionStore — save overwrites (upsert)" begin
    store = SQLiteSessionStore(joinpath(mktempdir(), "test.db"))

    s = Session(app_name="App", user_id="u")
    s.state["v"] = 1
    save!(store, s)

    s.state["v"] = 2
    push!(s.history, PT.UserMessage("updated"))
    save!(store, s)

    s2 = load(store, s.id)
    @test s2.state["v"] == 2
    @test length(s2.history) == 1
    @test s2.history[1].content == "updated"

    close!(store)
end

@testset "SQLiteSessionStore — delete" begin
    store = SQLiteSessionStore(joinpath(mktempdir(), "test.db"))

    s = Session(app_name="App", user_id="u")
    save!(store, s)
    @test !isnothing(load(store, s.id))

    Base.delete!(store, s.id)
    @test isnothing(load(store, s.id))

    close!(store)
end

@testset "SQLiteSessionStore — list with filters" begin
    store = SQLiteSessionStore(joinpath(mktempdir(), "test.db"))

    s1 = Session(app_name="App1", user_id="alice")
    s2 = Session(app_name="App1", user_id="bob")
    s3 = Session(app_name="App2", user_id="alice")
    save!(store, s1); save!(store, s2); save!(store, s3)

    # All
    ids = list(store)
    @test length(ids) == 3

    # By app_name
    @test length(list(store; app_name="App1")) == 2
    @test length(list(store; app_name="App2")) == 1
    @test length(list(store; app_name="App3")) == 0

    # By user_id
    @test length(list(store; user_id="alice")) == 2
    @test length(list(store; user_id="bob"))   == 1

    # Both
    @test length(list(store; app_name="App1", user_id="alice")) == 1
    @test length(list(store; app_name="App2", user_id="bob"))   == 0

    close!(store)
end

@testset "SQLiteSessionStore — artifact roundtrip" begin
    tmpdir = mktempdir()
    store  = SQLiteSessionStore(joinpath(tmpdir, "test.db"))

    session = Session(app_name="ArtApp", user_id="art-user")
    tmpfile = tempname() * ".txt"
    write(tmpfile, "artifact content")

    art = register_artifact!(session, tmpfile; name="my-artifact", store=store)
    save!(store, session)

    s2 = load(store, session.id)
    @test length(s2.artifacts) == 1
    @test s2.artifacts[1].name         == "my-artifact"
    @test s2.artifacts[1].type         == :text
    @test s2.artifacts[1].content_type == "text/plain"

    close!(store)
end

@testset "SQLiteSessionStore — message types roundtrip" begin
    store = SQLiteSessionStore(joinpath(mktempdir(), "test.db"))

    s = Session(app_name="MsgTest", user_id="u")
    push!(s.history, PT.SystemMessage("you are a bot"))
    push!(s.history, PT.UserMessage("hello"))
    push!(s.history, PT.AIMessage("hi"))
    push!(s.history, PT.ToolMessage(content="result", name="my_tool",
                                     tool_call_id="tc1", raw="result"))
    save!(store, s)

    s2 = load(store, s.id)
    @test length(s2.history) == 4
    @test s2.history[1] isa PT.SystemMessage
    @test s2.history[2] isa PT.UserMessage
    @test s2.history[3] isa PT.AIMessage
    @test s2.history[4] isa PT.ToolMessage
    @test s2.history[4].content == "result"

    close!(store)
end
