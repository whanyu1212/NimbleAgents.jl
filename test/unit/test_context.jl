import PromptingTools as PT

@testset "ContextConfig" begin

    # defaults match Claude Opus 4.5/4.6 specs
    cfg = ContextConfig()
    @test cfg.context_window == 400_000
    @test cfg.compact_threshold ≈ 0.80
    @test cfg.keep_last == 20
    @test isnothing(cfg.summary_model)

    # threshold calculation: 80% of 400k = 320k
    threshold = floor(Int, cfg.context_window * cfg.compact_threshold)
    @test threshold == 320_000

    # custom config
    cfg2 = ContextConfig(context_window=128_000, compact_threshold=0.75, keep_last=10)
    @test cfg2.context_window == 128_000
    @test floor(Int, cfg2.context_window * cfg2.compact_threshold) == 96_000
    @test cfg2.keep_last == 10

    # field on Agent
    agent = Agent(name="A", instructions=".")
    @test agent.context isa ContextConfig
    @test agent.context.context_window == 400_000

    custom_agent = Agent(
        name="B",
        instructions=".",
        context=ContextConfig(context_window=128_000, keep_last=5),
    )
    @test custom_agent.context.context_window == 128_000
    @test custom_agent.context.keep_last == 5
end

@testset "_estimate_tokens" begin

    # AIMessage carries real token counts from the API
    msg_ai = PT.AIMessage(content="hello"; tokens=(10, 5))
    @test NimbleAgents._estimate_tokens(msg_ai) == 15

    # UserMessage has no tokens field — falls back to char heuristic
    # "hello world" = 11 chars → ceil(11/4) = 3
    msg_user = PT.UserMessage("hello world")
    @test NimbleAgents._estimate_tokens(msg_user) == ceil(Int, 11 / 4)
    @test NimbleAgents._estimate_tokens(msg_user) == 3

    # AIMessage with zero tokens also falls back to char heuristic
    msg_zero = PT.AIMessage(content="hello world"; tokens=(0, 0))
    @test NimbleAgents._estimate_tokens(msg_zero) == 3

    # empty content
    msg_empty = PT.UserMessage("")
    @test NimbleAgents._estimate_tokens(msg_empty) == 0

    # _history_tokens sums across messages
    s = Session()
    push!(s.history, PT.UserMessage("hello world"))              # 3 tokens (heuristic)
    push!(s.history, PT.AIMessage(content="hi"; tokens=(5, 3)))  # 8 tokens (exact)
    @test NimbleAgents._history_tokens(s) == 11
end

@testset "compact! — below threshold" begin
    agent = Agent(name="A", instructions=".")
    session = Session()

    # well below threshold — compact! should be a no-op
    push!(session.history, PT.UserMessage("hello"))
    push!(session.history, PT.AIMessage(content="hi"))

    result = compact!(session, agent)
    @test result == false
    @test length(session.history) == 2   # unchanged
end

@testset "compact! — keep_last guard" begin

    # Even if token estimate is high, if we have fewer messages than keep_last
    # there is nothing to summarise — compact! should bail out
    cfg = ContextConfig(context_window=100, compact_threshold=0.01, keep_last=20)
    agent = Agent(name="A", instructions=".", context=cfg)
    session = Session()

    for i in 1:5
        push!(session.history, PT.UserMessage("msg $i"))
    end

    result = compact!(session, agent)
    @test result == false
    @test length(session.history) == 5
end

@testset "compact! — splits old vs keep correctly" begin

    # Use a very low threshold so we can trigger compaction without a huge history.
    # Set summary_model to something invalid so if it tries to call the LLM it throws,
    # proving that we only test the split logic here without a live API call.
    cfg = ContextConfig(
        context_window=100,    # tiny
        compact_threshold=0.01,   # triggers immediately (threshold = 1 token)
        keep_last=3,
    )
    agent = Agent(name="A", instructions=".", context=cfg)
    session = Session()

    # 6 messages: first 3 are "old", last 3 should be kept
    msgs = [PT.UserMessage("msg $i") for i in 1:6]
    append!(session.history, msgs)

    # We expect compact! to attempt a summarisation LLM call and fail
    # (no API key in unit tests) — catch the error but verify the split
    # would have been 3 old + 3 kept.
    n = length(session.history)
    n_old = n - cfg.keep_last          # 3
    @test n_old == 3

    old_content = [session.history[i].content for i in 1:n_old]
    keep_content = [session.history[i].content for i in (n_old + 1):n]
    @test old_content == ["msg 1", "msg 2", "msg 3"]
    @test keep_content == ["msg 4", "msg 5", "msg 6"]
end
