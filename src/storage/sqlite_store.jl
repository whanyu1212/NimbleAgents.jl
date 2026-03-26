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

include("sqlite_store/types.jl")
include("sqlite_store/schema.jl")
include("sqlite_store/helpers.jl")
include("sqlite_store/crud.jl")
include("sqlite_store/cleanup.jl")
