###############################################################################
# builtins/filesystem/read.jl — read_file_tool
###############################################################################

"""
    read_file_tool

Built-in `NimbleTool` that reads file contents and returns them as a string.
"""
const read_file_tool = NimbleTool(;
    name="read_file",
    description="Read the contents of a file and return them as a string.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "path" => Dict{String,Any}(
                "type" => "string", "description" => "Path to the file to read."
            ),
        ),
        "required" => ["path"],
    ),
    callable=(path::String) -> begin
        isfile(path) || return "Error: file not found: $(path)"
        read(path, String)
    end,
)
