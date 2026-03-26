###############################################################################
# storage/artifacts/register.jl — artifact registration entrypoint
###############################################################################

"""
    register_artifact!(session, path; name, store) -> Artifact

Register a file as an artifact in the session. If `store` is provided, the
file is copied into the artifact store directory; otherwise the original path
is recorded as-is.

Called automatically by `run!` for `return_artifact=true` tools, by
`eval_julia_tool` for saved plots, and by `save_artifact_tool`.
"""
function register_artifact!(
    session::Session,
    path::String;
    name::String=basename(path),
    store::Union{AbstractSessionStore,Nothing}=nothing,
    metadata::Dict{String,Any}=Dict{String,Any}(),
)::Artifact
    mime = _mime_for_path(path)
    art_type = _type_for_mime(mime)

    # Copy into artifact store if one is configured
    dest_path = if !isnothing(store) && isfile(path)
        dest_dir = joinpath(store_artifacts_dir(store), session.id)
        mkpath(dest_dir)
        art_id = string(Base.UUID(rand(UInt128)))
        dest = joinpath(dest_dir, art_id * splitext(path)[2])
        cp(path, dest; force=true)
        dest
    else
        path
    end

    artifact = Artifact(;
        session_id=session.id,
        name=name,
        type=art_type,
        content_type=mime,
        path=dest_path,
        metadata=metadata,
    )
    push!(session.artifacts, artifact)
    artifact
end
