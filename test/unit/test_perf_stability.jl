###############################################################################
# test_perf_stability.jl — performance and type-stability smoke gates
###############################################################################

@testset "Type stability smoke" begin
    @test (@inferred NimbleAgents._resolve_cutoff(60, nothing)) isa Float64
    @test (@inferred NimbleAgents._trim_tool_output("hello", 100)) == "hello"
    @test (@inferred NimbleAgents._estimate_tokens(NimbleAgents.UserMessage("hello"))) == 2
    @test (@inferred NimbleAgents._keyword_score("dark mode", "prefers dark mode")) > 0.0

    store = NimbleAgents.InMemorySessionStore()
    session = NimbleAgents.Session(app_name="perf", user_id="u")
    @test (@inferred NimbleAgents.save!(store, session)) === session
    @test (@inferred NimbleAgents.list(store)) isa Vector{String}
end

@testset "Allocation smoke" begin
    patch = @patch function NimbleAgents.aitools(conv; kwargs...)
        push!(
            conv,
            NimbleAgents.AIMessage(; content="ok", tokens=(8, 4), elapsed=0.01),
        )
        conv
    end

    apply(patch) do
        agent = NimbleAgents.Agent(name="PerfBot", instructions="Be concise.")
        NimbleAgents.run!(agent, "warmup"; verbose=false)
        alloc = @allocated NimbleAgents.run!(agent, "hello"; verbose=false)
        @test alloc < 100_000_000
    end

    tmp = mktempdir()
    store = NimbleAgents.JSONSessionStore(tmp)
    session = NimbleAgents.Session(app_name="perf", user_id="u")
    push!(session.history, NimbleAgents.UserMessage("hello"))

    NimbleAgents.save!(store, session)  # warmup
    _ = NimbleAgents.load(store, session.id)  # warmup

    save_alloc = @allocated NimbleAgents.save!(store, session)
    load_alloc = @allocated NimbleAgents.load(store, session.id)
    @test save_alloc < 10_000_000
    @test load_alloc < 10_000_000
end
