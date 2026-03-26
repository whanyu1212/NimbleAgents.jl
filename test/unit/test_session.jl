using JSON3: JSON3
using DBInterface: DBInterface

@testset "Session" begin

    # ── construction ──────────────────────────────────────────────────────
    s = Session()
    @test s isa Session
    @test isempty(s)
    @test length(s) == 0
    @test s.app_name == "NimbleAgents"
    @test s.user_id == "default"
    @test !isempty(s.id)
    @test isempty(s.state)
    @test isempty(s.events)

    # custom fields
    s2 = Session(app_name="MyApp", user_id="alice")
    @test s2.app_name == "MyApp"
    @test s2.user_id == "alice"

    # ── state dict ────────────────────────────────────────────────────────
    s.state["score"] = 42
    s.state["name"] = "Bob"
    @test s.state["score"] == 42
    @test s.state["name"] == "Bob"

    # ── reset! clears everything ──────────────────────────────────────────
    push!(s.history, NimbleAgents.UserMessage("hi"))
    push!(s.events, TurnEvent("TestAgent", "test-model", "hi"))
    reset!(s)
    @test isempty(s)
    @test isempty(s.state)
    @test isempty(s.events)

    # ── ToolEvent ─────────────────────────────────────────────────────────
    te = ToolEvent("add", Dict{Symbol,Any}(:x => 1, :y => 2), 3)
    @test te.name == "add"
    @test te.result == 3
    @test isnothing(te.error)

    te_err = ToolEvent("add", Dict{Symbol,Any}(:x => 1, :y => 2); error="oops")
    @test te_err.error == "oops"
    @test isnothing(te_err.result)

    # ── TurnEvent ─────────────────────────────────────────────────────────
    turn = TurnEvent("MathAgent", "test-model", "What is 1+1?")
    @test turn.agent == "MathAgent"
    @test turn.model == "test-model"
    @test turn.input == "What is 1+1?"
    @test isnothing(turn.output)
    @test turn.llm_calls == 0
    @test turn.input_tokens == 0
    @test turn.cost == 0.0
    @test isempty(turn.tool_calls)

    # ── _save_history! skips system messages and already-seeded msgs ──────
    s3 = Session()
    conv = NimbleAgents.AbstractMessage[
        NimbleAgents.SystemMessage("You are helpful."),
        NimbleAgents.UserMessage("turn 1"),
        NimbleAgents.AIMessage("response 1"),
    ]
    NimbleAgents._save_history!(s3, conv, 2)  # 2 seeded
    @test length(s3) == 1
    @test s3.history[1] isa NimbleAgents.AIMessage

    # system message is never saved
    NimbleAgents._save_history!(s3, conv, 0)  # treat all as new
    @test all(m -> !(m isa NimbleAgents.SystemMessage), s3.history)

    # ── _accumulate_usage! adds token counts ─────────────────────────────
    turn2 = TurnEvent("TestAgent", "test-model", "test")
    mock_msg = NimbleAgents.AIMessage(
        content="hi", usage=NimbleAgents.TokenUsage(input_tokens=10, output_tokens=5)
    )
    NimbleAgents._accumulate_usage!(turn2, mock_msg)
    @test turn2.input_tokens == 10
    @test turn2.output_tokens == 5

    # calling again accumulates
    NimbleAgents._accumulate_usage!(turn2, mock_msg)
    @test turn2.input_tokens == 20
    @test turn2.output_tokens == 10
end

# ── Model pricing ────────────────────────────────────────────────────────────

@testset "set_model_pricing! / get / remove" begin
    set_model_pricing!("cost-test-model", 1.0, 2.0)
    p = get_model_pricing("cost-test-model")
    @test p.input == 1.0
    @test p.output == 2.0

    remove_model_pricing!("cost-test-model")
    @test isnothing(get_model_pricing("cost-test-model"))
end

@testset "default pricing for known models" begin
    p = get_model_pricing("gpt-5.4-mini")
    @test !isnothing(p)
    @test p.input == 0.40
    @test p.output == 1.60
end

@testset "_compute_cost" begin
    set_model_pricing!("cost-calc-model", 2.0, 8.0)  # $2/M in, $8/M out
    cost = NimbleAgents._compute_cost("cost-calc-model", 1_000_000, 500_000)
    @test cost ≈ 2.0 + 4.0  # $2 input + $4 output = $6
    remove_model_pricing!("cost-calc-model")
end

@testset "_compute_cost — unknown model returns 0" begin
    cost = NimbleAgents._compute_cost("nonexistent-model-xyz", 1000, 500)
    @test cost == 0.0
end

@testset "_accumulate_usage! computes cost" begin
    set_model_pricing!("cost-accum-model", 1.0, 2.0)  # $1/M in, $2/M out
    turn = TurnEvent("Bot", "cost-accum-model", "hi")
    mock_msg = NimbleAgents.AIMessage(
        content="ok", usage=NimbleAgents.TokenUsage(input_tokens=1000, output_tokens=500)
    )
    NimbleAgents._accumulate_usage!(turn, mock_msg)

    # 1000 * 1.0/1M + 500 * 2.0/1M = 0.001 + 0.001 = 0.002
    @test turn.cost ≈ 0.002
    remove_model_pricing!("cost-accum-model")
end

# ── Session updated_at ────────────────────────────────────────────────────────

@testset "Session updated_at initialised" begin
    s = Session()
    @test s.updated_at ≈ s.created_at
    @test s.updated_at > 0
end

# ── cleanup! — _resolve_cutoff ────────────────────────────────────────────────

@testset "_resolve_cutoff" begin
    # max_age converts to cutoff
    cutoff = NimbleAgents._resolve_cutoff(3600, nothing)
    @test cutoff ≈ time() - 3600 atol = 1.0

    # before passes through
    @test NimbleAgents._resolve_cutoff(nothing, 12345.0) == 12345.0

    # both or neither → error
    @test_throws ArgumentError NimbleAgents._resolve_cutoff(100, 100.0)
    @test_throws ArgumentError NimbleAgents._resolve_cutoff(nothing, nothing)
end

# ── cleanup! — InMemorySessionStore ──────────────────────────────────────────

@testset "cleanup! InMemorySessionStore" begin
    store = InMemorySessionStore()

    old = Session(app_name="App")
    old.updated_at = time() - 7200  # 2 hours ago
    store.sessions[old.id] = old

    recent = Session(app_name="App")
    recent.updated_at = time()
    store.sessions[recent.id] = recent

    removed = cleanup!(store; max_age=3600)
    @test removed == 1
    @test isnothing(load(store, old.id))
    @test !isnothing(load(store, recent.id))
end

# ── cleanup! — JSONSessionStore ──────────────────────────────────────────────

@testset "cleanup! JSONSessionStore" begin
    dir = mktempdir()
    store = JSONSessionStore(dir)

    old = Session(app_name="App")
    save!(store, old)
    # Backdate the updated_at in the JSON file
    path = joinpath(dir, old.id * ".json")
    data = JSON3.read(read(path, String), Dict{String,Any})
    data["updated_at"] = time() - 7200
    write(path, JSON3.write(data))

    recent = Session(app_name="App")
    save!(store, recent)

    removed = cleanup!(store; max_age=3600)
    @test removed == 1
    @test isnothing(load(store, old.id))
    @test !isnothing(load(store, recent.id))
end

# ── cleanup! — SQLiteSessionStore ────────────────────────────────────────────

@testset "cleanup! SQLiteSessionStore" begin
    dbpath = joinpath(mktempdir(), "test_ttl.db")
    store = SQLiteSessionStore(dbpath)

    old = Session(app_name="App")
    save!(store, old)
    # Backdate updated_at in the database
    DBInterface.execute(
        store.db, "UPDATE sessions SET updated_at = ? WHERE id = ?", (time() - 7200, old.id)
    )

    recent = Session(app_name="App")
    save!(store, recent)

    removed = cleanup!(store; max_age=3600)
    @test removed == 1
    @test isnothing(load(store, old.id))
    @test !isnothing(load(store, recent.id))

    # cleanup! with before= keyword
    save!(store, Session(app_name="App"))  # fresh session
    removed2 = cleanup!(store; before=time() - 86400)
    @test removed2 == 0  # nothing older than 1 day

    close!(store)
end
