###############################################################################
# tools/registry.jl — tool map/schema generation and dispatch entrypoints
###############################################################################

"""
    build_tool_map(tools) -> Dict{String, Tool}

Convert a vector of `Tool` objects into a name-keyed dict for fast dispatch.
"""
function build_tool_map(tools::Vector{<:AbstractTool})::Dict{String,AbstractTool}
    Dict(t.name => t for t in tools)
end

"""
    tools_schema(tools) -> Vector{Dict}

Render a vector of `Tool`s into the JSON-serialisable list that OpenAI-compatible
APIs expect under the `tools` key.
"""
function tools_schema(tools::Vector{<:AbstractTool})
    map(tools) do t
        schema = Dict{String,Any}(
            "type" => "function",
            "function" => Dict{String,Any}("name" => t.name, "parameters" => t.parameters),
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

"""
    dispatch_tool(tool_map, name, args) -> Any

Look up `name` in `tool_map` and call the corresponding tool with `args`
(a `Dict{Symbol, Any}`). Returns the tool's return value, or rethrows on error.

Argument ordering uses the `required` list from the tool's JSON schema (which
reflects the original parameter order), so this is robust to Julia mangling
method argument names in test environments.
"""
function dispatch_tool(
    tool_map::Dict{String,<:AbstractTool}, name::String, args::Dict{Symbol,<:Any}
)
    haskey(tool_map, name) ||
        throw(ToolNotFoundError("Tool `$name` not found in tool map"))

    tool = tool_map[name]
    _call_tool(tool, args)
end

"""
    dispatch_tool(tool_map, msg::ToolMessage) -> Any

Convenience overload that accepts a `ToolMessage` directly (as returned by
NimbleAgents when parsing an LLM response with tool calls).
"""
function dispatch_tool(tool_map::Dict{String,<:AbstractTool}, msg::ToolMessage)
    haskey(tool_map, msg.name) ||
        throw(ToolNotFoundError("Tool `$(msg.name)` not found in tool map"))

    tool = tool_map[msg.name]
    _call_tool(tool, msg.args)
end
