###############################################################################
# sqlite_memory.jl — SQLite-backed memory persistence
#
# Stores MemoryEntry records in a single SQLite database file.
# Follows the same patterns as SQLiteSessionStore: _collect_rows, UPSERT, close!.
#
# Usage:
#   mem = SQLiteMemoryService("memory.db")
#   add_memory!(mem, "User prefers dark mode"; user_id="alice", app_name="MyApp")
#   results = search_memory(mem, "dark mode"; user_id="alice", app_name="MyApp")
###############################################################################

using SQLite: SQLite
using DBInterface: DBInterface
using JSON3: JSON3

"""
    SQLiteMemoryService(path)

Persist memories in a SQLite database at `path`. The database and table
are created automatically on first use.

# Example
```julia
mem = SQLiteMemoryService("memory.db")
add_memory!(mem, "User prefers dark mode"; user_id="alice", app_name="MyApp")
results = search_memory(mem, "dark mode"; user_id="alice", app_name="MyApp")
close!(mem)
```
"""
struct SQLiteMemoryService <: AbstractMemoryService
    db::SQLite.DB

    function SQLiteMemoryService(path::String)
        dir = dirname(path)
        isempty(dir) || mkpath(dir)
        db = SQLite.DB(path)
        _init_memory_schema!(db)
        new(db)
    end
end

function _init_memory_schema!(db::SQLite.DB)
    DBInterface.execute(
        db,
        """
    CREATE TABLE IF NOT EXISTS memories (
        id                TEXT PRIMARY KEY,
        content           TEXT NOT NULL,
        user_id           TEXT NOT NULL,
        app_name          TEXT NOT NULL,
        metadata          TEXT NOT NULL DEFAULT '{}',
        source_session_id TEXT,
        created_at        REAL NOT NULL
    )
""",
    )
    DBInterface.execute(
        db,
        """
    CREATE INDEX IF NOT EXISTS idx_memories_user_app
    ON memories (user_id, app_name)
""",
    )
    nothing
end

function add_memory!(
    service::SQLiteMemoryService,
    content::String;
    user_id::String="default",
    app_name::String="NimbleAgents",
    metadata::Dict{String,Any}=Dict{String,Any}(),
    session_id::Union{String,Nothing}=nothing,
)
    entry = MemoryEntry(;
        content=content,
        user_id=user_id,
        app_name=app_name,
        metadata=metadata,
        source_session_id=session_id,
    )

    metadata_json = JSON3.write(metadata)

    DBInterface.execute(
        service.db,
        """
    INSERT INTO memories (id, content, user_id, app_name, metadata, source_session_id, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        content           = excluded.content,
        metadata          = excluded.metadata,
        source_session_id = excluded.source_session_id
""",
        (
            entry.id,
            entry.content,
            entry.user_id,
            entry.app_name,
            metadata_json,
            entry.source_session_id,
            entry.created_at,
        ),
    )

    entry
end

function search_memory(
    service::SQLiteMemoryService,
    query::String;
    user_id::String="default",
    app_name::String="NimbleAgents",
    top_k::Int=5,
)
    result = DBInterface.execute(
        service.db,
        "SELECT id, content, user_id, app_name, metadata, source_session_id, created_at FROM memories WHERE user_id = ? AND app_name = ?",
        (user_id, app_name),
    )

    rows = _collect_rows(result)
    isempty(rows) && return MemoryEntry[]

    scored = Tuple{MemoryEntry,Float64}[]
    for row in rows
        meta = Dict{String,Any}(JSON3.read(row.metadata, Dict{String,Any}))
        ssid = row.source_session_id === missing ? nothing : row.source_session_id
        entry = MemoryEntry(
            row.id, row.content, row.user_id, row.app_name, meta, ssid, row.created_at
        )
        score = _keyword_score(query, entry.content)
        score > 0.0 && push!(scored, (entry, score))
    end

    sort!(scored; by=x -> -x[2])
    [e for (e, _) in scored[1:min(top_k, length(scored))]]
end

function delete_memory!(service::SQLiteMemoryService, id::String)
    DBInterface.execute(service.db, "DELETE FROM memories WHERE id = ?", (id,))
    nothing
end

function list_memories(
    service::SQLiteMemoryService;
    user_id::Union{String,Nothing}=nothing,
    app_name::Union{String,Nothing}=nothing,
)
    if isnothing(user_id) && isnothing(app_name)
        result = DBInterface.execute(
            service.db,
            "SELECT id, content, user_id, app_name, metadata, source_session_id, created_at FROM memories",
        )
    elseif !isnothing(user_id) && !isnothing(app_name)
        result = DBInterface.execute(
            service.db,
            "SELECT id, content, user_id, app_name, metadata, source_session_id, created_at FROM memories WHERE user_id = ? AND app_name = ?",
            (user_id, app_name),
        )
    elseif !isnothing(user_id)
        result = DBInterface.execute(
            service.db,
            "SELECT id, content, user_id, app_name, metadata, source_session_id, created_at FROM memories WHERE user_id = ?",
            (user_id,),
        )
    else
        result = DBInterface.execute(
            service.db,
            "SELECT id, content, user_id, app_name, metadata, source_session_id, created_at FROM memories WHERE app_name = ?",
            (app_name,),
        )
    end

    rows = _collect_rows(result)
    entries = MemoryEntry[]
    for row in rows
        meta = Dict{String,Any}(JSON3.read(row.metadata, Dict{String,Any}))
        ssid = row.source_session_id === missing ? nothing : row.source_session_id
        push!(
            entries,
            MemoryEntry(
                row.id, row.content, row.user_id, row.app_name, meta, ssid, row.created_at
            ),
        )
    end
    entries
end

function close!(service::SQLiteMemoryService)
    SQLite.close(service.db)
    nothing
end
