###############################################################################
# storage/sqlite_store/cleanup.jl — TTL cleanup for persisted sessions
###############################################################################

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
