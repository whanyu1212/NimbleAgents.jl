###############################################################################
# storage/memory/types.jl — memory types and backend API contracts
###############################################################################

"""
    MemoryEntry(; content, user_id, app_name, metadata, source_session_id)

A single stored fact in the memory system.

# Fields
- `id::String`: Unique identifier (auto-generated UUID).
- `content::String`: The fact text.
- `user_id::String`: User who owns this memory.
- `app_name::String`: Application scope.
- `metadata::Dict{String,Any}`: Arbitrary key-value metadata.
- `source_session_id::Union{String,Nothing}`: Session that created this memory.
- `created_at::Float64`: `time()` when the memory was created.
"""
struct MemoryEntry
    id::String
    content::String
    user_id::String
    app_name::String
    metadata::Dict{String,Any}
    source_session_id::Union{String,Nothing}
    created_at::Float64
end

function MemoryEntry(;
    content::String,
    user_id::String,
    app_name::String,
    metadata::Dict{String,Any}=Dict{String,Any}(),
    source_session_id::Union{String,Nothing}=nothing,
    id::String=string(Base.UUID(rand(UInt128))),
    created_at::Float64=time(),
)
    MemoryEntry(id, content, user_id, app_name, metadata, source_session_id, created_at)
end

"""
    AbstractMemoryService

Abstract type for memory backends. Implementations must define:
- `add_memory!(service, content; user_id, app_name, metadata, session_id) -> MemoryEntry`
- `search_memory(service, query; user_id, app_name, top_k) -> Vector{MemoryEntry}`
- `delete_memory!(service, id)`
- `list_memories(service; user_id, app_name) -> Vector{MemoryEntry}`
- `close!(service)`
"""
abstract type AbstractMemoryService end

"""
    add_memory!(service, content; user_id="default", app_name="NimbleAgents", metadata=Dict{String,Any}(), session_id=nothing) -> MemoryEntry

Store a memory entry for a user/application scope.
"""
function add_memory! end

"""
    search_memory(service, query; user_id="default", app_name="NimbleAgents", top_k=5) -> Vector{MemoryEntry}

Return the top matching memories for `query` in the given scope.
"""
function search_memory end

"""
    delete_memory!(service, id)

Delete a memory entry by id.
"""
function delete_memory! end

"""
    list_memories(service; user_id=nothing, app_name=nothing) -> Vector{MemoryEntry}

List memories, optionally filtered by user and/or app.
"""
function list_memories end
