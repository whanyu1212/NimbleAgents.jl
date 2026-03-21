###############################################################################
# test_parallel_tools.jl — unit tests for parallel tool execution in run!
#
# Uses Mocking.jl to stub PT.aitools, same strategy as test_run.jl.
# Tools defined at module scope (runtests.jl) to avoid closure mangling.
###############################################################################

import PromptingTools as PT

# ── Helpers ───────────────────────────────────────────────────────────────────

_ai_msg_p(text) = PT.AIMessage(; content=text, tokens=(10, 10), elapsed=0.1)

function _multi_tool_request(calls::Vector{<:Pair{String}})
    tms = [PT.ToolMessage(
        content      = nothing,
        raw          = "",
        tool_call_id = "call_$(name)_$(i)",
        name         = name,
        args         = Dict{Symbol,Any}(Symbol(k) => v for (k,v) in args),
    ) for (i, (name, args)) in enumerate(calls)]
    PT.AIToolRequest(; tool_calls=tms, content="", tokens=(5,5), elapsed=0.1)
end

# Tool fixtures (par_add_tool, par_single_tool, etc.) are defined in runtests.jl
# at module scope to avoid closure mangling of arg names.

# ── Multiple tools execute in parallel ────────────────────────────────────────

@testset "run! — multiple tools execute in parallel" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _multi_tool_request([
                "par_add" => Dict("x" => 1, "y" => 2),
                "par_add" => Dict("x" => 10, "y" => 20),
            ]))
        else
            push!(conv, _ai_msg_p("Results: 3 and 30"))
        end
        conv
    end

    apply(patch) do
        agent   = Agent(name="Bot", instructions="test", tools=[par_add_tool])
        session = Session(app_name="App", user_id="u")

        t0     = time()
        result = run!(agent, "add both"; session, verbose=false)
        elapsed = time() - t0

        @test result == "Results: 3 and 30"
        # Both tool calls should be recorded
        @test length(session.events) == 1
        @test length(session.events[1].tool_calls) == 2
        @test session.events[1].tool_calls[1].name == "par_add"
        @test session.events[1].tool_calls[2].name == "par_add"
    end
end

# ── Single tool stays sequential ──────────────────────────────────────────────

@testset "run! — single tool call stays sequential" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _multi_tool_request([
                "par_single" => Dict("x" => 5),
            ]))
        else
            push!(conv, _ai_msg_p("result: 10"))
        end
        conv
    end

    apply(patch) do
        agent  = Agent(name="Bot", instructions="test", tools=[par_single_tool])
        result = run!(agent, "double 5"; verbose=false)
        @test result == "result: 10"
    end
end

# ── return_direct forces sequential ──────────────────────────────────────────

@testset "run! — return_direct tool forces sequential execution" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        push!(conv, _multi_tool_request([
            "rd_normal" => Dict("x" => 1),
            "rd_direct" => Dict("x" => 2),
        ]))
        conv
    end

    # Uses rd_normal_tool and rd_direct_tool from runtests.jl fixtures
    apply(patch) do
        agent  = Agent(name="Bot", instructions="test",
                       tools=[rd_normal_tool, rd_direct_tool])
        result = run!(agent, "go"; verbose=false)

        # return_direct should short-circuit — result is from rd_direct
        @test result == 200
        @test call_count[] == 1
    end
end

# ── sub_agents present forces sequential ─────────────────────────────────────

@testset "run! — sub_agents present forces sequential execution" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _multi_tool_request([
                "par_seq_a" => Dict("x" => 1),
                "par_seq_b" => Dict("x" => 2),
            ]))
        else
            push!(conv, _ai_msg_p("done"))
        end
        conv
    end

    apply(patch) do
        sub = Agent(name="Sub", instructions="sub agent")
        agent = Agent(name="Bot", instructions="test",
                      tools=[par_seq_a_tool, par_seq_b_tool], sub_agents=[sub])

        session = Session(app_name="App", user_id="u")
        result  = run!(agent, "go"; session, verbose=false)

        @test result == "done"
        # Both tools executed sequentially
        @test length(session.events[1].tool_calls) == 2
    end
end

# ── Parallel tool error is caught ─────────────────────────────────────────────

@testset "run! — parallel tool error is caught" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _multi_tool_request([
                "par_good" => Dict("x" => 1),
                "par_bad"  => Dict("x" => 2),
            ]))
        else
            push!(conv, _ai_msg_p("handled"))
        end
        conv
    end

    apply(patch) do
        agent   = Agent(name="Bot", instructions="test",
                        tools=[par_good_tool, par_bad_tool])
        session = Session(app_name="App", user_id="u")
        result  = run!(agent, "go"; session, verbose=false)

        @test result == "handled"
        # Error should be recorded in the tool event
        turn = session.events[1]
        @test length(turn.tool_calls) == 2
        @test isnothing(turn.tool_calls[1].error)  # par_good succeeded
        @test !isnothing(turn.tool_calls[2].error)  # par_bad failed
        @test occursin("boom", turn.tool_calls[2].error)
    end
end

# ── Tool hooks fire for parallel execution ────────────────────────────────────

@testset "run! — tool hooks fire during parallel execution" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _multi_tool_request([
                "par_hook_a" => Dict("x" => 1),
                "par_hook_b" => Dict("x" => 2),
            ]))
        else
            push!(conv, _ai_msg_p("done"))
        end
        conv
    end

    apply(patch) do
        log = String[]
        hooks = AgentHooks(
            on_tool_call   = (ag, name, args) -> push!(log, "call:$name"),
            on_tool_result = (ag, name, res)  -> push!(log, "result:$name"),
        )
        agent = Agent(name="Bot", instructions="test",
                      tools=[par_hook_a_tool, par_hook_b_tool], hooks=hooks)

        run!(agent, "go"; verbose=false)

        # on_tool_call fires for both before execution starts
        @test "call:par_hook_a" in log
        @test "call:par_hook_b" in log
        # on_tool_result fires for both after results collected
        @test "result:par_hook_a" in log
        @test "result:par_hook_b" in log
    end
end
