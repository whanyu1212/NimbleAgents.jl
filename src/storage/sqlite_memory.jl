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

include("sqlite_memory/types.jl")
include("sqlite_memory/schema.jl")
include("sqlite_memory/crud.jl")
