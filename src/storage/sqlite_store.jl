###############################################################################
# sqlite_store.jl — SQLite-backed session persistence
#
# Stores sessions, events, and artifacts in a single SQLite database file.
# Zero setup — just point at a file path and go.
#
# Usage:
#   store = SQLiteSessionStore("myapp.db")
#   save!(store, session)
#   session = load(store, session_id)
###############################################################################

using SQLite: SQLite
using DBInterface: DBInterface
using JSON3: JSON3

"""
    SQLiteSessionStore(path; artifacts_dir)

Persist sessions in a SQLite database at `path`. The database and tables
are created automatically on first use.

Artifacts are stored in `artifacts_dir` (defaults to a sibling `artifacts/`
directory next to the database file).

# Example
```julia
store = SQLiteSessionStore("sessions.db")
session = Session(app_name="MyApp", user_id="alice")
run!(agent, "Hello"; session, store)

# Later — restore the session
session = load(store, session.id)
```
"""
struct SQLiteSessionStore <: AbstractSessionStore
    db::SQLite.DB
    artifacts_dir::String

    function SQLiteSessionStore(path::String; artifacts_dir::Union{String,Nothing}=nothing)
        dir = dirname(path)
        isempty(dir) || mkpath(dir)
        db = SQLite.DB(path)

        art_dir = something(artifacts_dir, joinpath(dirname(abspath(path)), "artifacts"))
        mkpath(art_dir)

        _init_schema!(db)
        new(db, art_dir)
    end
end

store_artifacts_dir(s::SQLiteSessionStore) = s.artifacts_dir

# ── Schema ────────────────────────────────────────────────────────────────────

function _init_schema!(db::SQLite.DB)
    DBInterface.execute(
        db,
        """
    CREATE TABLE IF NOT EXISTS sessions (
        id         TEXT PRIMARY KEY,
        app_name   TEXT NOT NULL,
        user_id    TEXT NOT NULL,
        created_at REAL NOT NULL,
        history    TEXT NOT NULL DEFAULT '[]',
        state      TEXT NOT NULL DEFAULT '{}',
        artifacts  TEXT NOT NULL DEFAULT '[]',
        updated_at REAL NOT NULL
    )
""",
    )
    DBInterface.execute(
        db,
        """
    CREATE INDEX IF NOT EXISTS idx_sessions_app_user
    ON sessions (app_name, user_id)
""",
    )
    nothing
end

# ── helpers ───────────────────────────────────────────────────────────────────

# SQLite.jl 1.8 Row objects become stale after the query iterator advances,
# so `collect(result)` yields rows whose fields are all `missing`.
# Work around this by materialising each row into a NamedTuple during iteration.
function _collect_rows(result)
    rows = NamedTuple[]
    for row in result
        names = propertynames(row)
        vals = Tuple(getproperty(row, n) for n in names)
        push!(rows, NamedTuple{Tuple(names)}(vals))
    end
    rows
end

# ── save! ─────────────────────────────────────────────────────────────────────

function save!(store::SQLiteSessionStore, session::Session)
    session.updated_at = time()
    history_json = JSON3.write(_msg_to_dict.(session.history))
    state_json = JSON3.write(_safe_state(session.state))
    artifacts_json = JSON3.write(_artifact_to_dict.(session.artifacts))

    DBInterface.execute(
        store.db,
        """
    INSERT INTO sessions (id, app_name, user_id, created_at, history, state, artifacts, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        history    = excluded.history,
        state      = excluded.state,
        artifacts  = excluded.artifacts,
        updated_at = excluded.updated_at
""",
        (
            session.id,
            session.app_name,
            session.user_id,
            session.created_at,
            history_json,
            state_json,
            artifacts_json,
            session.updated_at,
        ),
    )

    return session
end

# ── load ──────────────────────────────────────────────────────────────────────

function load(store::SQLiteSessionStore, session_id::String)::Union{Session,Nothing}
    result = DBInterface.execute(
        store.db,
        "SELECT id, app_name, user_id, created_at, updated_at, history, state, artifacts FROM sessions WHERE id = ?",
        (session_id,),
    )

    rows = _collect_rows(result)
    isempty(rows) && return nothing
    row = rows[1]

    history = PT.AbstractMessage[
        _dict_to_msg(Dict{String,Any}(d)) for
        d in JSON3.read(row.history, Vector{Dict{String,Any}})
    ]
    state = Dict{String,Any}(JSON3.read(row.state, Dict{String,Any}))
    artifacts = Artifact[
        _dict_to_artifact(Dict{String,Any}(a)) for
        a in JSON3.read(row.artifacts, Vector{Dict{String,Any}})
    ]

    s = Session(; id=row.id, app_name=row.app_name, user_id=row.user_id)
    s.created_at = row.created_at
    s.updated_at = row.updated_at
    append!(s.history, history)
    merge!(s.state, state)
    append!(s.artifacts, artifacts)
    s
end

# ── delete! ───────────────────────────────────────────────────────────────────

function Base.delete!(store::SQLiteSessionStore, session_id::String)
    DBInterface.execute(store.db, "DELETE FROM sessions WHERE id = ?", (session_id,))
    art_dir = joinpath(store.artifacts_dir, session_id)
    isdir(art_dir) && rm(art_dir; recursive=true)
    return nothing
end

# ── list ──────────────────────────────────────────────────────────────────────

function list(
    store::SQLiteSessionStore;
    app_name::Union{String,Nothing}=nothing,
    user_id::Union{String,Nothing}=nothing,
)::Vector{String}
    if isnothing(app_name) && isnothing(user_id)
        result = DBInterface.execute(store.db, "SELECT id FROM sessions")
    elseif !isnothing(app_name) && !isnothing(user_id)
        result = DBInterface.execute(
            store.db,
            "SELECT id FROM sessions WHERE app_name = ? AND user_id = ?",
            (app_name, user_id),
        )
    elseif !isnothing(app_name)
        result = DBInterface.execute(
            store.db, "SELECT id FROM sessions WHERE app_name = ?", (app_name,)
        )
    else
        result = DBInterface.execute(
            store.db, "SELECT id FROM sessions WHERE user_id = ?", (user_id,)
        )
    end
    [row.id for row in _collect_rows(result)]
end

# ── cleanup! ──────────────────────────────────────────────────────────────────

function cleanup!(
    store::SQLiteSessionStore;
    max_age::Union{Real,Nothing}=nothing,
    before::Union{Float64,Nothing}=nothing,
)::Int
    cutoff = _resolve_cutoff(max_age, before)

    # Get IDs of expired sessions so we can also clean up artifact dirs
    result = DBInterface.execute(
        store.db, "SELECT id FROM sessions WHERE updated_at < ?", (cutoff,)
    )
    expired_ids = [row.id for row in _collect_rows(result)]

    if !isempty(expired_ids)
        DBInterface.execute(
            store.db, "DELETE FROM sessions WHERE updated_at < ?", (cutoff,)
        )
        for id in expired_ids
            art_dir = joinpath(store.artifacts_dir, id)
            isdir(art_dir) && rm(art_dir; recursive=true)
        end
    end

    length(expired_ids)
end

# ── close! ────────────────────────────────────────────────────────────────────

"""
    close!(store::SQLiteSessionStore)

Close the underlying database connection. The store should not be used after this.
"""
function close!(store::SQLiteSessionStore)
    SQLite.close(store.db)
    nothing
end
