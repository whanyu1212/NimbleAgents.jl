###############################################################################
# storage/sqlite_store/crud.jl — save/load/list/delete/close for sessions
###############################################################################

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

function load(store::SQLiteSessionStore, session_id::String)::Union{Session,Nothing}
    result = DBInterface.execute(
        store.db,
        "SELECT id, app_name, user_id, created_at, updated_at, history, state, artifacts FROM sessions WHERE id = ?",
        (session_id,),
    )

    rows = _collect_rows(result)
    isempty(rows) && return nothing
    row = rows[1]

    history = NimbleAgents.AbstractMessage[
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

function Base.delete!(store::SQLiteSessionStore, session_id::String)
    DBInterface.execute(store.db, "DELETE FROM sessions WHERE id = ?", (session_id,))
    art_dir = joinpath(store.artifacts_dir, session_id)
    isdir(art_dir) && rm(art_dir; recursive=true)
    return nothing
end

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

"""
    close!(store::SQLiteSessionStore)

Close the underlying database connection. The store should not be used after this.
"""
function close!(store::SQLiteSessionStore)
    SQLite.close(store.db)
    nothing
end
