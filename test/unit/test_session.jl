import PromptingTools as PT

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
    push!(s.history, PT.UserMessage("hi"))
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
    conv = PT.AbstractMessage[
        PT.SystemMessage("You are helpful."),
        PT.UserMessage("turn 1"),
        PT.AIMessage("response 1"),
    ]
    NimbleAgents._save_history!(s3, conv, 2)  # 2 seeded
    @test length(s3) == 1
    @test s3.history[1] isa PT.AIMessage

    # system message is never saved
    NimbleAgents._save_history!(s3, conv, 0)  # treat all as new
    @test all(m -> !(m isa PT.SystemMessage), s3.history)

    # ── _accumulate_usage! adds token counts ─────────────────────────────
    turn2 = TurnEvent("TestAgent", "test-model", "test")
    mock_msg = PT.AIMessage(
        content="hi", usage=PT.TokenUsage(input_tokens=10, output_tokens=5)
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
    mock_msg = PT.AIMessage(
        content="ok", usage=PT.TokenUsage(input_tokens=1000, output_tokens=500)
    )
    NimbleAgents._accumulate_usage!(turn, mock_msg)

    # 1000 * 1.0/1M + 500 * 2.0/1M = 0.001 + 0.001 = 0.002
    @test turn.cost ≈ 0.002
    remove_model_pricing!("cost-accum-model")
end
