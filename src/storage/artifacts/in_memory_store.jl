###############################################################################
# storage/artifacts/in_memory_store.jl — in-memory session persistence backend
###############################################################################

"""
    InMemorySessionStore()

An in-memory session store. Sessions are kept for the lifetime of the process
and lost on restart. Suitable as the default for `serve()` and for testing.

Artifacts are stored in a temp directory that is also ephemeral.

```julia
store   = InMemorySessionStore()
session = Session(app_name="MyApp", user_id="alice")
save!(store, session)
load(store, session.id)  # → same Session object
```
"""
struct InMemorySessionStore <: AbstractSessionStore
    sessions::Dict{String,Session}
    artifacts_dir::String
    InMemorySessionStore() = new(Dict{String,Session}(), mktempdir())
end

store_artifacts_dir(s::InMemorySessionStore) = s.artifacts_dir

# save! just upserts the session into the dict — the object is already live.
function save!(store::InMemorySessionStore, session::Session)
    session.updated_at = time()
    store.sessions[session.id] = session
    return session
end

function load(store::InMemorySessionStore, session_id::String)::Union{Session,Nothing}
    get(store.sessions, session_id, nothing)
end

function Base.delete!(store::InMemorySessionStore, session_id::String)
    delete!(store.sessions, session_id)
    art_dir = joinpath(store.artifacts_dir, session_id)
    isdir(art_dir) && rm(art_dir; recursive=true)
    return nothing
end

# list with optional filtering by app_name and/or user_id
function list(
    store::InMemorySessionStore;
    app_name::Union{String,Nothing}=nothing,
    user_id::Union{String,Nothing}=nothing,
)::Vector{String}
    [
        id for
        (id, s) in store.sessions if (isnothing(app_name) || s.app_name == app_name) &&
            (isnothing(user_id) || s.user_id == user_id)
    ]
end

function cleanup!(
    store::InMemorySessionStore;
    max_age::Union{Real,Nothing}=nothing,
    before::Union{Float64,Nothing}=nothing,
)::Int
    cutoff = _resolve_cutoff(max_age, before)
    expired = [id for (id, s) in store.sessions if s.updated_at < cutoff]
    for id in expired
        delete!(store, id)
    end
    length(expired)
end
