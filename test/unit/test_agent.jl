struct TestReport
    "A simple test report"
    summary::String
    score::Int
    passed::Union{Bool, Nothing}
end

@testset "Agent struct" begin

    agent = Agent(
        name         = "TestBot",
        instructions = "You are a test assistant.",
        tools        = [add_tool, greet_tool],
    )

    @test agent.name == "TestBot"
    @test agent.instructions == "You are a test assistant."
    @test length(agent.tools) == 2
    @test agent.model == "gpt-4o-mini"
    @test agent.max_iterations == 10
    @test isnothing(agent.output_type)

    # Custom model and iterations
    agent2 = Agent(
        name           = "CustomBot",
        instructions   = "Custom.",
        model          = "gpt-4o",
        max_iterations = 5,
    )
    @test agent2.model == "gpt-4o"
    @test agent2.max_iterations == 5

    # output_type field
    agent3 = Agent(
        name         = "StructuredBot",
        instructions = "Extract data.",
        output_type  = TestReport,
    )
    @test agent3.output_type == TestReport

    # default retry config
    @test agent.retry isa RetryConfig
    @test agent.retry.max_retries    == 3
    @test agent.retry.initial_delay  == 0.5
    @test agent.retry.max_delay      == 60.0
    @test agent.retry.multiplier     == 2.0
    @test agent.retry.jitter         == true
    @test 429 in agent.retry.retry_on_status
    @test 529 in agent.retry.retry_on_status

    # custom retry config
    agent_no_retry = Agent(
        name         = "NoRetry",
        instructions = ".",
        retry        = RetryConfig(max_retries=0),
    )
    @test agent_no_retry.retry.max_retries == 0

    # default hooks are all nothing
    @test agent.hooks isa AgentHooks
    @test isnothing(agent.hooks.on_llm_call)
    @test isnothing(agent.hooks.on_llm_result)
    @test isnothing(agent.hooks.on_tool_call)
    @test isnothing(agent.hooks.on_tool_result)
    @test isnothing(agent.hooks.on_complete)
end

@testset "RetryConfig" begin

    cfg = RetryConfig()

    # backoff grows exponentially and is capped at max_delay
    d1 = NimbleAgents._backoff_delay(cfg, 1)
    d2 = NimbleAgents._backoff_delay(cfg, 2)
    d3 = NimbleAgents._backoff_delay(cfg, 3)
    @test d1 >= cfg.initial_delay * 0.75
    @test d1 <= cfg.initial_delay * 1.0
    @test d2 > d1   # grows
    @test d3 > d2

    # cap is respected — attempt 100 should not exceed max_delay
    d_large = NimbleAgents._backoff_delay(cfg, 100)
    @test d_large <= cfg.max_delay

    # no jitter path
    cfg_nojitter = RetryConfig(jitter=false)
    d_exact = NimbleAgents._backoff_delay(cfg_nojitter, 1)
    @test d_exact ≈ 0.5

    # _retryable detects status codes in the error message
    err_429 = ErrorException("HTTP 429 Too Many Requests")
    err_503 = ErrorException("HTTP 503 Service Unavailable")
    err_529 = ErrorException("HTTP 529 Overloaded")
    err_400 = ErrorException("HTTP 400 Bad Request")
    err_401 = ErrorException("HTTP 401 Unauthorized")

    @test  NimbleAgents._retryable(cfg, err_429)
    @test  NimbleAgents._retryable(cfg, err_503)
    @test  NimbleAgents._retryable(cfg, err_529)
    @test !NimbleAgents._retryable(cfg, err_400)
    @test !NimbleAgents._retryable(cfg, err_401)

    # False positive: "429" appears but not as an HTTP status
    err_fp = ErrorException("processed 429 records successfully")
    @test !NimbleAgents._retryable(cfg, err_fp)

    # "status 500" variant (some libraries format this way)
    err_s500 = ErrorException("request failed with status 500")
    @test NimbleAgents._retryable(cfg, err_s500)

    # _with_retry succeeds immediately when no error
    calls = Ref(0)
    result = NimbleAgents._with_retry(RetryConfig(), "Test") do
        calls[] += 1
        "ok"
    end
    @test result == "ok"
    @test calls[] == 1

    # _with_retry retries on retryable errors then succeeds
    # (suppress stderr — _with_retry logs each retry attempt)
    attempts = Ref(0)
    cfg_fast = RetryConfig(max_retries=2, initial_delay=0.001, jitter=false)
    result2 = redirect_stderr(devnull) do
        NimbleAgents._with_retry(cfg_fast, "Test") do
            attempts[] += 1
            attempts[] < 3 && throw(ErrorException("HTTP 429 rate limit"))
            "recovered"
        end
    end
    @test result2 == "recovered"
    @test attempts[] == 3   # failed twice, succeeded on third

    # _with_retry rethrows immediately on non-retryable error
    attempts2 = Ref(0)
    @test_throws ErrorException redirect_stderr(devnull) do
        NimbleAgents._with_retry(cfg_fast, "Test") do
            attempts2[] += 1
            throw(ErrorException("HTTP 401 Unauthorized"))
        end
    end
    @test attempts2[] == 1  # no retries for 401
end

@testset "AgentHooks" begin

    # hooks fire in the right order with the right arguments
    log = String[]

    hooks = AgentHooks(
        on_llm_call    = (ag, iter)            -> push!(log, "llm:$iter"),
        on_llm_result  = (ag, iter, resp)      -> push!(log, "llm_result:$iter"),
        on_tool_call   = (ag, name, args)      -> push!(log, "call:$name"),
        on_tool_result = (ag, name, result)    -> push!(log, "result:$name=$result"),
        on_complete    = (ag, result)          -> push!(log, "done"),
    )

    @test hooks.on_llm_call    isa Function
    @test hooks.on_llm_result  isa Function
    @test hooks.on_tool_call   isa Function
    @test hooks.on_tool_result isa Function
    @test hooks.on_complete    isa Function

    # fire each manually to confirm correct signatures
    dummy_agent = Agent(name="X", instructions="Y")
    hooks.on_llm_call(dummy_agent, 1)
    hooks.on_llm_result(dummy_agent, 1, "raw_response")
    hooks.on_tool_call(dummy_agent, "add", Dict{Symbol,Any}(:x => 1))
    hooks.on_tool_result(dummy_agent, "add", 42)
    hooks.on_complete(dummy_agent, "final")

    @test log == ["llm:1", "llm_result:1", "call:add", "result:add=42", "done"]

    # _fire is a no-op for nothing
    NimbleAgents._fire(nothing, dummy_agent, 1)  # should not error
end
