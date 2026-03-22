###############################################################################
# artifacts.jl — Artifact tracking and session persistence
#
# Artifacts are named, typed outputs an agent intentionally produces:
# files, plots, structured data, reports. Two registration mechanisms:
#
#   1. return_artifact=true on a tool (developer intent)
#   2. save_artifact_tool (agent/LLM intent)
#
# Sessions serialise to JSON via JSONSessionStore (pluggable).
###############################################################################

using JSON3: JSON3

# ── Artifact ──────────────────────────────────────────────────────────────────

"""
    Artifact(; session_id, name, type, content_type, path, metadata)

A named, typed output produced by an agent during a session.

# Fields
- `id::String`: UUID identifying this artifact.
- `session_id::String`: Session that produced this artifact.
- `name::String`: Human-readable label.
- `type::Symbol`: `:file`, `:plot`, `:data`, or `:text`.
- `content_type::String`: MIME type (`"image/png"`, `"text/csv"`, etc.).
- `path::String`: Path to the artifact file.
- `metadata::Dict{String,Any}`: Arbitrary extra info (source tool, size, etc.).
- `created_at::Float64`: `time()` when registered.
"""
struct Artifact
    id::String
    session_id::String
    name::String
    type::Symbol
    content_type::String
    path::String
    metadata::Dict{String,Any}
    created_at::Float64
end

function Artifact(;
    session_id::String,
    name::String,
    type::Symbol=:file,
    content_type::String="application/octet-stream",
    path::String,
    metadata::Dict{String,Any}=Dict{String,Any}(),
)
    Artifact(
        string(Base.UUID(rand(UInt128))),
        session_id,
        name,
        type,
        content_type,
        path,
        metadata,
        time(),
    )
end

# Infer MIME type from file extension
function _mime_for_path(path::String)::String
    ext = lowercase(splitext(path)[2])
    get(
        Dict(
            ".png" => "image/png",
            ".jpg" => "image/jpeg",
            ".jpeg" => "image/jpeg",
            ".svg" => "image/svg+xml",
            ".pdf" => "application/pdf",
            ".csv" => "text/csv",
            ".json" => "application/json",
            ".txt" => "text/plain",
            ".md" => "text/markdown",
            ".jl" => "text/x-julia",
            ".py" => "text/x-python",
            ".html" => "text/html",
        ),
        ext,
        "application/octet-stream",
    )
end

# Infer artifact type from MIME
function _type_for_mime(mime::String)::Symbol
    startswith(mime, "image/") && return :plot
    mime == "text/csv" && return :data
    mime == "application/json" && return :data
    startswith(mime, "text/") && return :text
    :file
end

# ── AbstractSessionStore ──────────────────────────────────────────────────────

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

# ── InMemorySessionStore ──────────────────────────────────────────────────────

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

# ── register_artifact! ────────────────────────────────────────────────────────

"""
    register_artifact!(session, path; name, store) -> Artifact

Register a file as an artifact in the session. If `store` is provided, the
file is copied into the artifact store directory; otherwise the original path
is recorded as-is.

Called automatically by `run!` for `return_artifact=true` tools, by
`eval_julia_tool` for saved plots, and by `save_artifact_tool`.
"""
function register_artifact!(
    session::Session,
    path::String;
    name::String=basename(path),
    store::Union{AbstractSessionStore,Nothing}=nothing,
    metadata::Dict{String,Any}=Dict{String,Any}(),
)::Artifact
    mime = _mime_for_path(path)
    art_type = _type_for_mime(mime)

    # Copy into artifact store if one is configured
    dest_path = if !isnothing(store) && isfile(path)
        dest_dir = joinpath(store_artifacts_dir(store), session.id)
        mkpath(dest_dir)
        art_id = string(Base.UUID(rand(UInt128)))
        dest = joinpath(dest_dir, art_id * splitext(path)[2])
        cp(path, dest; force=true)
        dest
    else
        path
    end

    artifact = Artifact(;
        session_id=session.id,
        name=name,
        type=art_type,
        content_type=mime,
        path=dest_path,
        metadata=metadata,
    )
    push!(session.artifacts, artifact)
    artifact
end

# ── JSONSessionStore ──────────────────────────────────────────────────────────

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

# ── Serialisation helpers ─────────────────────────────────────────────────────

# Convert a PT.AbstractMessage to a plain Dict for JSON serialisation.
function _msg_to_dict(msg::PT.AbstractMessage)::Dict{String,Any}
    type_name = string(nameof(typeof(msg)))
    d = Dict{String,Any}("_type" => type_name)
    # All message types have content
    d["content"] = msg.content
    # AIToolRequest has tool_calls
    if msg isa PT.AIToolRequest && !isnothing(msg.tool_calls)
        d["tool_calls"] = map(msg.tool_calls) do tc
            Dict{String,Any}(
                "id" => tc.id,
                "name" => tc.name,
                "args" => if isnothing(tc.args)
                    Dict{String,Any}()
                else
                    Dict{String,Any}(string(k) => v for (k, v) in tc.args)
                end,
            )
        end
    end
    # ToolMessage has name and tool_call_id
    if hasproperty(msg, :name)
        d["name"] = getproperty(msg, :name)
    end
    if hasproperty(msg, :tool_call_id)
        d["tool_call_id"] = getproperty(msg, :tool_call_id)
    end
    d
end

# Reconstruct a PT.AbstractMessage from a plain Dict.
function _dict_to_msg(d::Dict)::PT.AbstractMessage
    type_name = get(d, "_type", "UserMessage")
    content = get(d, "content", "")
    if type_name == "UserMessage"
        PT.UserMessage(content)
    elseif type_name == "AIMessage"
        PT.AIMessage(content)
    elseif type_name == "SystemMessage"
        PT.SystemMessage(content)
    elseif type_name == "AIToolRequest"
        tool_calls = map(get(d, "tool_calls", [])) do tc
            args = Dict{Symbol,Any}(Symbol(k) => v for (k, v) in tc["args"])
            PT.ToolCall(; id=get(tc, "id", ""), name=tc["name"], args=args)
        end
        PT.AIToolRequest(; tool_calls, content)
    elseif type_name == "ToolMessage"
        PT.ToolMessage(;
            content=content,
            raw=something(content, ""),
            name=get(d, "name", ""),
            tool_call_id=get(d, "tool_call_id", ""),
        )
    else
        PT.UserMessage(something(content, ""))
    end
end

# Serialise only JSON-safe state values — silently drop live Julia objects
# (sandbox modules, open handles, etc.)
function _safe_state(state::Dict{String,Any})::Dict{String,Any}
    result = Dict{String,Any}()
    for (k, v) in state
        k == "_julia_sandbox" && continue   # REPL sandbox — not serialisable
        try
            JSON3.write(v)   # test round-trip
            result[k] = v
        catch
            # silently skip non-serialisable values
        end
    end
    result
end

function _artifact_to_dict(a::Artifact)::Dict{String,Any}
    Dict{String,Any}(
        "id" => a.id,
        "session_id" => a.session_id,
        "name" => a.name,
        "type" => string(a.type),
        "content_type" => a.content_type,
        "path" => a.path,
        "metadata" => a.metadata,
        "created_at" => a.created_at,
    )
end

function _dict_to_artifact(d::Dict)::Artifact
    Artifact(
        d["id"],
        d["session_id"],
        d["name"],
        Symbol(d["type"]),
        d["content_type"],
        d["path"],
        Dict{String,Any}(d["metadata"]),
        d["created_at"],
    )
end

# ── save! / load / delete! / list ─────────────────────────────────────────────

"""
    save!(store::JSONSessionStore, session::Session)

Serialise session history, state, events, and artifacts to a JSON file.
Non-serialisable state values (REPL sandbox, open handles) are silently dropped.
"""
function save!(store::JSONSessionStore, session::Session)
    path = joinpath(store.dir, session.id * ".json")
    data = Dict{String,Any}(
        "id" => session.id,
        "app_name" => session.app_name,
        "user_id" => session.user_id,
        "created_at" => session.created_at,
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

    history = PT.AbstractMessage[_dict_to_msg(Dict{String,Any}(d)) for d in data["history"]]
    state = Dict{String,Any}(data["state"])
    artifacts = Artifact[_dict_to_artifact(Dict{String,Any}(a)) for a in data["artifacts"]]

    s = Session(; id=data["id"], app_name=data["app_name"], user_id=data["user_id"])
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
