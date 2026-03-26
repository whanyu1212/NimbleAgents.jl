using .Mocking

@testset "Handoff & agent_as_tool" begin

    # ── helpers ───────────────────────────────────────────────────────────────
    # Minimal stub tool so agents have something to register
    @tool function echo_stub(msg::String)
        "Echo the message back."
        msg
    end

    # ── Handoff struct ────────────────────────────────────────────────────────
    target = Agent(name="Target", instructions="I am the target.")
    starter = Agent(name="Starter", instructions="I am the starter.")

    h = Handoff(target, "please handle this")
    @test h isa Handoff
    @test h.target === target
    @test h.message == "please handle this"
    @test h.history_filter.kind == :all  # default filter

    # 3-arg constructor
    h2 = Handoff(target, "msg", HandoffFilter(:none))
    @test h2.history_filter.kind == :none

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
    @test result.history_filter.kind == :all

    # With custom history_filter
    ht_filtered = handoff_tool(target; history_filter=HandoffFilter(:strip_tools))
    result_f = ht_filtered.callable("go")
    @test result_f.history_filter.kind == :strip_tools

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
    hooks_a = AgentHooks(on_complete=(ag, _) -> (fired[] = true))

    agent_a = Agent(
        name="AgentA",
        instructions="Instructions for A.",
        tools=[echo_stub_tool],
        hooks=hooks_a,
    )
    agent_b = Agent(
        name="AgentB",
        instructions="Instructions for B.",
        tools=Tool[],   # no tools
    )

    @test agent_a.name == "AgentA"
    @test agent_a.instructions == "Instructions for A."
    @test length(agent_a.tools) == 1
    @test agent_b.name == "AgentB"
    @test isempty(agent_b.tools)

    # Hooks are per-agent — agent_b's complete hook does not set fired[]
    @test !fired[]
end

# ──────────────────────────────────────────────────────────────────────────────
# HandoffFilter
# ──────────────────────────────────────────────────────────────────────────────

@testset "HandoffFilter" begin

    # ── constructors ─────────────────────────────────────────────────────────
    @testset "constructors" begin
        f1 = HandoffFilter()
        @test f1.kind == :all
        @test f1.n == 0
        @test isnothing(f1.func)

        f2 = HandoffFilter(:none)
        @test f2.kind == :none

        f3 = HandoffFilter(:last_n, 3)
        @test f3.kind == :last_n
        @test f3.n == 3

        fn = x -> x
        f4 = HandoffFilter(fn)
        @test f4.kind == :custom
        @test f4.func === fn
    end

    # ── _apply_handoff_filter ────────────────────────────────────────────────
    @testset "_apply_handoff_filter" begin
        # Build a sample history
        msgs = NimbleAgents.AbstractMessage[
            NimbleAgents.SystemMessage("system"),
            NimbleAgents.UserMessage("hello"),
            NimbleAgents.AIMessage(content="I'll call a tool"),
            NimbleAgents.UserMessage("thanks"),
            NimbleAgents.AIMessage(content="done"),
        ]

        # :all — pass through unchanged
        @test NimbleAgents._apply_handoff_filter(HandoffFilter(:all), msgs) === msgs

        # :none — empty
        @test isempty(NimbleAgents._apply_handoff_filter(HandoffFilter(:none), msgs))

        # :strip_tools — no tool messages in this set, so all pass
        stripped = NimbleAgents._apply_handoff_filter(HandoffFilter(:strip_tools), msgs)
        @test length(stripped) == length(msgs)

        # :strip_tools with actual tool messages
        tm = NimbleAgents.ToolMessage(
            content=nothing, raw="", tool_call_id="c1", name="foo", args=Dict{Symbol,Any}()
        )
        atr = NimbleAgents.AIToolRequest(; tool_calls=[tm], content="", tokens=(5, 5), elapsed=0.1)
        msgs_with_tools = NimbleAgents.AbstractMessage[
            NimbleAgents.UserMessage("hello"), atr, tm, NimbleAgents.AIMessage(content="done")
        ]
        stripped2 = NimbleAgents._apply_handoff_filter(
            HandoffFilter(:strip_tools), msgs_with_tools
        )
        @test length(stripped2) == 2
        @test stripped2[1] isa NimbleAgents.UserMessage
        @test stripped2[2] isa NimbleAgents.AIMessage

        # :last_n
        last2 = NimbleAgents._apply_handoff_filter(HandoffFilter(:last_n, 2), msgs)
        @test length(last2) == 2
        @test last2[1] isa NimbleAgents.UserMessage   # "thanks"
        @test last2[2] isa NimbleAgents.AIMessage     # "done"

        # :last_n with n >= length
        all_back = NimbleAgents._apply_handoff_filter(HandoffFilter(:last_n, 100), msgs)
        @test all_back === msgs

        # :last_n with n = 0
        empty_back = NimbleAgents._apply_handoff_filter(HandoffFilter(:last_n, 0), msgs)
        @test isempty(empty_back)

        # :custom function
        only_user = HandoffFilter(
            h -> NimbleAgents.AbstractMessage[m for m in h if m isa NimbleAgents.UserMessage]
        )
        user_msgs = NimbleAgents._apply_handoff_filter(only_user, msgs)
        @test length(user_msgs) == 2
        @test all(m -> m isa NimbleAgents.UserMessage, user_msgs)

        # unknown kind falls through to return history
        unknown = HandoffFilter(:unknown_kind, 0, nothing)
        @test NimbleAgents._apply_handoff_filter(unknown, msgs) === msgs
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# loop_pipeline!
# ──────────────────────────────────────────────────────────────────────────────

@testset "loop_pipeline!" begin
    _ai_msg_lp(text) = NimbleAgents.AIMessage(; content=text, tokens=(10, 10), elapsed=0.1)

    @testset "stops on stop_when" begin
        call_count = Ref(0)

        patch = @patch function NimbleAgents.aitools(conv; kwargs...)
            call_count[] += 1
            # Coder says code, Reviewer says APPROVED on 2nd round
            agent_name = get(Dict(kwargs), :model, "")
            last_user = ""
            for m in reverse(conv)
                if m isa NimbleAgents.UserMessage
                    last_user = m.content
                    break
                end
            end
            if occursin("APPROVED", last_user) || call_count[] >= 3
                push!(conv, _ai_msg_lp("APPROVED: looks good"))
            else
                push!(
                    conv,
                    _ai_msg_lp("Here is the code: fib(n) = n < 2 ? n : fib(n-1)+fib(n-2)"),
                )
            end
            conv
        end

        apply(patch) do
            coder = Agent(name="Coder", instructions="Write code.")
            reviewer = Agent(
                name="Reviewer", instructions="Review code. Say APPROVED if good."
            )

            result = loop_pipeline!(
                [coder, reviewer],
                "Write fibonacci";
                max_rounds=5,
                stop_when=(agent, result) -> occursin("APPROVED", string(result)),
                verbose=false,
            )
            @test occursin("APPROVED", string(result))
        end
    end

    @testset "respects max_rounds" begin
        round_count = Ref(0)

        patch = @patch function NimbleAgents.aitools(conv; kwargs...)
            round_count[] += 1
            push!(conv, _ai_msg_lp("iteration $(round_count[])"))
            conv
        end

        apply(patch) do
            a1 = Agent(name="A1", instructions="Agent 1.")
            a2 = Agent(name="A2", instructions="Agent 2.")

            result = loop_pipeline!(
                [a1, a2],
                "go";
                max_rounds=2,
                stop_when=(_, _) -> false,  # never stop
                verbose=false,
            )
            # 2 rounds × 2 agents = 4 calls
            @test round_count[] == 4
            @test result isa String
        end
    end

    @testset "empty agents errors" begin
        @test_throws ErrorException loop_pipeline!(Agent[], "go"; verbose=false)
    end

    @testset "with session" begin
        patch = @patch function NimbleAgents.aitools(conv; kwargs...)
            push!(conv, _ai_msg_lp("done"))
            conv
        end

        apply(patch) do
            session = Session()
            a1 = Agent(name="A1", instructions="Agent 1.")

            result = loop_pipeline!(
                [a1],
                "task";
                max_rounds=1,
                stop_when=(_, _) -> true,
                session=session,
                verbose=false,
            )
            @test result == "done"
            @test length(session.events) >= 1
        end
    end
end

@testset "run_pipeline!" begin
    _ai_msg_rp(text) = NimbleAgents.AIMessage(; content=text, tokens=(10, 10), elapsed=0.1)

    @testset "handoff history includes matching tool result" begin
        billing = Agent(
            name="BillingAgent",
            instructions="Handle billing requests.",
            model="gpt-5.4-nano-2026-03-17",
        )
        triage = Agent(
            name="TriageAgent",
            instructions="Route billing issues to BillingAgent.",
            tools=[handoff_tool(billing)],
            model="gpt-5.4-mini",
        )
        session = Session()
        saw_valid_history = Ref(false)

        patch = @patch function NimbleAgents.aitools(conv; kwargs...)
            model = get(Dict(kwargs), :model, "")

            if model == triage.model
                tc = NimbleAgents.ToolMessage(
                    content=nothing,
                    raw="",
                    tool_call_id="handoff_call_1",
                    name="handoff_to_BillingAgent",
                    args=Dict(:message => "Please help with billing."),
                )
                push!(
                    conv,
                    NimbleAgents.AIToolRequest(; tool_calls=[tc], content=nothing, tokens=(5, 5), elapsed=0.1),
                )
                return conv
            end

            if model == billing.model
                reqs = [m for m in conv if m isa NimbleAgents.AIToolRequest]
                replies = Set(m.tool_call_id for m in conv if m isa NimbleAgents.ToolMessage)
                for req in reqs
                    ids = Set(tc.tool_call_id for tc in req.tool_calls)
                    ids ⊆ replies || error("missing tool response in handoff history")
                end
                saw_valid_history[] = true
                push!(conv, _ai_msg_rp("Handled by billing"))
                return conv
            end

            error("Unexpected model in mocked aitools: $(model)")
        end

        apply(patch) do
            result = run_pipeline!(
                triage, "I was charged twice this month."; session=session, verbose=false
            )
            @test result == "Handled by billing"
            @test saw_valid_history[]
            @test any(m -> m isa NimbleAgents.AIToolRequest, session.history)
            @test any(
                m -> m isa NimbleAgents.ToolMessage && m.tool_call_id == "handoff_call_1",
                session.history,
            )
        end
    end
end
