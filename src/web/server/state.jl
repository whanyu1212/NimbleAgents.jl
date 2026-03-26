###############################################################################
# web/server/state.jl — server runtime state
###############################################################################

mutable struct RunState
    task::Union{Task,Nothing}
    approval_channel::Channel{String}
    event_channel::Channel{String}   # pre-serialised JSON SSE lines
    status::Symbol            # :running | :interrupted | :done | :error
    result::Union{String,Nothing}
    session_id::String
end

function RunState(session_id::String)
    RunState(
        nothing, Channel{String}(1), Channel{String}(256), :running, nothing, session_id
    )
end

const _runs = Dict{String,RunState}()
const _agents = Dict{String,Agent}()

# Active store — set by serve(), used by all handlers.
# Default: InMemorySessionStore (replaced on each serve() call).
const _store = Ref{AbstractSessionStore}(InMemorySessionStore())
