###############################################################################
# storage/memory/in_memory.jl — in-memory memory backend
###############################################################################

"""
    InMemoryMemoryService()

In-memory memory backend using keyword search. Good for testing and short-lived
applications. All data is lost when the process exits.
"""
struct InMemoryMemoryService <: AbstractMemoryService
    entries::Dict{String,MemoryEntry}
    lock::ReentrantLock

    InMemoryMemoryService() = new(Dict{String,MemoryEntry}(), ReentrantLock())
end

function add_memory!(
    service::InMemoryMemoryService,
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
    lock(service.lock) do
        service.entries[entry.id] = entry
    end
    entry
end

function search_memory(
    service::InMemoryMemoryService,
    query::String;
    user_id::String="default",
    app_name::String="NimbleAgents",
    top_k::Int=5,
)
    candidates = lock(service.lock) do
        [e for e in values(service.entries) if e.user_id == user_id && e.app_name == app_name]
    end

    scored = [(e, _keyword_score(query, e.content)) for e in candidates]
    filter!(x -> x[2] > 0.0, scored)
    sort!(scored; by=x -> -x[2])

    [e for (e, _) in scored[1:min(top_k, length(scored))]]
end

function delete_memory!(service::InMemoryMemoryService, id::String)
    lock(service.lock) do
        delete!(service.entries, id)
    end
    nothing
end

function list_memories(
    service::InMemoryMemoryService;
    user_id::Union{String,Nothing}=nothing,
    app_name::Union{String,Nothing}=nothing,
)
    lock(service.lock) do
        entries = collect(values(service.entries))
        if !isnothing(user_id)
            filter!(e -> e.user_id == user_id, entries)
        end
        if !isnothing(app_name)
            filter!(e -> e.app_name == app_name, entries)
        end
        entries
    end
end

function close!(service::InMemoryMemoryService)
    nothing
end
