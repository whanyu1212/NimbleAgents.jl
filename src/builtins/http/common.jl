###############################################################################
# builtins/http/common.jl — shared helpers for HTTP built-in tools
###############################################################################

function _parse_headers_json(headers_json::AbstractString)
    try
        parsed = JSON3.read(headers_json, Dict{String,String})
        [k => v for (k, v) in parsed]
    catch
        nothing
    end
end

function _truncate_text(text::String, limit::Int)
    if length(text) > limit
        text[1:limit] * "\n... (truncated at $(limit) chars)"
    else
        text
    end
end
