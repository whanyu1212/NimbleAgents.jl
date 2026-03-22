using Mocking
Mocking.activate()

using NimbleAgents
using Test
using Aqua

# Tools must be defined at module scope (not inside @testset blocks) so that
# Julia does not mangle argument names in closure-wrapped code.
# Unit test files that need shared fixtures include them from here.

# Fixtures for test_return_direct.jl
# @tool creates <name>_tool variable; functions are named separately.
@tool function rd_normal(x::Int)
    "A normal tool — does not short-circuit."
    x * 2
end

@tool return_direct=true function rd_direct(x::Int)
    "A return_direct tool — short-circuits the agent loop."
    x * 100
end

@tool function rd_implicit(y::String)
    "No return_direct keyword."
    uppercase(y)
end

# Fixtures for test_parallel_tools.jl
@tool function par_add(x::Int, y::Int)
    "Add two integers with a small delay."
    sleep(0.05)
    x + y
end

@tool function par_single(x::Int)
    "Double a number."
    x * 2
end

@tool function par_seq_a(x::Int)
    "Tool A."
    x * 10
end

@tool function par_seq_b(x::Int)
    "Tool B."
    x * 20
end

@tool function par_good(x::Int)
    "Works fine."
    x * 10
end

@tool function par_bad(x::Int)
    "Always fails."
    error("boom")
end

@tool function par_hook_a(x::Int)
    "Tool A."
    x
end

@tool function par_hook_b(x::Int)
    "Tool B."
    x
end

# Fixtures for test_eval.jl
@tool function ev_add(x::Int, y::Int)
    "Add two numbers."
    x + y
end

# Fixtures for test_trim.jl
@tool max_output=10_000 function trim_test(x::String)
    "A tool with a per-tool output limit."
    x
end

@tool function trim_default(x::String)
    "A tool with no per-tool output limit."
    x
end

function timed_include(path)
    t0 = time()
    include(path)
    dt = round(time() - t0; digits=2)
    println("  ⏱  $(path) — $(dt)s")
end

@testset "Aqua" begin
    Aqua.test_all(
        NimbleAgents;
        stale_deps=(ignore=[:Test, :DotEnv, :Term],),
        deps_compat=(ignore=[:Test],),
    )
end

@testset "NimbleAgents.jl" begin
    timed_include("unit/test_tools.jl")
    timed_include("unit/test_agent.jl")
    timed_include("unit/test_session.jl")
    timed_include("unit/test_handoff.jl")
    timed_include("unit/test_primitives.jl")
    timed_include("unit/test_context.jl")
    timed_include("unit/test_return_direct.jl")
    timed_include("unit/test_cli_tools.jl")
    timed_include("unit/test_external_agent.jl")
    timed_include("unit/test_skills.jl")
    timed_include("unit/test_artifacts.jl")
    timed_include("unit/test_builtins.jl")
    timed_include("unit/test_mcp.jl")
    timed_include("unit/test_run.jl")
    timed_include("unit/test_guardrails.jl")
    timed_include("unit/test_tracer.jl")
    timed_include("unit/test_eval.jl")
    timed_include("unit/test_rate_limit.jl")
    timed_include("unit/test_parallel_tools.jl")
    timed_include("unit/test_sqlite_store.jl")
    timed_include("unit/test_memory.jl")
    timed_include("unit/test_sqlite_memory.jl")
    timed_include("unit/test_gemini.jl")
    timed_include("unit/test_repl.jl")
    timed_include("unit/test_trim.jl")
end
