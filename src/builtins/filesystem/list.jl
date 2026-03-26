###############################################################################
# builtins/filesystem/list.jl — list_dir_tool
###############################################################################

"""
    list_dir_tool

Built-in `NimbleTool` that lists directory entries with basic type/size hints.
"""
const list_dir_tool = NimbleTool(;
    name="list_dir",
    description="List the contents of a directory, showing names, types, and sizes.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "path" => Dict{String,Any}(
                "type" => "string",
                "description" => "Path to the directory to list. Defaults to current directory.",
            ),
        ),
        "required" => ["path"],
    ),
    callable=(path::String) -> begin
        isdir(path) || return "Error: directory not found: $(path)"
        entries = readdir(path; join=true)
        isempty(entries) && return "(empty directory)"
        lines = map(entries) do entry
            if isdir(entry)
                "  $(basename(entry))/"
            else
                sz = filesize(entry)
                sz_str = if sz < 1024
                    "$(sz) B"
                elseif sz < 1024^2
                    "$(round(sz / 1024, digits=1)) KB"
                else
                    "$(round(sz / 1024^2, digits=1)) MB"
                end
                "  $(basename(entry))  ($(sz_str))"
            end
        end
        join(lines, "\n")
    end,
)
