###############################################################################
# tools/validation.jl — schema-based arg validation and callable invocation
###############################################################################

# JSON schema type → Julia types that are considered valid
const _SCHEMA_TYPE_MAP = Dict{String,Vector{Type}}(
    "string" => [String, SubString],
    "integer" =>
        [Int, Int8, Int16, Int32, Int64, Int128, UInt, UInt8, UInt16, UInt32, UInt64],
    "number" => [
        Int,
        Int8,
        Int16,
        Int32,
        Int64,
        Int128,
        UInt,
        UInt8,
        UInt16,
        UInt32,
        UInt64,
        Float16,
        Float32,
        Float64,
    ],
    "boolean" => [Bool],
    "array" => [Array, Vector],
    "object" => [Dict, AbstractDict],
)

# Validate args against the tool's JSON schema.
# Returns nothing if valid, or an error string describing the first problem found.
function _validate_tool_args(
    tool::AbstractTool, args::Dict{Symbol,<:Any}
)::Union{Nothing,String}
    params = tool.parameters
    properties = get(params, "properties", Dict())
    required = get(params, "required", String[])

    # Check required fields are present
    for req in required
        haskey(args, Symbol(req)) ||
            return "Missing required argument `$(req)` for tool `$(tool.name)`."
    end

    # Check types of provided args against schema
    for (key, val) in args
        prop = get(properties, string(key), nothing)
        isnothing(prop) && continue   # unknown arg — let the callable handle it
        expected_type = get(prop, "type", nothing)
        isnothing(expected_type) && continue   # no type constraint in schema

        valid_types = get(_SCHEMA_TYPE_MAP, expected_type, nothing)
        isnothing(valid_types) && continue   # unrecognised schema type — skip

        any(T -> val isa T, valid_types) ||
            return "Argument `$(key)` for tool `$(tool.name)` expected $(expected_type), " *
                   "got $(typeof(val))."
    end

    nothing
end

# Internal: call a tool's callable using parameter order from the schema.
# We use the `required` list (which preserves declaration order) rather than
# re-reading the method signature, avoiding arg-name mangling in test runners.
function _call_tool(tool::AbstractTool, args::Dict{Symbol,<:Any})
    # Validate args against the JSON schema before dispatching
    err = _validate_tool_args(tool, args)
    isnothing(err) || return "ToolValidationError: $(err)"

    params = tool.parameters

    # If the callable accepts a single Dict argument, pass the full args dict.
    # This is the convention used by built-in tools with optional parameters.
    m = first(methods(tool.callable))
    if m.nargs == 2   # 1 explicit arg (nargs includes implicit `#self#`)
        sig = Base.unwrap_unionall(m.sig)
        if length(sig.parameters) >= 2 && sig.parameters[2] <: Dict
            return tool.callable(args)
        end
    end

    # Otherwise: build ordered positional args from the schema's `required` list.
    ordered_names = if haskey(params, "required")
        Symbol.(params["required"])
    else
        Symbol.(sort(collect(keys(params["properties"]))))
    end

    positional = [args[k] for k in ordered_names if haskey(args, k)]
    tool.callable(positional...)
end
