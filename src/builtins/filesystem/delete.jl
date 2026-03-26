###############################################################################
# builtins/filesystem/delete.jl — delete_file_tool
###############################################################################

"""
    delete_file_tool

Built-in `NimbleTool` that permanently deletes a file path.
"""
const delete_file_tool = NimbleTool(;
    name="delete_file",
    description="Permanently delete a file. This action cannot be undone.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "path" => Dict{String,Any}(
                "type" => "string", "description" => "Path to the file to delete."
            ),
        ),
        "required" => ["path"],
    ),
    callable=(path::String) -> begin
        isfile(path) || return "Error: file not found: $(path)"
        rm(path)
        "Deleted: $(path)"
    end,
)
