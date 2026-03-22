###############################################################################
# memory.jl — Semantic / long-term memory (cross-session fact storage)
#
# Agents can store and retrieve facts across sessions, scoped by user_id and
# app_name. Two backends: InMemoryMemoryService (keyword search, zero deps)
# and SQLiteMemoryService (persistent, in sqlite_memory.jl).
#
# Usage:
#   mem = InMemoryMemoryService()
#   agent = Agent(name="Bot", instructions="...", memory=mem)
#   session = Session(app_name="MyApp", user_id="alice")
#   run!(agent, "Remember that I prefer dark mode"; session=session)
###############################################################################

# ── MemoryEntry ──────────────────────────────────────────────────────────────

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

# ── AbstractMemoryService ────────────────────────────────────────────────────

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

# ── Keyword scoring ──────────────────────────────────────────────────────────

# Tokenize into lowercase words, stripping punctuation.
function _tokenize(text::String)::Vector{String}
    words = split(lowercase(text))
    [replace(w, r"[^\w]" => "") for w in words if !isempty(replace(w, r"[^\w]" => ""))]
end

"""
    _keyword_score(query, content) -> Float64

Score how well `content` matches `query` using keyword overlap + substring boost.
Returns a value in [0, 1].
"""
function _keyword_score(query::String, content::String)::Float64
    query_words = _tokenize(query)
    isempty(query_words) && return 0.0

    content_lower = lowercase(content)
    content_words = Set(_tokenize(content))

    # Word overlap
    hits = count(w -> w in content_words, query_words)
    score = hits / length(query_words)

    # Exact substring boost
    if occursin(lowercase(query), content_lower)
        score = min(score + 0.3, 1.0)
    end

    clamp(score, 0.0, 1.0)
end

# ── InMemoryMemoryService ────────────────────────────────────────────────────

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

# ── System prompt injection ──────────────────────────────────────────────────

"""
    _memory_prompt(memory, input, session) -> String

Build a system prompt fragment with relevant memories for the current input.
Returns `""` if memory is nothing, session is nothing, or no results are found.
"""
function _memory_prompt(
    memory::Union{AbstractMemoryService,Nothing},
    input::String,
    session::Union{Session,Nothing},
)
    isnothing(memory) && return ""
    isnothing(session) && return ""

    results = search_memory(
        memory, input; user_id=session.user_id, app_name=session.app_name
    )
    isempty(results) && return ""

    lines = String[
        "",
        "---",
        "## Relevant Memories",
        "",
        "The following facts were recalled from previous interactions with this user:",
        "",
    ]
    for (i, entry) in enumerate(results)
        push!(lines, "$(i). $(entry.content)")
    end
    push!(lines, "")
    join(lines, "\n")
end
