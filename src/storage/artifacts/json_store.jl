###############################################################################
# storage/artifacts/json_store.jl — JSON-backed session persistence backend
###############################################################################

"""
    JSONSessionStore(dir)

Persist sessions as JSON files in `dir`. Artifacts are copied into
`dir/../artifacts/<session_id>/`.

```julia
store = JSONSessionStore(".nimble/sessions")
save!(store, session)
session = load(store, session_id)
```
"""
struct JSONSessionStore <: AbstractSessionStore
    dir::String
    JSONSessionStore(dir::String) = (mkpath(dir); new(dir))
end

store_artifacts_dir(s::JSONSessionStore) = joinpath(dirname(s.dir), "artifacts")

"""
    save!(store::JSONSessionStore, session::Session)

Serialise session history, state, events, and artifacts to a JSON file.
Non-serialisable state values (REPL sandbox, open handles) are silently dropped.
"""
function save!(store::JSONSessionStore, session::Session)
    session.updated_at = time()
    path = joinpath(store.dir, session.id * ".json")
    data = Dict{String,Any}(
        "id" => session.id,
        "app_name" => session.app_name,
        "user_id" => session.user_id,
        "created_at" => session.created_at,
        "updated_at" => session.updated_at,
        "history" => _msg_to_dict.(session.history),
        "state" => _safe_state(session.state),
        "artifacts" => _artifact_to_dict.(session.artifacts),
    )
    write(path, JSON3.write(data))
    return session
end

"""
    load(store::JSONSessionStore, session_id::String) -> Session

Restore a session from disk. Returns `nothing` if not found.
"""
function load(store::JSONSessionStore, session_id::String)::Union{Session,Nothing}
    path = joinpath(store.dir, session_id * ".json")
    isfile(path) || return nothing

    data = JSON3.read(read(path, String), Dict{String,Any})

    history = AbstractMessage[_dict_to_msg(Dict{String,Any}(d)) for d in data["history"]]
    state = Dict{String,Any}(data["state"])
    artifacts = Artifact[_dict_to_artifact(Dict{String,Any}(a)) for a in data["artifacts"]]

    s = Session(; id=data["id"], app_name=data["app_name"], user_id=data["user_id"])
    s.created_at = get(data, "created_at", s.created_at)
    s.updated_at = get(data, "updated_at", s.created_at)
    append!(s.history, history)
    merge!(s.state, state)
    append!(s.artifacts, artifacts)
    s
end

"""
    delete!(store::JSONSessionStore, session_id::String)

Remove the session JSON file and its artifacts directory.
"""
function Base.delete!(store::JSONSessionStore, session_id::String)
    path = joinpath(store.dir, session_id * ".json")
    isfile(path) && rm(path)
    art_dir = joinpath(store_artifacts_dir(store), session_id)
    isdir(art_dir) && rm(art_dir; recursive=true)
    return nothing
end

"""
    list(store::JSONSessionStore; app_name, user_id) -> Vector{String}

Return all persisted session IDs, optionally filtered by `app_name` and/or `user_id`.
"""
function list(
    store::JSONSessionStore;
    app_name::Union{String,Nothing}=nothing,
    user_id::Union{String,Nothing}=nothing,
)::Vector{String}
    ids = String[]
    for f in readdir(store.dir)
        endswith(f, ".json") || continue
        if isnothing(app_name) && isnothing(user_id)
            push!(ids, splitext(f)[1])
        else
            # Peek at the header fields only — avoid loading full history
            path = joinpath(store.dir, f)
            data = try
                JSON3.read(read(path, String), Dict{String,Any})
            catch
                continue
            end
            (isnothing(app_name) || get(data, "app_name", "") == app_name) &&
                (isnothing(user_id) || get(data, "user_id", "") == user_id) &&
                push!(ids, splitext(f)[1])
        end
    end
    ids
end

function cleanup!(
    store::JSONSessionStore;
    max_age::Union{Real,Nothing}=nothing,
    before::Union{Float64,Nothing}=nothing,
)::Int
    cutoff = _resolve_cutoff(max_age, before)
    count = 0
    for f in readdir(store.dir)
        endswith(f, ".json") || continue
        path = joinpath(store.dir, f)
        data = try
            JSON3.read(read(path, String), Dict{String,Any})
        catch
            continue
        end
        updated = get(data, "updated_at", get(data, "created_at", Inf))
        if updated < cutoff
            session_id = splitext(f)[1]
            delete!(store, session_id)
            count += 1
        end
    end
    count
end
