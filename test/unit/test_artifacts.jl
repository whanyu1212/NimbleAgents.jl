import PromptingTools as PT

@testset "Artifact construction" begin
    a = Artifact(
        session_id="sess-1",
        name="report.pdf",
        type=:file,
        content_type="application/pdf",
        path="/tmp/report.pdf",
    )
    @test a isa Artifact
    @test !isempty(a.id)
    @test a.session_id == "sess-1"
    @test a.name == "report.pdf"
    @test a.type == :file
    @test a.content_type == "application/pdf"
    @test a.path == "/tmp/report.pdf"
    @test isempty(a.metadata)
    @test a.created_at > 0.0

    # Two artifacts get different UUIDs
    b = Artifact(session_id="s", name="x", path="/x")
    @test a.id != b.id
end

@testset "_mime_for_path" begin
    @test NimbleAgents._mime_for_path("plot.png") == "image/png"
    @test NimbleAgents._mime_for_path("photo.jpg") == "image/jpeg"
    @test NimbleAgents._mime_for_path("photo.jpeg") == "image/jpeg"
    @test NimbleAgents._mime_for_path("vec.svg") == "image/svg+xml"
    @test NimbleAgents._mime_for_path("doc.pdf") == "application/pdf"
    @test NimbleAgents._mime_for_path("data.csv") == "text/csv"
    @test NimbleAgents._mime_for_path("info.json") == "application/json"
    @test NimbleAgents._mime_for_path("notes.txt") == "text/plain"
    @test NimbleAgents._mime_for_path("readme.md") == "text/markdown"
    @test NimbleAgents._mime_for_path("code.jl") == "text/x-julia"
    @test NimbleAgents._mime_for_path("code.py") == "text/x-python"
    @test NimbleAgents._mime_for_path("page.html") == "text/html"
    @test NimbleAgents._mime_for_path("blob.bin") == "application/octet-stream"
    # case-insensitive
    @test NimbleAgents._mime_for_path("PLOT.PNG") == "image/png"
end

@testset "_type_for_mime" begin
    @test NimbleAgents._type_for_mime("image/png") == :plot
    @test NimbleAgents._type_for_mime("image/jpeg") == :plot
    @test NimbleAgents._type_for_mime("image/svg+xml") == :plot
    @test NimbleAgents._type_for_mime("text/plain") == :text
    @test NimbleAgents._type_for_mime("text/csv") == :data
    @test NimbleAgents._type_for_mime("application/json") == :data
    @test NimbleAgents._type_for_mime("application/pdf") == :file
    @test NimbleAgents._type_for_mime("application/octet-stream") == :file
end

@testset "register_artifact! — no store" begin
    session = Session(app_name="App", user_id="u1")
    tmpfile = tempname() * ".csv"
    write(tmpfile, "a,b\n1,2\n")

    art = register_artifact!(
        session, tmpfile; name="my-data", metadata=Dict{String,Any}("source" => "test")
    )

    @test art isa Artifact
    @test art.name == "my-data"
    @test art.type == :data
    @test art.content_type == "text/csv"
    @test art.path == tmpfile          # unchanged — no store
    @test art.metadata["source"] == "test"
    @test length(session.artifacts) == 1
    @test session.artifacts[1] === art
end

@testset "register_artifact! — with InMemorySessionStore copies file" begin
    store = InMemorySessionStore()
    session = Session(app_name="App", user_id="u1")

    tmpfile = tempname() * ".png"
    write(tmpfile, "fake png bytes")

    art = register_artifact!(session, tmpfile; store=store)

    @test art.path != tmpfile           # copied to store artifacts dir
    @test isfile(art.path)
    @test art.type == :plot             # inferred from .png
    @test length(session.artifacts) == 1
end

@testset "InMemorySessionStore — save / load / delete / list" begin
    store = InMemorySessionStore()

    s1 = Session(app_name="App1", user_id="alice")
    s2 = Session(app_name="App1", user_id="bob")
    s3 = Session(app_name="App2", user_id="alice")

    save!(store, s1);
    save!(store, s2);
    save!(store, s3)

    # load returns the same object
    @test load(store, s1.id) === s1
    @test load(store, s2.id) === s2
    @test isnothing(load(store, "nonexistent-id"))

    # list — all
    ids = list(store)
    @test length(ids) == 3
    @test s1.id in ids

    # list — filtered
    @test length(list(store; app_name="App1")) == 2
    @test length(list(store; user_id="alice")) == 2
    @test length(list(store; app_name="App1", user_id="alice")) == 1
    @test length(list(store; app_name="App2", user_id="bob")) == 0

    # delete
    Base.delete!(store, s1.id)
    @test isnothing(load(store, s1.id))
    @test length(list(store)) == 2
end

@testset "JSONSessionStore — save / load / delete / list" begin
    tmpdir = mktempdir()
    store = JSONSessionStore(joinpath(tmpdir, "sessions"))

    s = Session(app_name="TestApp", user_id="test-user")
    push!(s.history, PT.UserMessage("hello"))
    push!(s.history, PT.AIMessage("hi there"))
    s.state["score"] = 42

    save!(store, s)

    # File was created
    @test isfile(joinpath(store.dir, s.id * ".json"))

    # Load restores history and state
    s2 = load(store, s.id)
    @test !isnothing(s2)
    @test s2.id == s.id
    @test s2.app_name == "TestApp"
    @test s2.user_id == "test-user"
    @test length(s2.history) == 2
    @test s2.history[1] isa PT.UserMessage
    @test s2.history[1].content == "hello"
    @test s2.history[2] isa PT.AIMessage
    @test s2.history[2].content == "hi there"
    @test s2.state["score"] == 42

    # Missing session → nothing
    @test isnothing(load(store, "no-such-id"))

    # list / filter
    sa = Session(app_name="A", user_id="u1")
    sb = Session(app_name="A", user_id="u2")
    sc = Session(app_name="B", user_id="u1")
    save!(store, sa);
    save!(store, sb);
    save!(store, sc)

    @test length(list(store)) == 4  # s + sa + sb + sc
    @test length(list(store; app_name="A")) == 2
    @test length(list(store; user_id="u1")) == 2
    @test length(list(store; app_name="A", user_id="u1")) == 1

    # delete removes file and artifact dir
    Base.delete!(store, s.id)
    @test !isfile(joinpath(store.dir, s.id * ".json"))
    @test isnothing(load(store, s.id))
end

@testset "JSONSessionStore — artifact roundtrip" begin
    tmpdir = mktempdir()
    store = JSONSessionStore(joinpath(tmpdir, "sessions"))

    session = Session(app_name="ArtApp", user_id="art-user")
    tmpfile = tempname() * ".txt"
    write(tmpfile, "artifact content")

    art = register_artifact!(session, tmpfile; name="my-artifact", store=store)
    save!(store, session)

    s2 = load(store, session.id)
    @test length(s2.artifacts) == 1
    @test s2.artifacts[1].name == "my-artifact"
    @test s2.artifacts[1].type == :text
    @test s2.artifacts[1].content_type == "text/plain"
end

@testset "JSONSessionStore — _safe_state drops non-serialisable values" begin
    state = Dict{String,Any}(
        "count" => 42,
        "label" => "hello",
        "_julia_sandbox" => Module(),      # not serialisable
    )
    safe = NimbleAgents._safe_state(state)
    @test haskey(safe, "count")
    @test haskey(safe, "label")
    @test !haskey(safe, "_julia_sandbox")
end

@testset "_msg_to_dict / _dict_to_msg roundtrip" begin
    msgs = PT.AbstractMessage[
        PT.UserMessage("hello"),
        PT.AIMessage("world"),
        PT.SystemMessage("you are a bot"),
        PT.ToolMessage(content="result", name="my_tool", tool_call_id="tc1", raw="result"),  # raw required by PT
    ]

    for msg in msgs
        d = NimbleAgents._msg_to_dict(msg)
        back = NimbleAgents._dict_to_msg(d)
        @test back isa typeof(msg)
        @test back.content == msg.content
    end
end
