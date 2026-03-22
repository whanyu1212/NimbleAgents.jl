###############################################################################
# test_eval.jl — unit tests for the eval harness
###############################################################################

import PromptingTools as PT

# Reuses _make_turn and _make_tool_event helpers from test_tracer.jl (already
# in scope via timed_include ordering in runtests.jl).

# ── Helpers ──────────────────────────────────────────────────────────────────

_ai_msg_eval(text) = PT.AIMessage(; content=text, tokens=(10, 10), elapsed=0.1)

# ── EvalCase construction ────────────────────────────────────────────────────

@testset "EvalCase — defaults" begin
    c = EvalCase(input="hello")
    @test c.input == "hello"
    @test isnothing(c.expected)
    @test isnothing(c.expected_tools)
    @test isnothing(c.reference)
    @test c.tags == String[]
end

@testset "EvalCase — full construction" begin
    c = EvalCase(
        input="hi",
        expected="bye",
        expected_tools=["add", "mul"],
        reference=Dict{String,Any}("key" => 1),
        tags=["math"],
    )
    @test c.input == "hi"
    @test c.expected == "bye"
    @test c.expected_tools == ["add", "mul"]
    @test c.reference["key"] == 1
    @test c.tags == ["math"]
end

# ── EvalResult construction ──────────────────────────────────────────────────

@testset "EvalResult — construction" begin
    c = EvalCase(input="test")
    r = EvalResult(c, "output", nothing, Dict("m" => 1.0), true, nothing, 0.5)
    @test r.case === c
    @test r.output == "output"
    @test r.passed == true
    @test r.elapsed == 0.5
    @test isnothing(r.error)
end

# ── EvalReport aggregation ───────────────────────────────────────────────────

@testset "EvalReport — empty" begin
    report = EvalReport(EvalResult[])
    @test report.pass_rate == 0.0
    @test isempty(report.mean_scores)
    @test report.total_cost == 0.0
    @test report.total_duration == 0.0
end

@testset "EvalReport — aggregation" begin
    c1 = EvalCase(input="a")
    c2 = EvalCase(input="b")

    trace1 = Trace([_make_turn(cost=0.01)])
    trace2 = Trace([_make_turn(cost=0.02)])

    r1 = EvalResult(
        c1,
        "out1",
        trace1,
        Dict("exact_match" => 1.0, "fuzzy_match" => 0.8),
        true,
        nothing,
        1.0,
    )
    r2 = EvalResult(
        c2,
        "out2",
        trace2,
        Dict("exact_match" => 0.0, "fuzzy_match" => 0.6),
        false,
        nothing,
        2.0,
    )

    report = EvalReport([r1, r2])
    @test report.pass_rate == 0.5
    @test report.mean_scores["exact_match"] ≈ 0.5
    @test report.mean_scores["fuzzy_match"] ≈ 0.7
    @test report.total_cost ≈ 0.03
    @test report.total_duration ≈ 3.0
end

@testset "EvalReport — all pass" begin
    c = EvalCase(input="x")
    trace = Trace([_make_turn(cost=0.0)])
    r = EvalResult(c, "y", trace, Dict("m" => 1.0), true, nothing, 0.1)
    report = EvalReport([r])
    @test report.pass_rate == 1.0
end

@testset "EvalReport — error case with nil trace" begin
    c = EvalCase(input="x")
    r = EvalResult(c, nothing, nothing, Dict("m" => 0.0), false, "boom", 0.1)
    report = EvalReport([r])
    @test report.total_cost == 0.0
    @test report.pass_rate == 0.0
end

# ── _edit_distance ───────────────────────────────────────────────────────────

@testset "_edit_distance" begin
    @test NimbleAgents._edit_distance("", "") == 0
    @test NimbleAgents._edit_distance("abc", "") == 3
    @test NimbleAgents._edit_distance("", "xyz") == 3
    @test NimbleAgents._edit_distance("abc", "abc") == 0
    @test NimbleAgents._edit_distance("kitten", "sitting") == 3
    @test NimbleAgents._edit_distance("saturday", "sunday") == 3
    @test NimbleAgents._edit_distance("a", "b") == 1
end

# ── _metric_name ─────────────────────────────────────────────────────────────

@testset "_metric_name" begin
    @test NimbleAgents._metric_name(exact_match) == "exact_match"
    @test NimbleAgents._metric_name(fuzzy_match) == "fuzzy_match"

    nm = NimbleAgents.NamedMetric("my_metric", (c, o, t) -> 1.0)
    @test NimbleAgents._metric_name(nm) == "my_metric"
end

# ── exact_match ──────────────────────────────────────────────────────────────

@testset "exact_match" begin
    c = EvalCase(input="x", expected="hello")
    @test exact_match(c, "hello", nothing) == 1.0
    @test exact_match(c, "Hello", nothing) == 0.0
    @test exact_match(c, "hello!", nothing) == 0.0

    c_nil = EvalCase(input="x")
    @test exact_match(c_nil, "anything", nothing) == 1.0
end

# ── fuzzy_match ──────────────────────────────────────────────────────────────

@testset "fuzzy_match" begin
    c = EvalCase(input="x", expected="hello")
    @test fuzzy_match(c, "hello", nothing) == 1.0
    @test fuzzy_match(c, "HELLO", nothing) == 1.0
    @test fuzzy_match(c, "say hello world", nothing) == 1.0
    @test fuzzy_match(c, "xyz", nothing) < 1.0

    c_nil = EvalCase(input="x")
    @test fuzzy_match(c_nil, "anything", nothing) == 1.0

    c_empty = EvalCase(input="x", expected="")
    @test fuzzy_match(c_empty, "", nothing) == 1.0
end

# ── tool_trajectory ──────────────────────────────────────────────────────────

@testset "tool_trajectory" begin
    c = EvalCase(input="x", expected_tools=["add", "mul"])

    # Matching trajectory
    te1 = _make_tool_event(name="add")
    te2 = _make_tool_event(name="mul")
    trace = Trace([_make_turn(tools=[te1, te2])])
    @test tool_trajectory(c, "out", trace) == 1.0

    # Wrong order
    trace_rev = Trace([_make_turn(tools=[te2, te1])])
    @test tool_trajectory(c, "out", trace_rev) == 0.0

    # Missing tool
    trace_short = Trace([_make_turn(tools=[te1])])
    @test tool_trajectory(c, "out", trace_short) == 0.0

    # No expected_tools → pass
    c_nil = EvalCase(input="x")
    @test tool_trajectory(c_nil, "out", trace) == 1.0

    # Nil trace
    @test tool_trajectory(c, "out", nothing) == 0.0
end

# ── tool_coverage ────────────────────────────────────────────────────────────

@testset "tool_coverage" begin
    c = EvalCase(input="x", expected_tools=["add", "mul", "sub"])

    te1 = _make_tool_event(name="add")
    te2 = _make_tool_event(name="mul")
    trace = Trace([_make_turn(tools=[te1, te2])])

    @test tool_coverage(c, "out", trace) ≈ 2/3

    # All covered
    te3 = _make_tool_event(name="sub")
    trace_full = Trace([_make_turn(tools=[te1, te2, te3])])
    @test tool_coverage(c, "out", trace_full) == 1.0

    # No expected_tools → 1.0
    c_nil = EvalCase(input="x")
    @test tool_coverage(c_nil, "out", trace) == 1.0

    # Nil trace
    @test tool_coverage(c, "out", nothing) == 0.0

    # Empty expected_tools
    c_empty = EvalCase(input="x", expected_tools=String[])
    @test tool_coverage(c_empty, "out", trace) == 1.0
end

# ── cost_budget / latency_budget ─────────────────────────────────────────────

@testset "cost_budget" begin
    metric = cost_budget(0.05)
    @test metric isa NimbleAgents.NamedMetric
    @test NimbleAgents._metric_name(metric) == "cost_budget(0.05)"

    c = EvalCase(input="x")
    trace_cheap = Trace([_make_turn(cost=0.01)])
    trace_expensive = Trace([_make_turn(cost=0.10)])

    @test metric(c, "out", trace_cheap) == 1.0
    @test metric(c, "out", trace_expensive) == 0.0
    @test metric(c, "out", nothing) == 0.0
end

@testset "latency_budget" begin
    metric = latency_budget(5.0)
    @test NimbleAgents._metric_name(metric) == "latency_budget(5.0)"

    c = EvalCase(input="x")
    trace_fast = Trace([_make_turn(elapsed=2.0)])
    trace_slow = Trace([_make_turn(elapsed=10.0)])

    @test metric(c, "out", trace_fast) == 1.0
    @test metric(c, "out", trace_slow) == 0.0
    @test metric(c, "out", nothing) == 0.0
end

# ── NamedMetric callable ─────────────────────────────────────────────────────

@testset "NamedMetric — callable" begin
    nm = NimbleAgents.NamedMetric("always_one", (c, o, t) -> 1.0)
    c = EvalCase(input="x")
    @test nm(c, "out", nothing) == 1.0
end

# ── run_eval (mocked) ────────────────────────────────────────────────────────

@testset "run_eval — basic pass" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg_eval("4"))
        conv
    end

    apply(patch) do
        agent = Agent(name="Bot", instructions="Be helpful.")
        cases = [EvalCase(input="2+2?", expected="4")]
        report = run_eval(agent, cases; metrics=[exact_match], verbose=false)

        @test length(report.results) == 1
        @test report.results[1].passed == true
        @test report.results[1].scores["exact_match"] == 1.0
        @test report.pass_rate == 1.0
    end
end

@testset "run_eval — basic fail" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg_eval("5"))
        conv
    end

    apply(patch) do
        agent = Agent(name="Bot", instructions="Be helpful.")
        cases = [EvalCase(input="2+2?", expected="4")]
        report = run_eval(agent, cases; metrics=[exact_match], verbose=false)

        @test report.results[1].passed == false
        @test report.results[1].scores["exact_match"] == 0.0
        @test report.pass_rate == 0.0
    end
end

@testset "run_eval — multiple cases" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        # First call returns "4", second returns "wrong"
        text = call_count[] == 1 ? "4" : "wrong"
        push!(conv, _ai_msg_eval(text))
        conv
    end

    apply(patch) do
        agent = Agent(name="Bot", instructions="Be helpful.")
        cases = [EvalCase(input="2+2?", expected="4"), EvalCase(input="3+3?", expected="6")]
        report = run_eval(agent, cases; metrics=[exact_match], verbose=false)

        @test length(report.results) == 2
        @test report.results[1].passed == true
        @test report.results[2].passed == false
        @test report.pass_rate == 0.5
    end
end

@testset "run_eval — error handling" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        error("LLM exploded")
    end

    apply(patch) do
        agent = Agent(name="Bot", instructions="Be helpful.")
        cases = [EvalCase(input="boom", expected="4")]
        report = run_eval(agent, cases; metrics=[exact_match], verbose=false)

        @test length(report.results) == 1
        r = report.results[1]
        @test !isnothing(r.error)
        @test r.passed == false
        @test r.scores["exact_match"] == 0.0
        @test report.pass_rate == 0.0
    end
end

@testset "run_eval — pass_threshold < 1.0" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg_eval("close match"))
        conv
    end

    apply(patch) do
        agent = Agent(name="Bot", instructions="Be helpful.")
        cases = [EvalCase(input="x", expected="close")]
        report = run_eval(
            agent, cases; metrics=[fuzzy_match], verbose=false, pass_threshold=0.5
        )

        # "close" is a substring of "close match" → fuzzy_match = 1.0
        @test report.results[1].passed == true
    end
end

@testset "run_eval — tool trajectory with mocked tool calls" begin
    # Mock aitools to request a tool call, then return a final message
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            # First call: LLM wants to call "add" tool
            tm = PT.ToolMessage(
                content=nothing,
                raw="",
                tool_call_id="call_ev_add",
                name="ev_add",
                args=Dict{Symbol,Any}(:x => 2, :y => 2),
            )
            push!(
                conv,
                PT.AIToolRequest(; tool_calls=[tm], content="", tokens=(5, 5), elapsed=0.1),
            )
        else
            # Second call: final text
            push!(conv, _ai_msg_eval("4"))
        end
        conv
    end

    apply(patch) do
        agent = Agent(name="Bot", instructions="Be helpful.", tools=[ev_add_tool])
        cases = [EvalCase(input="2+2?", expected="4", expected_tools=["ev_add"])]
        report = run_eval(
            agent, cases; metrics=[exact_match, tool_trajectory], verbose=false
        )

        @test report.results[1].scores["exact_match"] == 1.0
        @test report.results[1].scores["tool_trajectory"] == 1.0
        @test report.results[1].passed == true
    end
end

# ── print_eval ───────────────────────────────────────────────────────────────

@testset "print_eval — PASS/FAIL/ERR display" begin
    c1 = EvalCase(input="good")
    c2 = EvalCase(input="bad")
    c3 = EvalCase(input="err")

    r1 = EvalResult(c1, "out", nothing, Dict("m" => 1.0), true, nothing, 0.1)
    r2 = EvalResult(c2, "out", nothing, Dict("m" => 0.0), false, nothing, 0.1)
    r3 = EvalResult(c3, nothing, nothing, Dict("m" => 0.0), false, "boom", 0.1)

    report = EvalReport([r1, r2, r3])
    buf = IOBuffer()
    print_eval(report; io=buf)
    output = String(take!(buf))

    @test occursin("PASS", output)
    @test occursin("FAIL", output)
    @test occursin("ERR", output)
    @test occursin("Case 1", output)
    @test occursin("Case 2", output)
    @test occursin("Case 3", output)
    @test occursin("33.3%", output)   # 1/3 pass rate
end

@testset "print_eval — empty report" begin
    report = EvalReport(EvalResult[])
    buf = IOBuffer()
    @test_nowarn print_eval(report; io=buf)
    output = String(take!(buf))
    @test occursin("Cases      : 0", output)
end

@testset "print_eval — shows cost" begin
    c = EvalCase(input="x")
    trace = Trace([_make_turn(cost=0.05)])
    r = EvalResult(c, "out", trace, Dict("m" => 1.0), true, nothing, 1.0)
    report = EvalReport([r])
    buf = IOBuffer()
    print_eval(report; io=buf)
    output = String(take!(buf))
    @test occursin("\$0.05", output)
end

# ── save_eval / load_eval ────────────────────────────────────────────────────

@testset "save_eval / load_eval round-trip" begin
    c = EvalCase(input="2+2?", expected="4", expected_tools=["add"], tags=["math"])
    trace = Trace([_make_turn(cost=0.01, input_tokens=100, output_tokens=50)])
    r = EvalResult(c, "4", trace, Dict("exact_match" => 1.0), true, nothing, 0.5)
    report = EvalReport([r])

    path = tempname() * ".json"
    save_eval(report, path)
    @test isfile(path)

    loaded = load_eval(path)
    @test loaded["pass_rate"] == 1.0
    @test loaded["total_cost"] ≈ 0.01
    @test length(loaded["results"]) == 1

    result_data = loaded["results"][1]
    @test result_data["input"] == "2+2?"
    @test result_data["expected"] == "4"
    @test result_data["passed"] == true
    @test result_data["scores"]["exact_match"] == 1.0
    @test result_data["trace"]["total_tokens"] == 150
end

@testset "load_eval — error on missing file" begin
    @test_throws ErrorException load_eval("/nonexistent/eval.json")
end

@testset "save_eval / load_eval — error case" begin
    c = EvalCase(input="boom")
    r = EvalResult(c, nothing, nothing, Dict("m" => 0.0), false, "kaboom", 0.1)
    report = EvalReport([r])

    path = tempname() * ".json"
    save_eval(report, path)
    loaded = load_eval(path)

    @test loaded["results"][1]["error"] == "kaboom"
    @test isnothing(loaded["results"][1]["trace"])
end
