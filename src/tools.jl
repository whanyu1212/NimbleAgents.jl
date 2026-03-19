###############################################################################
# tools.jl — Tool definition and dispatch
#
# Builds on PromptingTools' Tool / tool_call_signature / execute_tool so we
# don't duplicate JSON-schema generation logic.
###############################################################################

import PromptingTools as PT

# Re-export the core types so users only need `using NimbleAgents`
const AbstractTool = PT.AbstractTool
const ToolMessage  = PT.ToolMessage

# ──────────────────────────────────────────────────────────────────────────────
# NimbleTool — extends PT.Tool with return_direct
# ──────────────────────────────────────────────────────────────────────────────

"""
    NimbleTool(; name, parameters, description, callable, return_direct, strict)

A tool with all the fields of `PT.Tool` plus `return_direct::Bool`.

When `return_direct = true`, the agent loop short-circuits immediately after
this tool executes — its return value becomes the agent's final output without
any further LLM call.

Use `@tool` (or `@tool return_direct=true`) to create tools; you rarely need
to construct `NimbleTool` directly.
"""
struct NimbleTool <: AbstractTool
    name           ::String
    parameters     ::Dict{String, Any}
    description    ::Union{String, Nothing}
    callable       ::Any
    return_direct  ::Bool
    return_artifact::Bool
    strict         ::Union{Bool, Nothing}
end

NimbleTool(; name, parameters, description=nothing, callable,
             return_direct=false, return_artifact=false, strict=nothing) =
    NimbleTool(name, parameters, description, callable,
               return_direct, return_artifact, strict)

# Keep PT.Tool as an alias so existing code using Tool still works
const Tool = NimbleTool

# Helper used in run! — false for PT.Tool (third-party tools), true only when set
_is_return_direct(t::NimbleTool)   = t.return_direct
_is_return_direct(::PT.Tool)       = false
_is_return_artifact(t::NimbleTool) = t.return_artifact
_is_return_artifact(::PT.Tool)     = false
_is_return_artifact(::Any)         = false

# ──────────────────────────────────────────────────────────────────────────────
# @tool macro
#
# Usage:
#
#   @tool function get_weather(location::String, unit::String="celsius")
#       "Return the current weather for a location."
#       ...
#   end
#
# This defines the function normally and binds a `Tool` object to a variable
# named `<funcname>_tool` in the calling module.
# ──────────────────────────────────────────────────────────────────────────────

"""
    @tool [return_direct=true] function f(args...) ... end

Define a Julia function and automatically register it as a `NimbleTool` (with
name, description, and JSON parameter schema inferred from the function
signature and its docstring).

A variable `<funcname>_tool` is created in the calling scope holding the
resulting `NimbleTool` object.

When `return_direct=true`, the agent loop short-circuits immediately after this
tool executes — its return value becomes the agent's final output without any
further LLM call. Useful for lookup tools, cache hits, or any tool whose result
is already the definitive answer.

# Example — standard tool
```julia
@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end
```

# Example — return_direct tool
```julia
@tool return_direct=true function lookup_faq(question::String)
    "Look up a frequently asked question. Returns a definitive answer."
    faq_db[question]
end
# When the agent calls lookup_faq, its result is returned immediately —
# no follow-up LLM call is made.
```
"""
macro tool(args...)
    return_direct   = false
    return_artifact = false
    funcdef = nothing

    for arg in args
        if arg isa Expr && arg.head == :(=) &&
                arg.args[1] == :return_direct
            return_direct = arg.args[2]
        elseif arg isa Expr && arg.head == :(=) &&
                arg.args[1] == :return_artifact
            return_artifact = arg.args[2]
        elseif arg isa Expr && arg.head in (:function, :(=))
            funcdef = arg
        else
            error("@tool: unexpected argument: $arg")
        end
    end

    isnothing(funcdef) &&
        error("@tool expects a function definition")

    # Extract the function name from the signature
    sig = funcdef.args[1]
    fname = if sig isa Expr && sig.head == :call
        sig.args[1]
    elseif sig isa Symbol
        sig
    else
        error("@tool: could not parse function name from: $sig")
    end

    bare_name = fname isa Expr ? fname.args[end] : fname
    tool_var  = Symbol(bare_name, :_tool)
    tool_name = string(bare_name)

    # Extract description from the first string literal in the body
    body = funcdef.args[end]
    docs = nothing
    if body isa Expr && body.head == :block
        for stmt in body.args
            stmt isa LineNumberNode && continue
            if stmt isa String
                docs = stmt
            end
            break
        end
    end

    docs_expr = isnothing(docs) ? :nothing : docs

    schema_build = quote
        local _method    = first(methods($(esc(fname))))
        local _arg_names = PT.get_arg_names(_method)
        local _arg_types = PT.get_arg_types(_method)

        local _properties = Dict{String, Any}()
        local _required   = String[]
        for (n, t) in zip(_arg_names, _arg_types)
            _properties[string(n)] = PT.to_json_schema(PT.remove_null_types(t))
            PT.is_required_field(t) && push!(_required, string(n))
        end

        local _params = Dict{String, Any}("type" => "object", "properties" => _properties)
        isempty(_required) || (_params["required"] = _required)

        $(esc(tool_var)) = NimbleTool(;
            name            = $(tool_name),
            parameters      = _params,
            description     = $(docs_expr),
            callable        = $(esc(fname)),
            return_direct   = $(return_direct),
            return_artifact = $(return_artifact),
        )
    end

    return Expr(:block, esc(funcdef), schema_build)
end

# ──────────────────────────────────────────────────────────────────────────────
# Tool registry helpers
# ──────────────────────────────────────────────────────────────────────────────

"""
    build_tool_map(tools) -> Dict{String, Tool}

Convert a vector of `Tool` objects into a name-keyed dict for fast dispatch.
"""
function build_tool_map(tools::Vector{<:AbstractTool})::Dict{String, AbstractTool}
    Dict(t.name => t for t in tools)
end

"""
    tools_schema(tools) -> Vector{Dict}

Render a vector of `Tool`s into the JSON-serialisable list that OpenAI-compatible
APIs expect under the `tools` key.
"""
function tools_schema(tools::Vector{<:AbstractTool})
    map(tools) do t
        schema = Dict{String, Any}(
            "type" => "function",
            "function" => Dict{String, Any}(
                "name"        => t.name,
                "parameters"  => t.parameters,
            ),
        )
        if !isnothing(t.description) && !isempty(t.description)
            schema["function"]["description"] = t.description
        end
        if !isnothing(t.strict)
            schema["function"]["strict"] = t.strict
        end
        schema
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# Tool dispatch
# ──────────────────────────────────────────────────────────────────────────────

"""
    dispatch_tool(tool_map, name, args) -> Any

Look up `name` in `tool_map` and call the corresponding tool with `args`
(a `Dict{Symbol, Any}`).  Returns the tool's return value, or rethrows on error.

Argument ordering uses the `required` list from the tool's JSON schema (which
reflects the original parameter order), so this is robust to Julia mangling
method argument names in test environments.
"""
function dispatch_tool(
    tool_map::Dict{String, <:AbstractTool},
    name::String,
    args::Dict{Symbol, <:Any},
)
    haskey(tool_map, name) ||
        throw(PT.ToolNotFoundError("Tool `$name` not found in tool map"))

    tool = tool_map[name]
    _call_tool(tool, args)
end

"""
    dispatch_tool(tool_map, msg::ToolMessage) -> Any

Convenience overload that accepts a `ToolMessage` directly (as returned by
`PromptingTools` when parsing an LLM response with tool calls).
"""
function dispatch_tool(
    tool_map::Dict{String, <:AbstractTool},
    msg::ToolMessage,
)
    haskey(tool_map, msg.name) ||
        throw(PT.ToolNotFoundError("Tool `$(msg.name)` not found in tool map"))

    tool = tool_map[msg.name]
    _call_tool(tool, msg.args)
end

# Internal: call a tool's callable using parameter order from the schema.
# We use the `required` list (which preserves declaration order) rather than
# re-reading the method signature, avoiding arg-name mangling in test runners.
function _call_tool(tool::AbstractTool, args::Dict{Symbol, <:Any})
    params = tool.parameters

    # If the callable accepts a single Dict argument, pass the full args dict.
    # This is the convention used by built-in tools with optional parameters.
    m = first(methods(tool.callable))
    if m.nargs == 2   # 1 explicit arg (nargs includes implicit `#self#`)
        sig = Base.unwrap_unionall(m.sig)
        if length(sig.parameters) >= 2 &&
                sig.parameters[2] <: Dict
            return tool.callable(args)
        end
    end

    # Otherwise: build ordered positional args from the schema's `required` list.
    ordered_names = if haskey(params, "required")
        Symbol.(params["required"])
    else
        sort(collect(keys(params["properties"]))) .|> Symbol
    end

    positional = [args[k] for k in ordered_names if haskey(args, k)]
    tool.callable(positional...)
end
