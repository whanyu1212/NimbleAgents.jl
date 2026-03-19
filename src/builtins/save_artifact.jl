###############################################################################
# builtins/save_artifact.jl — agent-initiated artifact registration
###############################################################################

const save_artifact_tool = NimbleTool(
    name        = "save_artifact",
    description = """Register a file as a named artifact in the current session.
Use this when you have produced a file (report, chart, dataset, generated code)
that is worth keeping as a final deliverable — not for temporary or intermediate files.

The file must already exist on disk. It will be copied into the artifact store
and associated with this session.""",
    parameters  = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "path" => Dict{String,Any}(
                "type"        => "string",
                "description" => "Path to the file to register as an artifact.",
            ),
            "name" => Dict{String,Any}(
                "type"        => "string",
                "description" => "Human-readable name for the artifact.",
            ),
        ),
        "required" => ["path", "name"],
    ),
    callable = (path::String, name::String) -> begin
        isfile(path) || return "Error: file not found: $(path)"

        # Retrieve session and store from task-local storage
        session = get(task_local_storage(), :_current_session, nothing)
        store   = get(task_local_storage(), :_current_store,   nothing)

        isnothing(session) &&
            return "Error: no active session — pass a Session to run! to use artifacts."

        artifact = register_artifact!(session, path;
            name  = name,
            store = store,
            metadata = Dict{String,Any}("registered_by" => "agent"),
        )
        "Artifact registered: $(artifact.name) ($(artifact.id)) at $(artifact.path)"
    end,
)
