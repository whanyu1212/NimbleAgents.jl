###############################################################################
# test_tracer.jl — unit tests for the tracer module
###############################################################################

# ── helpers ───────────────────────────────────────────────────────────────────

function _make_turn(; agent="Bot", model="test-model", input="hi", output="hello",
                     tools=ToolEvent[], llm_calls=1,
                     input_tokens=10, output_tokens=5, cost=0.0, elapsed=1.0)
    t = TurnEvent(agent, model, input)
    t.output        = output
    t.tool_calls    = tools
    t.llm_calls     = llm_calls
    t.input_tokens  = input_tokens
    t.output_tokens = output_tokens
    t.cost          = cost
    t.elapsed       = elapsed
    t
end

function _make_tool_event(; name="add", args=Dict{Symbol,Any}(:x=>1,:y=>2),
                            result=3, error=nothing)
    ToolEvent(name, args, result, error, time())
end

# ── Trace construction ────────────────────────────────────────────────────────

@testset "Trace — empty" begin
    t = Trace(TurnEvent[])
    @test t.total_tokens      == 0
    @test t.total_cost        == 0.0
    @test t.total_llm_calls   == 0
    @test t.total_tool_calls  == 0
    @test t.duration          == 0.0
    @test isempty(t.agents)
    @test isempty(t.turns)
end

@testset "Trace — single turn" begin
    te = _make_tool_event()
    turn = _make_turn(input_tokens=100, output_tokens=40, cost=0.005, elapsed=2.5,
                      tools=[te], llm_calls=2)
    trace = Trace([turn])

    @test trace.total_input_tokens  == 100
    @test trace.total_output_tokens == 40
    @test trace.total_tokens        == 140
    @test trace.total_cost          ≈ 0.005
    @test trace.total_llm_calls     == 2
    @test trace.total_tool_calls    == 1
    @test trace.duration            ≈ 2.5
    @test trace.agents              == ["Bot"]
end

@testset "Trace — multiple turns, multiple agents" begin
    t1 = _make_turn(agent="AgentA", input_tokens=50, output_tokens=20, cost=0.001, elapsed=1.0,
                    tools=[_make_tool_event()], llm_calls=1)
    t2 = _make_turn(agent="AgentB", input_tokens=80, output_tokens=30, cost=0.002, elapsed=2.0,
                    tools=[_make_tool_event(), _make_tool_event()], llm_calls=2)
    trace = Trace([t1, t2])

    @test trace.total_input_tokens  == 130
    @test trace.total_output_tokens == 50
    @test trace.total_tokens        == 180
    @test trace.total_cost          ≈ 0.003
    @test trace.total_llm_calls     == 3
    @test trace.total_tool_calls    == 3
    @test trace.duration            ≈ 3.0
    @test trace.agents              == ["AgentA", "AgentB"]
end

@testset "Trace — deduplicates agent names" begin
    t1 = _make_turn(agent="Bot")
    t2 = _make_turn(agent="Bot")
    trace = Trace([t1, t2])
    @test trace.agents == ["Bot"]
end

# ── Trace from Session ────────────────────────────────────────────────────────

@testset "Trace — from Session" begin
    session = Session(app_name="Test", user_id="u")
    turn = _make_turn(input_tokens=30, output_tokens=10)
    push!(session.events, turn)

    trace = Trace(session)
    @test length(trace.turns)       == 1
    @test trace.total_tokens        == 40
end

# ── print_trace ───────────────────────────────────────────────────────────────

@testset "print_trace — runs without error" begin
    te = _make_tool_event()
    turn = _make_turn(tools=[te])
    trace = Trace([turn])

    buf = IOBuffer()
    @test_nowarn print_trace(trace; io=buf)
    output = String(take!(buf))

    @test occursin("Turn 1", output)
    @test occursin("Bot", output)
    @test occursin("add", output)
end

@testset "print_trace — truncates long output" begin
    turn = _make_turn(output="x" ^ 200)
    trace = Trace([turn])
    buf = IOBuffer()
    print_trace(trace; io=buf)
    output = String(take!(buf))
    @test occursin("…", output)
end

@testset "print_trace — shows tool errors" begin
    te = ToolEvent("broken", Dict{Symbol,Any}(), nothing, "something went wrong", time())
    turn = _make_turn(tools=[te])
    trace = Trace([turn])
    buf = IOBuffer()
    print_trace(trace; io=buf)
    output = String(take!(buf))
    @test occursin("ERROR", output)
    @test occursin("something went wrong", output)
end

# ── save_trace / load_trace ───────────────────────────────────────────────────

@testset "save_trace and load_trace round-trip" begin
    te = _make_tool_event(name="multiply", args=Dict{Symbol,Any}(:x=>3,:y=>4), result=12)
    turn = _make_turn(agent="MathBot", model="gpt-4o-mini", input="3*4", output="12",
                      tools=[te], input_tokens=20, output_tokens=8, cost=0.0018)
    trace = Trace([turn])

    path = tempname() * ".json"
    save_trace(trace, path)
    @test isfile(path)

    loaded = load_trace(path)
    @test loaded["total_tokens"]     == 28
    @test loaded["total_cost"]       ≈ 0.0018
    @test loaded["total_tool_calls"] == 1
    @test loaded["agents"]           == ["MathBot"]
    @test length(loaded["turns"])    == 1

    turn_data = loaded["turns"][1]
    @test turn_data["input"]  == "3*4"
    @test turn_data["output"] == "12"
    @test turn_data["model"]  == "gpt-4o-mini"
    @test turn_data["cost"]   ≈ 0.0018
    @test length(turn_data["tool_calls"]) == 1
    @test turn_data["tool_calls"][1]["name"] == "multiply"
end

@testset "load_trace — error on missing file" begin
    @test_throws ErrorException load_trace("/nonexistent/trace.json")
end

# ── print_trace cost display ────────────────────────────────────────────────

@testset "print_trace — shows cost when > 0" begin
    turn = _make_turn(cost=0.0042)
    trace = Trace([turn])
    buf = IOBuffer()
    print_trace(trace; io=buf)
    output = String(take!(buf))
    @test occursin("\$0.0042", output)
end

@testset "print_trace — hides cost when 0" begin
    turn = _make_turn(cost=0.0)
    trace = Trace([turn])
    buf = IOBuffer()
    print_trace(trace; io=buf)
    output = String(take!(buf))
    @test !occursin("Cost", output)
end

# ── Cost tracking ────────────────────────────────────────────────────────────

@testset "Trace — total_cost sums per-turn costs" begin
    t1 = _make_turn(cost=0.001)
    t2 = _make_turn(cost=0.003)
    t3 = _make_turn(cost=0.0)
    trace = Trace([t1, t2, t3])
    @test trace.total_cost ≈ 0.004
end
