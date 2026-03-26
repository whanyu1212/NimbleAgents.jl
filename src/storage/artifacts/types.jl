###############################################################################
# storage/artifacts/types.jl — artifact model and MIME/type inference
###############################################################################

"""
    Artifact(; session_id, name, type, content_type, path, metadata)

A named, typed output produced by an agent during a session.

# Fields
- `id::String`: UUID identifying this artifact.
- `session_id::String`: Session that produced this artifact.
- `name::String`: Human-readable label.
- `type::Symbol`: `:file`, `:plot`, `:data`, or `:text`.
- `content_type::String`: MIME type (`"image/png"`, `"text/csv"`, etc.).
- `path::String`: Path to the artifact file.
- `metadata::Dict{String,Any}`: Arbitrary extra info (source tool, size, etc.).
- `created_at::Float64`: `time()` when registered.
"""
struct Artifact
    id::String
    session_id::String
    name::String
    type::Symbol
    content_type::String
    path::String
    metadata::Dict{String,Any}
    created_at::Float64
end

function Artifact(;
    session_id::String,
    name::String,
    type::Symbol=:file,
    content_type::String="application/octet-stream",
    path::String,
    metadata::Dict{String,Any}=Dict{String,Any}(),
)
    Artifact(
        string(Base.UUID(rand(UInt128))),
        session_id,
        name,
        type,
        content_type,
        path,
        metadata,
        time(),
    )
end

# Infer MIME type from file extension
function _mime_for_path(path::String)::String
    ext = lowercase(splitext(path)[2])
    get(
        Dict(
            ".png" => "image/png",
            ".jpg" => "image/jpeg",
            ".jpeg" => "image/jpeg",
            ".svg" => "image/svg+xml",
            ".pdf" => "application/pdf",
            ".csv" => "text/csv",
            ".json" => "application/json",
            ".txt" => "text/plain",
            ".md" => "text/markdown",
            ".jl" => "text/x-julia",
            ".py" => "text/x-python",
            ".html" => "text/html",
        ),
        ext,
        "application/octet-stream",
    )
end

# Infer artifact type from MIME
function _type_for_mime(mime::String)::Symbol
    startswith(mime, "image/") && return :plot
    mime == "text/csv" && return :data
    mime == "application/json" && return :data
    startswith(mime, "text/") && return :text
    :file
end
