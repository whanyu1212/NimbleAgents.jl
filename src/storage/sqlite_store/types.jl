###############################################################################
# storage/sqlite_store/types.jl — SQLiteSessionStore type and constructor
###############################################################################

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
struct SQLiteSessionStore <: NimbleAgents.SQLiteSessionStore
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
