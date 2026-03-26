###############################################################################
# cli_tools/schema.jl — JSON schema generation for CLITool arguments
###############################################################################

_julia_type_to_json(::Type{String}) = "string"
_julia_type_to_json(::Type{Int}) = "integer"
_julia_type_to_json(::Type{Float64}) = "number"
_julia_type_to_json(::Type{Bool}) = "boolean"
_julia_type_to_json(::Type) = "string"   # fallback: stringify

function _cli_schema(args::Vector{Pair{String,CLIArg}})
    properties = Dict{String,Any}()
    required = String[]

    for (arg_name, arg) in args
        properties[arg_name] = Dict{String,Any}(
            "type" => _julia_type_to_json(arg.type), "description" => arg.description
        )
        arg.required && push!(required, arg_name)
    end

    schema = Dict{String,Any}("type" => "object", "properties" => properties)
    isempty(required) || (schema["required"] = required)
    schema
end
