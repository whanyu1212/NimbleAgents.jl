using SQLite

using NimbleAgents
using Test
using Aqua

module Mocking
using ..NimbleAgents

export @patch, apply, activate

activate() = nothing

struct Patch
    target::Symbol
    fn::Function
end

function _target_override_setter(target::Symbol)
    if target === :aitools
        return NimbleAgents._set_aitools_override!
    elseif target === :aigenerate
        return NimbleAgents._set_aigenerate_override!
    elseif target === :aiextract
        return NimbleAgents._set_aiextract_override!
    else
        error("Unsupported patch target: $(target)")
    end
end

function apply(patch::Patch, f::Function)
    apply(Patch[patch], f)
end

function apply(patches::AbstractVector{Patch}, f::Function)
    olds = Pair{Patch,Union{Nothing,Function}}[]
    try
        for patch in patches
            setter = _target_override_setter(patch.target)
            old = setter(patch.fn)
            push!(olds, patch => old)
        end
        return f()
    finally
        for (patch, old) in Iterators.reverse(olds)
            setter = _target_override_setter(patch.target)
            setter(old)
        end
    end
end

# Support do-block call style: `apply(patch) do ... end`
apply(f::Function, patch::Patch) = apply(patch, f)
apply(f::Function, patches::AbstractVector{Patch}) = apply(patches, f)

macro patch(def)
    def isa Expr && def.head == :function || error("@patch expects a function definition")
    sig = def.args[1]
    sig isa Expr && sig.head == :call || error("@patch expects a named function definition")
    fname = sig.args[1]
    target = if fname isa Expr && fname.head == :. && length(fname.args) == 2
        prop = fname.args[2]
        prop isa QuoteNode ? prop.value : prop
    elseif fname isa Symbol
        fname
    else
        error("@patch expects a simple function target, got: $(sprint(show, fname))")
    end

    target isa Symbol || error("@patch target must be a Symbol")
    target in (:aitools, :aigenerate, :aiextract) || error(
        "@patch only supports NimbleAgents.aitools/.aigenerate/.aiextract, got: $(target)",
    )

    patched_name = gensym(:patched)
    patched_sig = deepcopy(sig)
    patched_sig.args[1] = patched_name
    patched_def = Expr(:function, patched_sig, def.args[2])

    return esc(quote
        $patched_def
        Mocking.Patch($(QuoteNode(target)), $patched_name)
    end)
end

end

using .Mocking
Mocking.activate()

const RUN_LIVE_TESTS =
    lowercase(get(ENV, "NIMBLEAGENTS_RUN_LIVE_TESTS", "false")) in ("1", "true", "yes")

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
    try
        println("  ⏱  $(path) — $(dt)s")
    catch err
        err isa IOError || rethrow()
    end
end

@testset "Aqua" begin
    Aqua.test_all(NimbleAgents; stale_deps=(ignore=[:Test],), deps_compat=(ignore=[:Test],))
end

@testset "NimbleAgents.jl" begin
    timed_include("unit/test_tools.jl")
    timed_include("unit/test_docstrings.jl")
    timed_include("unit/test_reference_docs.jl")
    timed_include("unit/test_public_api.jl")
    timed_include("unit/test_source_layout.jl")
    timed_include("unit/test_examples_syntax.jl")
    timed_include("unit/test_examples_runtime.jl")
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
    timed_include("unit/test_perf_stability.jl")
    timed_include("unit/test_parallel_tools.jl")
    timed_include("unit/test_sqlite_store.jl")
    timed_include("unit/test_memory.jl")
    timed_include("unit/test_sqlite_memory.jl")
    timed_include("unit/test_gemini.jl")
    timed_include("unit/test_repl.jl")
    timed_include("unit/test_trim.jl")
end

@testset "Integration (Live)" begin
    if RUN_LIVE_TESTS
        timed_include("integration/test_structured_output.jl")
        timed_include("integration/test_agent_live.jl")
    else
        println(
            "  ⏭  integration tests skipped (set NIMBLEAGENTS_RUN_LIVE_TESTS=true to enable)",
        )
    end
end
