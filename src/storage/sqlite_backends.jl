###############################################################################
# sqlite_backends.jl — optional SQLite backends loaded via package extension
###############################################################################

"""
    SQLiteSessionStore(path; artifacts_dir=nothing)

SQLite-backed `AbstractSessionStore` implementation, loaded via
`NimbleAgentsSQLiteExt` when `SQLite.jl` and `DBInterface.jl` are available.
"""
abstract type SQLiteSessionStore <: AbstractSessionStore end

"""
    SQLiteMemoryService(path)

SQLite-backed `AbstractMemoryService` implementation, loaded via
`NimbleAgentsSQLiteExt` when `SQLite.jl` and `DBInterface.jl` are available.
"""
abstract type SQLiteMemoryService <: AbstractMemoryService end

function _require_sqlite_ext()
    ext = Base.get_extension(NimbleAgents, :NimbleAgentsSQLiteExt)
    !isnothing(ext) && return ext
    throw(
        ArgumentError(
            "SQLite backends are optional. Add SQLite.jl and DBInterface.jl to your environment, `using SQLite`, then call SQLiteSessionStore/SQLiteMemoryService.",
        ),
    )
end

function (::Type{SQLiteSessionStore})(
    path::AbstractString; artifacts_dir::Union{AbstractString,Nothing}=nothing
)
    ext = _require_sqlite_ext()
    ext.SQLiteSessionStore(
        String(path);
        artifacts_dir=isnothing(artifacts_dir) ? nothing : String(artifacts_dir),
    )
end

function (::Type{SQLiteMemoryService})(path::AbstractString)
    ext = _require_sqlite_ext()
    ext.SQLiteMemoryService(String(path))
end
