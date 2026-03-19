@testset "Handoff & agent_as_tool" begin

    # ── helpers ───────────────────────────────────────────────────────────────
    # Minimal stub tool so agents have something to register
    @tool function echo_stub(msg::String)
        "Echo the message back."
        msg
    end

    # ── Handoff struct ────────────────────────────────────────────────────────
    target  = Agent(name="Target", instructions="I am the target.")
    starter = Agent(name="Starter", instructions="I am the starter.")

    h = Handoff(target, "please handle this")
    @test h isa Handoff
    @test h.target === target
    @test h.message == "please handle this"

    # ── handoff_tool ─────────────────────────────────────────────────────────
    ht = handoff_tool(target)
    @test ht isa Tool
    @test ht.name == "handoff_to_Target"
    @test occursin("Target", ht.description)

    # Calling the tool's callable returns a Handoff
    result = ht.callable("forward this")
    @test result isa Handoff
    @test result.target === target
    @test result.message == "forward this"

    # Custom name / description
    ht2 = handoff_tool(target; name="transfer", description="Custom transfer tool.")
    @test ht2.name == "transfer"
    @test ht2.description == "Custom transfer tool."

    # ── handoff_tool schema ───────────────────────────────────────────────────
    params = ht.parameters
    @test params["type"] == "object"
    @test haskey(params["properties"], "message")
    @test params["required"] == ["message"]

    # ── agent_as_tool ─────────────────────────────────────────────────────────
    sub_agent = Agent(name="Sub", instructions="I am a subagent.", tools=[echo_stub_tool])
    at = agent_as_tool(sub_agent)
    @test at isa Tool
    @test at.name == "Sub"
    @test occursin("Sub", at.description)

    # Custom name
    at2 = agent_as_tool(sub_agent; name="sub_runner", description="Run the sub agent.")
    @test at2.name == "sub_runner"

    # Schema has a `task` parameter
    @test haskey(at.parameters["properties"], "task")
    @test at.parameters["required"] == ["task"]

    # ── Each agent has independent tools / hooks / instructions ───────────────
    fired = Ref(false)
    hooks_a = AgentHooks(on_complete = (ag, _) -> (fired[] = true))

    agent_a = Agent(
        name         = "AgentA",
        instructions = "Instructions for A.",
        tools        = [echo_stub_tool],
        hooks        = hooks_a,
    )
    agent_b = Agent(
        name         = "AgentB",
        instructions = "Instructions for B.",
        tools        = Tool[],   # no tools
    )

    @test agent_a.name         == "AgentA"
    @test agent_a.instructions == "Instructions for A."
    @test length(agent_a.tools) == 1
    @test agent_b.name         == "AgentB"
    @test isempty(agent_b.tools)

    # Hooks are per-agent — agent_b's complete hook does not set fired[]
    @test !fired[]
end
