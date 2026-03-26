###############################################################################
# llm_core/internal_helpers/json_utils.jl — generic JSON and type coercion utils
###############################################################################

function _vector_eltype(T::Type)
    sig = Base.unwrap_unionall(T)
    if isempty(sig.parameters)
        return Any
    end
    el = sig.parameters[1]
    el isa TypeVar ? Any : el
end

function _symbol_dict(obj)::Dict{Symbol,Any}
    if obj isa Dict{Symbol,Any}
        return obj
    end
    result = Dict{Symbol,Any}()
    for (k, v) in pairs(obj)
        result[Symbol(k)] = _to_plain(v)
    end
    result
end

function _string_dict(obj)::Dict{String,Any}
    result = Dict{String,Any}()
    for (k, v) in pairs(obj)
        result[string(k)] = _json_safe(v)
    end
    result
end

function _to_plain(value)
    if value isa JSON3.Object
        return Dict{String,Any}(string(k) => _to_plain(v) for (k, v) in pairs(value))
    elseif value isa JSON3.Array
        return Any[_to_plain(v) for v in value]
    elseif value isa AbstractDict
        return Dict{String,Any}(string(k) => _to_plain(v) for (k, v) in pairs(value))
    elseif value isa AbstractVector
        return Any[_to_plain(v) for v in value]
    else
        return value
    end
end

function _json_safe(value)
    if value isa NamedTuple
        return Dict{String,Any}(string(k) => _json_safe(v) for (k, v) in pairs(value))
    elseif value isa AbstractDict
        return Dict{String,Any}(string(k) => _json_safe(v) for (k, v) in pairs(value))
    elseif value isa AbstractVector
        return Any[_json_safe(v) for v in value]
    else
        return value
    end
end

_maybe_int(::Nothing) = nothing
_maybe_int(x) = Int(x)
