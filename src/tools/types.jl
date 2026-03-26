###############################################################################
# tools/types.jl — tool model and return-direct/artifact metadata
###############################################################################

"""
    NimbleTool(; name, parameters, description, callable, return_direct, strict)

A tool with all the fields of `Tool` plus `return_direct::Bool`.

When `return_direct = true`, the agent loop short-circuits immediately after
this tool executes — its return value becomes the agent's final output without
any further LLM call.

Use `@tool` (or `@tool return_direct=true`) to create tools; you rarely need
to construct `NimbleTool` directly.
"""
struct NimbleTool <: AbstractTool
    name::String
    parameters::Dict{String,Any}
    description::Union{String,Nothing}
    callable::Any
    return_direct::Bool
    return_artifact::Bool
    strict::Union{Bool,Nothing}
    max_output::Int   # 0 = unlimited (use agent default)
end

function NimbleTool(;
    name,
    parameters,
    description=nothing,
    callable,
    return_direct=false,
    return_artifact=false,
    strict=nothing,
    max_output=0,
)
    NimbleTool(
        name,
        parameters,
        description,
        callable,
        return_direct,
        return_artifact,
        strict,
        max_output,
    )
end

# Keep Tool as an alias so existing code using Tool still works
const Tool = NimbleTool

# Helpers used in run! — false/unlimited unless explicitly enabled on NimbleTool.
_is_return_direct(t::NimbleTool) = t.return_direct
_is_return_direct(::Any) = false
_is_return_artifact(t::NimbleTool) = t.return_artifact
_is_return_artifact(::Any) = false
_max_output(t::NimbleTool) = t.max_output
_max_output(::Any) = 0
