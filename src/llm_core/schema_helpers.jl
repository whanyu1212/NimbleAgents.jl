###############################################################################
# llm_core/schema_helpers.jl — schema derivation from Julia method signatures
###############################################################################

remove_null_types(::Type{T}) where {T} = _remove_null_types(T)
function _remove_null_types(T::Type)
    T isa Union || return T
    keep = filter(t -> t !== Nothing, Base.uniontypes(T))
    isempty(keep) && return Any
    length(keep) == 1 && return keep[1]
    Union{keep...}
end

is_required_field(::Type{T}) where {T} = !(T isa Union) || !(Nothing in Base.uniontypes(T))

function get_arg_names(method::Method)
    Base.method_argnames(method)[2:end]
end

function get_arg_types(method::Method)
    sig = Base.unwrap_unionall(method.sig)
    collect(sig.parameters[2:end])
end

function to_json_schema(::Type{T}) where {T}
    _to_json_schema(T)
end

function _to_json_schema(T::Type)
    T === Any && return Dict{String,Any}()
    T === Bool && return Dict{String,Any}("type" => "boolean")
    T <: AbstractString && return Dict{String,Any}("type" => "string")
    T <: Integer && return Dict{String,Any}("type" => "integer")
    T <: AbstractFloat && return Dict{String,Any}("type" => "number")
    T <: AbstractVector && return Dict{String,Any}(
        "type" => "array", "items" => _to_json_schema(_vector_eltype(T))
    )
    T <: AbstractDict && return Dict{String,Any}("type" => "object")
    isstructtype(T) || error("Unsupported schema type: $(T)")

    properties = Dict{String,Any}()
    required = String[]
    for (name, field_type) in zip(fieldnames(T), fieldtypes(T))
        properties[string(name)] = _to_json_schema(_remove_null_types(field_type))
        is_required_field(field_type) && push!(required, string(name))
    end

    schema = Dict{String,Any}("type" => "object", "properties" => properties)
    isempty(required) || (schema["required"] = required)
    schema
end
