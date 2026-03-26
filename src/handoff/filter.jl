###############################################################################
# handoff/filter.jl — history filtering for handoff transitions
###############################################################################

"""
    HandoffFilter

Controls how conversation history is transformed when handing off to the next
agent. Pass a `HandoffFilter` to `handoff_tool` or `run_pipeline!` to filter
the session history before the receiving agent sees it.

# Built-in filters (symbols)
- `:all`          — pass full history unchanged (default)
- `:none`         — clear history; receiving agent starts fresh
- `:strip_tools`  — remove all tool-call and tool-result messages
- `:last_n`       — keep only the last N messages (use `HandoffFilter(:last_n, 5)`)

# Custom filter (function)
Pass a function `(history::Vector{AbstractMessage}) -> Vector{AbstractMessage}`
for full control over what the receiving agent sees.

# Examples
```julia
# Strip tool messages on handoff
handoff_tool(billing; history_filter = HandoffFilter(:strip_tools))

# Keep only last 3 messages
handoff_tool(billing; history_filter = HandoffFilter(:last_n, 3))

# Custom function
handoff_tool(billing; history_filter = HandoffFilter(msgs -> filter(m -> m isa UserMessage, msgs)))
```
"""
struct HandoffFilter
    kind::Symbol
    n::Int
    func::Union{Function,Nothing}
end

HandoffFilter() = HandoffFilter(:all, 0, nothing)
HandoffFilter(kind::Symbol) = HandoffFilter(kind, 0, nothing)
HandoffFilter(kind::Symbol, n::Int) = HandoffFilter(kind, n, nothing)
HandoffFilter(f::Function) = HandoffFilter(:custom, 0, f)

function _apply_handoff_filter(filter::HandoffFilter, history::Vector{<:AbstractMessage})
    kind = filter.kind
    kind == :all && return history

    if kind == :none
        return AbstractMessage[]
    elseif kind == :strip_tools
        return AbstractMessage[
            m for m in history if !(m isa ToolMessage || m isa AIToolRequest)
        ]
    elseif kind == :last_n
        n = max(filter.n, 0)
        return n >= length(history) ? history : history[(end - n + 1):end]
    elseif kind == :custom && !isnothing(filter.func)
        return filter.func(history)
    else
        return history
    end
end
