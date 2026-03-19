using Mocking
Mocking.activate()

using NimbleAgents
using Test

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

function timed_include(path)
    t0 = time()
    include(path)
    dt = round(time() - t0; digits=2)
    println("  ⏱  $(path) — $(dt)s")
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
    timed_include("unit/test_skills.jl")
    timed_include("unit/test_artifacts.jl")
    timed_include("unit/test_builtins.jl")
    timed_include("unit/test_mcp.jl")
    timed_include("unit/test_run.jl")
end
