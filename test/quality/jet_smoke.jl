using Test
using NimbleAgents
using JET

@testset "JET smoke checks" begin
    @test_opt NimbleAgents._resolve_cutoff(60, nothing)
    @test_opt NimbleAgents._trim_tool_output("hello", 100)
    @test_opt NimbleAgents._estimate_tokens(NimbleAgents.UserMessage("hello world"))
    @test_opt NimbleAgents._keyword_score("dark mode", "prefers dark mode")

    store = NimbleAgents.InMemorySessionStore()
    session = NimbleAgents.Session(app_name="perf", user_id="u")
    @test_opt NimbleAgents.save!(store, session)
    @test_opt NimbleAgents.list(store)
end
