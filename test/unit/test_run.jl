###############################################################################
# test_run.jl — unit tests for run! using Mocking.jl to stub PT.aitools
#
# Strategy: @patch PT.aitools to return canned PT.AbstractMessage vectors
# so no real LLM call is made. Each test controls exactly what the fake LLM
# "returns" to exercise specific code paths in run!.
#
# Requires: Mocking.activate() called before `using NimbleAgents` (in runtests.jl)
###############################################################################

import PromptingTools as PT

# ── Helpers ───────────────────────────────────────────────────────────────────

# Build a minimal AIMessage (plain text response, no tool calls)
_ai_msg(text) = PT.AIMessage(; content=text, tokens=(10, 10), elapsed=0.1)

# Build a fake tool request: LLM wants to call `tool_name` with `args`
function _tool_request(tool_name::String, args::Dict; content="")
    # PT uses ToolMessage inside AIToolRequest.tool_calls
    tm = PT.ToolMessage(
        content      = nothing,
        raw          = "",
        tool_call_id = "call_$(tool_name)",
        name         = tool_name,
        args         = Dict{Symbol,Any}(Symbol(k) => v for (k,v) in args),
    )
    PT.AIToolRequest(; tool_calls=[tm], content=content, tokens=(5,5), elapsed=0.1)
end

# ── Basic text response ───────────────────────────────────────────────────────

@testset "run! — plain text response" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("Hello back!"))
        conv
    end

    apply(patch) do
        agent  = Agent(name="Bot", instructions="Be helpful.")
        result = run!(agent, "Hello"; verbose=false)
        @test result == "Hello back!"
        @test result isa String
    end
end

# ── Dynamic instructions ─────────────────────────────────────────────────────

@testset "run! — dynamic instructions resolved from function" begin
    captured_system = Ref("")

    patch = @patch function PT.aitools(conv; kwargs...)
        # Capture the system prompt that was passed to the LLM
        captured_system[] = conv[1].content
        push!(conv, _ai_msg("Got it!"))
        conv
    end

    apply(patch) do
        dyn = (session, agent) -> "You are helping $(session.user_id). Agent: $(agent.name)."
        agent   = Agent(name="DynBot", instructions=dyn)
        session = Session(app_name="App", user_id="alice")

        result = run!(agent, "Hi"; session, verbose=false)
        @test result == "Got it!"
        @test captured_system[] == "You are helping alice. Agent: DynBot."
    end
end

@testset "run! — dynamic instructions with nothing session" begin
    captured_system = Ref("")

    patch = @patch function PT.aitools(conv; kwargs...)
        captured_system[] = conv[1].content
        push!(conv, _ai_msg("OK"))
        conv
    end

    apply(patch) do
        dyn   = (session, agent) -> "No session: $(isnothing(session))"
        agent = Agent(name="DynBot", instructions=dyn)

        result = run!(agent, "Hi"; verbose=false)
        @test result == "OK"
        @test captured_system[] == "No session: true"
    end
end

# ── api_kwargs passthrough ────────────────────────────────────────────────────

@testset "run! — api_kwargs passed through to LLM call" begin
    captured_kwargs = Dict{Symbol,Any}()

    patch = @patch function PT.aitools(conv; kwargs...)
        merge!(captured_kwargs, Dict(kwargs))
        push!(conv, _ai_msg("Done"))
        conv
    end

    apply(patch) do
        agent = Agent(
            name         = "ReasonBot",
            instructions = "Think hard.",
            api_kwargs   = (; reasoning = Dict("effort" => "high"), temperature = 0.5),
        )

        result = run!(agent, "Solve this"; verbose=false)
        @test result == "Done"
        @test captured_kwargs[:reasoning] == Dict("effort" => "high")
        @test captured_kwargs[:temperature] == 0.5
    end
end

@testset "run! — empty api_kwargs does not break calls" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("OK"))
        conv
    end

    apply(patch) do
        agent = Agent(name="Bot", instructions="test")
        @test agent.api_kwargs == NamedTuple()
        result = run!(agent, "Hi"; verbose=false)
        @test result == "OK"
    end
end

# ── Session history updated ───────────────────────────────────────────────────

@testset "run! — session history appended" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("Hi there"))
        conv
    end

    apply(patch) do
        agent   = Agent(name="Bot", instructions="test")
        session = Session(app_name="App", user_id="u")

        run!(agent, "Hello"; session, verbose=false)

        # _save_history! saves messages after the seeded conversation,
        # so only the AIMessage is in history (UserMessage is part of the seed)
        @test any(m isa PT.AIMessage for m in session.history)
        # event recorded
        @test length(session.events) == 1
        @test session.events[1] isa TurnEvent
        @test session.events[1].input == "Hello"
    end
end

# ── Session history preserved across turns ────────────────────────────────────

@testset "run! — session persists across calls" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        push!(conv, _ai_msg("response $(call_count[])"))
        conv
    end

    apply(patch) do
        agent   = Agent(name="Bot", instructions="test")
        session = Session(app_name="App", user_id="u")

        run!(agent, "first";  session, verbose=false)
        run!(agent, "second"; session, verbose=false)

        # Two turns → 2 events
        @test length(session.events) == 2
        # History grows — each turn adds at least the AI response
        ai_msgs = filter(m -> m isa PT.AIMessage, session.history)
        @test length(ai_msgs) == 2
    end
end

# ── Tool call → execute → continue loop ──────────────────────────────────────

@testset "run! — tool call executed and result fed back" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            # First call: LLM requests a tool
            push!(conv, _tool_request("add", Dict("x" => 3, "y" => 4)))
        else
            # Second call: LLM gives final answer after seeing tool result
            push!(conv, _ai_msg("The answer is 7"))
        end
        conv
    end

    apply(patch) do
        @tool function add(x::Int, y::Int)
            "Add two integers."
            x + y
        end

        agent  = Agent(name="Bot", instructions="test", tools=[add_tool])
        result = run!(agent, "What is 3+4?"; verbose=false)

        @test result == "The answer is 7"
        @test call_count[] == 2  # LLM called twice: tool request + final answer
    end
end

# ── Tool call recorded in session events ──────────────────────────────────────

@testset "run! — tool events recorded in session" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _tool_request("greet_agent", Dict("name" => "Alice")))
        else
            push!(conv, _ai_msg("Done"))
        end
        conv
    end

    apply(patch) do
        @tool function greet_agent(name::String)
            "Greet someone."
            "Hello, $(name)!"
        end

        agent   = Agent(name="Bot", instructions="test", tools=[greet_agent_tool])
        session = Session(app_name="App", user_id="u")
        run!(agent, "Greet Alice"; session, verbose=false)

        @test length(session.events) == 1
        turn = session.events[1]
        @test length(turn.tool_calls) == 1
        @test turn.tool_calls[1].name == "greet_agent"
        @test turn.tool_calls[1].result == "Hello, Alice!"
    end
end

# ── return_direct short-circuits ──────────────────────────────────────────────

@testset "run! — return_direct skips second LLM call" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        push!(conv, _tool_request("cached_lookup", Dict("key" => "answer")))
        conv
    end

    apply(patch) do
        @tool return_direct=true function cached_lookup(key::String)
            "Look up a cached value."
            "42"
        end

        agent  = Agent(name="Bot", instructions="test", tools=[cached_lookup_tool])
        result = run!(agent, "What is the answer?"; verbose=false)

        @test result == "42"
        @test call_count[] == 1  # only one LLM call — return_direct short-circuited
    end
end

# ── on_complete hook fires ─────────────────────────────────────────────────────

@testset "run! — on_complete hook fires with result" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("done"))
        conv
    end

    apply(patch) do
        completed = Ref(false)
        hooks = AgentHooks(on_complete = (ag, result) -> (completed[] = true))
        agent = Agent(name="Bot", instructions="test", hooks=hooks)

        run!(agent, "go"; verbose=false)
        @test completed[]
    end
end

# ── on_tool_call and on_tool_result hooks fire ────────────────────────────────

@testset "run! — tool hooks fire in order" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _tool_request("echo_hook", Dict("msg" => "hi")))
        else
            push!(conv, _ai_msg("ok"))
        end
        conv
    end

    apply(patch) do
        @tool function echo_hook(msg::String)
            "Echo a message."
            msg
        end

        log = String[]
        hooks = AgentHooks(
            on_tool_call   = (ag, name, args) -> push!(log, "call:$name"),
            on_tool_result = (ag, name, res)  -> push!(log, "result:$name"),
        )
        agent = Agent(name="Bot", instructions="test",
                      tools=[echo_hook_tool], hooks=hooks)

        run!(agent, "echo hi"; verbose=false)
        @test log == ["call:echo_hook", "result:echo_hook"]
    end
end

# ── Tool error is caught and returned as string ───────────────────────────────

@testset "run! — tool errors are caught and fed back to LLM" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _tool_request("broken_tool", Dict("x" => 1)))
        else
            push!(conv, _ai_msg("Sorry, the tool failed"))
        end
        conv
    end

    apply(patch) do
        @tool function broken_tool(x::Int)
            "A tool that always errors."
            error("intentional error")
        end

        agent  = Agent(name="Bot", instructions="test", tools=[broken_tool_tool])
        result = run!(agent, "run broken"; verbose=false)

        @test result == "Sorry, the tool failed"
        @test call_count[] == 2   # LLM called again after seeing the error
    end
end

# ── HumanInterrupt thrown when should_interrupt and no channel ────────────────

@testset "run! — HumanInterrupt thrown without approval_channel" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _tool_request("dangerous_op", Dict("path" => "/tmp/x")))
        conv
    end

    apply(patch) do
        @tool function dangerous_op(path::String)
            "A dangerous operation."
            "done"
        end

        hooks = AgentHooks(should_interrupt = (name, args) -> name == "dangerous_op")
        agent = Agent(name="Bot", instructions="test",
                      tools=[dangerous_op_tool], hooks=hooks)

        @test_throws HumanInterrupt run!(agent, "do it"; verbose=false)
    end
end

# ── approval_channel: "approve" lets tool proceed ────────────────────────────

@testset "run! — approval_channel approve proceeds" begin
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        if call_count[] == 1
            push!(conv, _tool_request("guarded_op", Dict("x" => 1)))
        else
            push!(conv, _ai_msg("approved and done"))
        end
        conv
    end

    apply(patch) do
        @tool function guarded_op(x::Int)
            "A guarded operation."
            "result:$(x)"
        end

        hooks = AgentHooks(should_interrupt = (name, args) -> name == "guarded_op")
        agent = Agent(name="Bot", instructions="test",
                      tools=[guarded_op_tool], hooks=hooks)

        ch   = Channel{String}(1)
        put!(ch, "approve")   # pre-load approval

        result = run!(agent, "do it"; verbose=false, approval_channel=ch)
        @test result == "approved and done"
    end
end

# ── Session auto-persisted when store provided ────────────────────────────────

@testset "run! — session auto-persisted to store" begin
    patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("saved"))
        conv
    end

    apply(patch) do
        agent   = Agent(name="Bot", instructions="test")
        session = Session(app_name="App", user_id="u")
        store   = InMemorySessionStore()

        run!(agent, "persist me"; session, store, verbose=false)

        # Session should now be in the store
        @test !isnothing(load(store, session.id))
    end
end

# ── Structured output parse retry ────────────────────────────────────────────

struct ParseRetryReport
    summary::String
    score::Int
end

@testset "run! — structured output succeeds on first attempt" begin
    aitools_patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("done"))
        conv
    end
    extract_patch = @patch function PT.aiextract(conv; return_type, kwargs...)
        PT.DataMessage(; content=ParseRetryReport("ok", 10), tokens=(5, 5), elapsed=0.1)
    end

    apply([aitools_patch, extract_patch]) do
        agent  = Agent(name="Bot", instructions="test", output_type=ParseRetryReport)
        result = run!(agent, "go"; verbose=false)
        @test result isa ParseRetryReport
        @test result.score == 10
    end
end

@testset "run! — structured output retries on parse failure then succeeds" begin
    attempt = Ref(0)
    aitools_patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("done"))
        conv
    end
    extract_patch = @patch function PT.aiextract(conv; return_type, kwargs...)
        attempt[] += 1
        if attempt[] < 2
            # First attempt: return nothing (parse failure)
            PT.DataMessage(; content=nothing, tokens=(5, 5), elapsed=0.1)
        else
            # Second attempt: return correct type
            PT.DataMessage(; content=ParseRetryReport("recovered", 99), tokens=(5, 5), elapsed=0.1)
        end
    end

    apply([aitools_patch, extract_patch]) do
        agent  = Agent(name="Bot", instructions="test", output_type=ParseRetryReport,
                       retry=RetryConfig(max_parse_retries=2))
        result = redirect_stderr(devnull) do
            run!(agent, "go"; verbose=false)
        end
        @test result isa ParseRetryReport
        @test result.score == 99
        @test attempt[] == 2
    end
end

@testset "run! — structured output errors after exhausting parse retries" begin
    aitools_patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("done"))
        conv
    end
    extract_patch = @patch function PT.aiextract(conv; return_type, kwargs...)
        PT.DataMessage(; content=nothing, tokens=(5, 5), elapsed=0.1)
    end

    apply([aitools_patch, extract_patch]) do
        agent = Agent(name="Bot", instructions="test", output_type=ParseRetryReport,
                      retry=RetryConfig(max_parse_retries=1))
        @test_throws ErrorException redirect_stderr(devnull) do
            run!(agent, "go"; verbose=false)
        end
    end
end

@testset "run! — parse retries disabled with max_parse_retries=0" begin
    aitools_patch = @patch function PT.aitools(conv; kwargs...)
        push!(conv, _ai_msg("done"))
        conv
    end
    extract_patch = @patch function PT.aiextract(conv; return_type, kwargs...)
        PT.DataMessage(; content=nothing, tokens=(5, 5), elapsed=0.1)
    end

    apply([aitools_patch, extract_patch]) do
        agent = Agent(name="Bot", instructions="test", output_type=ParseRetryReport,
                      retry=RetryConfig(max_parse_retries=0))
        @test_throws ErrorException redirect_stderr(devnull) do
            run!(agent, "go"; verbose=false)
        end
    end
end

# ── max_iterations fallback ───────────────────────────────────────────────────

@testset "run! — max_iterations fallback returns last AI content" begin
    # Always return a tool request so the loop never terminates naturally
    call_count = Ref(0)
    patch = @patch function PT.aitools(conv; kwargs...)
        call_count[] += 1
        push!(conv, _tool_request("inf_tool", Dict("x" => call_count[])))
        conv
    end

    apply(patch) do
        @tool function inf_tool(x::Int)
            "Loops forever."
            "loop"
        end

        # max_iterations=2 means it will give up after 2 LLM calls
        agent  = Agent(name="Bot", instructions="test",
                       tools=[inf_tool_tool], max_iterations=2)
        result = redirect_stderr(devnull) do
            run!(agent, "loop"; verbose=false)
        end
        @test result isa String   # returns something, doesn't crash
        @test call_count[] == 2
    end
end
