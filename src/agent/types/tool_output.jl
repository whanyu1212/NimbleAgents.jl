###############################################################################
# agent/types/tool_output.jl — tool output trimming policy helpers
###############################################################################

"""
    _trim_tool_output(text, max_chars) -> String

Line-aware head+tail trimming. If `text` fits within `max_chars`, returns it
unchanged. Otherwise keeps ~80% from the head and ~20% from the tail (snapped
to line boundaries) with an informative gap marker.

Returns the original string when `max_chars <= 0` (unlimited).
"""
function _trim_tool_output(text::AbstractString, max_chars::Int)::String
    max_chars <= 0 && return String(text)
    n = length(text)
    n <= max_chars && return String(text)

    lines = split(text, '\n')
    length(lines) <= 2 && return text[1:max_chars] * "\n... (truncated, $(n) total chars)"

    head_budget = round(Int, max_chars * 0.80)
    tail_budget = max_chars - head_budget

    # Head: take lines until budget exhausted
    head_lines = String[]
    head_chars = 0
    for line in lines
        next = head_chars + length(line) + 1  # +1 for newline
        next > head_budget && break
        push!(head_lines, line)
        head_chars = next
    end

    # Tail: take lines from end until budget exhausted
    tail_lines = String[]
    tail_chars = 0
    for i in length(lines):-1:1
        line = lines[i]
        next = tail_chars + length(line) + 1
        next > tail_budget && break
        pushfirst!(tail_lines, line)
        tail_chars = next
    end

    omitted_lines = length(lines) - length(head_lines) - length(tail_lines)
    omitted_chars = n - head_chars - tail_chars
    approx_tokens = div(omitted_chars, 4)

    head_str = join(head_lines, '\n')
    tail_str = join(tail_lines, '\n')
    marker = "\n... (trimmed $(omitted_chars) chars / ~$(approx_tokens) tokens, $(omitted_lines) lines omitted) ...\n"

    head_str * marker * tail_str
end

"""
    _effective_max_output(tool_obj, agent) -> Int

Resolve the effective output limit: per-tool override wins, then agent default.
Returns 0 (unlimited) if neither is set.
"""
function _effective_max_output(tool_obj, agent)::Int
    per_tool = _max_output(tool_obj)
    per_tool > 0 && return per_tool
    return agent.max_tool_output
end
