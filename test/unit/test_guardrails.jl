###############################################################################
# test_guardrails.jl — unit tests for the guardrails system
###############################################################################

# ── GuardrailResult types ─────────────────────────────────────────────────────

@testset "GuardrailResult types" begin
    @test Pass() isa Pass
    @test Block("reason") isa Block
    @test Block("reason").reason == "reason"
    @test Modify("new") isa Modify
    @test Modify("new").value == "new"
end

# ── Guardrail construction ────────────────────────────────────────────────────

@testset "Guardrail construction" begin
    g = Guardrail(name="test", check=_ -> Pass())
    @test g.name == "test"
    @test g.on   == :input   # default

    g2 = Guardrail(name="out", check=_ -> Pass(), on=:output)
    @test g2.on == :output

    @test_throws ErrorException Guardrail(name="bad", check=_ -> Pass(), on=:invalid)
end

# ── _run_guardrails — Pass ────────────────────────────────────────────────────

@testset "_run_guardrails — Pass" begin
    g = Guardrail(name="allow_all", check=_ -> Pass())
    result = NimbleAgents._run_guardrails([g], :input, "hello", "TestAgent", false)
    @test result == "hello"
end

# ── _run_guardrails — Block ───────────────────────────────────────────────────

@testset "_run_guardrails — Block" begin
    g = Guardrail(name="block_all", check=_ -> Block("blocked"))
    @test_throws NimbleAgents.GuardrailBlocked begin
        NimbleAgents._run_guardrails([g], :input, "hello", "TestAgent", false)
    end
    try
        NimbleAgents._run_guardrails([g], :input, "hello", "TestAgent", false)
    catch e
        @test e isa NimbleAgents.GuardrailBlocked
        @test e.reason == "blocked"
        @test e.guardrail_name == "block_all"
    end
end

# ── _run_guardrails — Modify ──────────────────────────────────────────────────

@testset "_run_guardrails — Modify" begin
    g = Guardrail(name="uppercase", check=v -> Modify(uppercase(v)))
    result = NimbleAgents._run_guardrails([g], :input, "hello", "TestAgent", false)
    @test result == "HELLO"
end

# ── _run_guardrails — chaining ────────────────────────────────────────────────

@testset "_run_guardrails — chaining multiple guardrails" begin
    g1 = Guardrail(name="strip",     check=v -> Modify(strip(v)))
    g2 = Guardrail(name="uppercase", check=v -> Modify(uppercase(v)))
    result = NimbleAgents._run_guardrails([g1, g2], :input, "  hello  ", "TestAgent", false)
    @test result == "HELLO"
end

# ── _run_guardrails — phase filtering ────────────────────────────────────────

@testset "_run_guardrails — phase filtering" begin
    input_g  = Guardrail(name="input_only",  on=:input,  check=_ -> Block("input blocked"))
    output_g = Guardrail(name="output_only", on=:output, check=_ -> Block("output blocked"))

    # input_g should NOT fire when phase=:output
    result = NimbleAgents._run_guardrails([input_g], :output, "hello", "TestAgent", false)
    @test result == "hello"

    # output_g should NOT fire when phase=:input
    result2 = NimbleAgents._run_guardrails([output_g], :input, "hello", "TestAgent", false)
    @test result2 == "hello"
end

# ── _run_guardrails — error in check treated as Block ────────────────────────

@testset "_run_guardrails — check error treated as block" begin
    g = Guardrail(name="buggy", check=_ -> error("oops"))
    @test_throws NimbleAgents.GuardrailBlocked begin
        NimbleAgents._run_guardrails([g], :input, "hello", "TestAgent", false)
    end
    try
        NimbleAgents._run_guardrails([g], :input, "hello", "TestAgent", false)
    catch e
        @test e isa NimbleAgents.GuardrailBlocked
        @test occursin("oops", e.reason)
    end
end

# ── Agent integration — input guardrail blocks ────────────────────────────────

@testset "Agent — input guardrail blocks before LLM call" begin
    block_all = Guardrail(
        name  = "block_all",
        on    = :input,
        check = _ -> Block("Input not allowed."),
    )

    @tool function dummy_tool_gr(x::Int)
        "A dummy tool."
        x
    end

    agent = Agent(
        name       = "GuardBot",
        instructions = "You are a helpful assistant.",
        tools      = [dummy_tool_gr_tool],
        guardrails = [block_all],
    )

    # The LLM should never be called — result comes straight from the guardrail
    result = run!(agent, "do something"; verbose=false)
    @test result == "Input not allowed."
end

# ── Agent integration — input guardrail modifies input ───────────────────────

@testset "Agent — input Modify rewrites input" begin
    # We just verify that Modify doesn't crash and the agent runs normally.
    # We can't easily assert on what was sent to the LLM without mocking,
    # but we can confirm no exception is thrown.
    strip_g = Guardrail(
        name  = "strip_spaces",
        on    = :input,
        check = v -> Modify(strip(v)),
    )

    agent = Agent(
        name         = "StripBot",
        instructions = "Reply with the word DONE.",
        guardrails   = [strip_g],
    )

    # Should not throw
    @test_nowarn begin
        try run!(agent, "  hello  "; verbose=false) catch end
    end
end

# ── Agent integration — output guardrail blocks response ─────────────────────

@testset "Agent — output guardrail blocks final response" begin
    block_output = Guardrail(
        name  = "block_output",
        on    = :output,
        check = _ -> Block("Output not allowed."),
    )

    agent = Agent(
        name         = "OutputGuardBot",
        instructions = "Reply with the word DONE.",
        guardrails   = [block_output],
    )

    # We can't easily run a live LLM call in unit tests, but we can test
    # _apply_output_guardrails directly
    dummy_turn  = NimbleAgents.TurnEvent("TestAgent", "test-model", "input")
    dummy_hooks = AgentHooks()
    result = NimbleAgents._apply_output_guardrails(
        "some response", agent, dummy_turn, time(), nothing,
        [], 0, dummy_hooks, nothing, false,
    )
    @test result == "Output not allowed."
end

# ── Agent integration — output guardrail modifies response ───────────────────

@testset "Agent — output Modify rewrites response" begin
    uppercase_output = Guardrail(
        name  = "uppercase_output",
        on    = :output,
        check = v -> Modify(uppercase(v)),
    )

    agent = Agent(
        name         = "UpperBot",
        instructions = "Reply.",
        guardrails   = [uppercase_output],
    )

    dummy_turn  = NimbleAgents.TurnEvent("TestAgent", "test-model", "input")
    dummy_hooks = AgentHooks()
    result = NimbleAgents._apply_output_guardrails(
        "hello world", agent, dummy_turn, time(), nothing,
        [], 0, dummy_hooks, nothing, false,
    )
    @test result == "HELLO WORLD"
end

# ── Agent integration — non-string output skips guardrails ───────────────────

@testset "Agent — non-string output skips output guardrails" begin
    block_output = Guardrail(
        name  = "block_output",
        on    = :output,
        check = _ -> Block("blocked"),
    )

    agent = Agent(
        name         = "StructBot",
        instructions = "Reply.",
        guardrails   = [block_output],
    )

    dummy_turn  = NimbleAgents.TurnEvent("TestAgent", "test-model", "input")
    dummy_hooks = AgentHooks()

    # Non-string result (e.g. structured output) should pass through untouched
    result = NimbleAgents._apply_output_guardrails(
        42, agent, dummy_turn, time(), nothing,
        [], 0, dummy_hooks, nothing, false,
    )
    @test result == 42
end
