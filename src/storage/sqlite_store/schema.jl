###############################################################################
# storage/sqlite_store/schema.jl — schema initialization
###############################################################################

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
