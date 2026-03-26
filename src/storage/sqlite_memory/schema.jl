###############################################################################
# storage/sqlite_memory/schema.jl — schema initialization for memories
###############################################################################

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
