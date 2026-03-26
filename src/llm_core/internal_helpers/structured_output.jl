###############################################################################
# llm_core/internal_helpers/structured_output.jl — structured output coercion
###############################################################################

function _parse_structured_fallback(return_type::Type, content)
    if content isa AbstractString
        try
            return _coerce_value(return_type, _symbol_dict(_to_plain(JSON3.read(content))))
        catch
            return nothing
        end
    end
    nothing
end

function _coerce_value(T::Type, value)
    if T isa Union && (Nothing in Base.uniontypes(T))
        if isnothing(value)
            return nothing
        end
        inner = _remove_null_types(T)
        return _coerce_value(inner, value)
    end

    value isa JSON3.Object && return _coerce_value(T, _symbol_dict(_to_plain(value)))
    value isa JSON3.Array && return _coerce_value(T, _to_plain(value))

    T <: AbstractString && return String(value)
    T === Bool && return Bool(value)
    T <: Integer && return convert(T, value)
    T <: AbstractFloat && return convert(T, value)

    if T <: AbstractVector
        item_type = _vector_eltype(T)
        return [_coerce_value(item_type, item) for item in value]
    end

    if isstructtype(T)
        dict = value isa AbstractDict ? value : _symbol_dict(value)
        kwargs = Pair{Symbol,Any}[]
        for (name, field_type) in zip(fieldnames(T), fieldtypes(T))
            if haskey(dict, name)
                push!(kwargs, name => _coerce_value(field_type, dict[name]))
            elseif is_required_field(field_type)
                throw(ArgumentError("Missing required field `$(name)` for $(T)"))
            else
                push!(kwargs, name => nothing)
            end
        end
        return T(; kwargs...)
    end

    convert(T, value)
end
