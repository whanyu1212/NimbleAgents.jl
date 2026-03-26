###############################################################################
# llm_core/overrides.jl — test seam overrides for LLM call plumbing
###############################################################################

# Test seam hooks for LLM call plumbing. Runtime defaults are `nothing`, which
# means normal behavior; tests can inject deterministic replacements.
const _AITOOLS_OVERRIDE = Ref{Union{Nothing,Function}}(nothing)
const _AIGENERATE_OVERRIDE = Ref{Union{Nothing,Function}}(nothing)
const _AIEXTRACT_OVERRIDE = Ref{Union{Nothing,Function}}(nothing)

function _set_aitools_override!(f::Union{Nothing,Function})
    old = _AITOOLS_OVERRIDE[]
    _AITOOLS_OVERRIDE[] = f
    old
end

function _set_aigenerate_override!(f::Union{Nothing,Function})
    old = _AIGENERATE_OVERRIDE[]
    _AIGENERATE_OVERRIDE[] = f
    old
end

function _set_aiextract_override!(f::Union{Nothing,Function})
    old = _AIEXTRACT_OVERRIDE[]
    _AIEXTRACT_OVERRIDE[] = f
    old
end
