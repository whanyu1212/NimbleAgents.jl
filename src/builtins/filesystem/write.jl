###############################################################################
# builtins/filesystem/write.jl — write_file_tool
###############################################################################

"""
    write_file_tool

Built-in `NimbleTool` that writes text to a file, creating parent directories
when needed.
"""
const write_file_tool = NimbleTool(;
    name="write_file",
    description="Write content to a file, creating it if it does not exist and overwriting if it does.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "path" => Dict{String,Any}(
                "type" => "string", "description" => "Path to the file to write."
            ),
            "content" => Dict{String,Any}(
                "type" => "string", "description" => "Content to write to the file."
            ),
        ),
        "required" => ["path", "content"],
    ),
    callable=(path::String, content::String) -> begin
        dir = dirname(path)
        isempty(dir) || mkpath(dir)
        write(path, content)
        "Written $(length(content)) bytes to $(path)."
    end,
)
