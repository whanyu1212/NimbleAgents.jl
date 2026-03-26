###############################################################################
# storage/artifacts/store_interface.jl — store abstraction and expiry helpers
###############################################################################

"""
    AbstractSessionStore

Interface for session persistence backends. Implement:
- `save!(store, session)`
- `load(store, session_id) -> Union{Session, Nothing}`
- `delete!(store, session_id)`
- `list(store; app_name, user_id) -> Vector{String}`
- `store_artifacts_dir(store) -> String`
"""
abstract type AbstractSessionStore end

"""
    save!(store, session) -> Session

Persist `session` into `store`.

# Arguments
- `store`: Session store backend.
- `session::Session`: Session to persist.

# Returns
- `Session`: The persisted session object.
"""
function save! end

"""
    load(store, session_id) -> Union{Session, Nothing}

Load a persisted session by id.

# Arguments
- `store`: Session store backend.
- `session_id::String`: Session identifier to load.

# Returns
- `Session`: Loaded session when found.
- `nothing`: If no persisted session exists for `session_id`.
"""
function load end

"""
    list(store; app_name=nothing, user_id=nothing) -> Vector{String}

List persisted session ids, optionally filtered by scope.

# Arguments
- `store`: Session store backend.
- `app_name::Union{String,Nothing}`: Optional application filter.
- `user_id::Union{String,Nothing}`: Optional user filter.

# Returns
- `Vector{String}`: Matching session ids.
"""
function list end

"""
    store_artifacts_dir(store) -> String

Return the directory where a session store persists artifact files.

# Arguments
- `store`: Session store backend.

# Returns
- `String`: Absolute or relative artifacts directory path.
"""
function store_artifacts_dir end

# Convert max_age / before kwargs into a cutoff timestamp.
function _resolve_cutoff(
    max_age::Union{Real,Nothing}, before::Union{Float64,Nothing}
)::Float64
    if !isnothing(max_age) && !isnothing(before)
        throw(ArgumentError("provide max_age or before, not both"))
    end
    if isnothing(max_age) && isnothing(before)
        throw(ArgumentError("provide max_age or before"))
    end
    !isnothing(before) ? before : time() - Float64(max_age)
end

"""
    cleanup!(store; max_age, before) -> Int

Delete expired sessions from the store and return the number removed.

# Arguments
- `store`: Session store backend.
- `max_age::Real`: Delete sessions not updated in the last `max_age` seconds.
- `before::Float64`: Delete sessions with `updated_at < before` (Unix timestamp).

Provide exactly one of the two keyword arguments.

# Returns
- `Int`: Number of sessions deleted.
"""
function cleanup! end
