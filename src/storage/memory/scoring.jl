###############################################################################
# storage/memory/scoring.jl — keyword tokenization and relevance scoring
###############################################################################

# Tokenize into lowercase words, stripping punctuation.
function _tokenize(text::String)::Vector{String}
    words = split(lowercase(text))
    [replace(w, r"[^\w]" => "") for w in words if !isempty(replace(w, r"[^\w]" => ""))]
end

"""
    _keyword_score(query, content) -> Float64

Score how well `content` matches `query` using keyword overlap + substring boost.
Returns a value in [0, 1].
"""
function _keyword_score(query::String, content::String)::Float64
    query_words = _tokenize(query)
    isempty(query_words) && return 0.0

    content_lower = lowercase(content)
    content_words = Set(_tokenize(content))

    # Word overlap
    hits = count(w -> w in content_words, query_words)
    score = hits / length(query_words)

    # Exact substring boost
    if occursin(lowercase(query), content_lower)
        score = min(score + 0.3, 1.0)
    end

    clamp(score, 0.0, 1.0)
end
