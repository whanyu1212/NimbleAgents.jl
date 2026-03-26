###############################################################################
# storage/sqlite_memory/types.jl — SQLiteMemoryService type
###############################################################################

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
struct SQLiteMemoryService <: NimbleAgents.SQLiteMemoryService
    db::SQLite.DB

    function SQLiteMemoryService(path::String)
        dir = dirname(path)
        isempty(dir) || mkpath(dir)
        db = SQLite.DB(path)
        _init_memory_schema!(db)
        new(db)
    end
end
