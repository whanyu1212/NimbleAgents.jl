###############################################################################
# builtins/filesystem/edit.jl — edit_file_tool
###############################################################################

"""
    edit_file_tool

Built-in `NimbleTool` that replaces one exact string match in a file.
"""
const edit_file_tool = NimbleTool(;
    name="edit_file",
    description="""Replace an exact string in a file with new content.
The `old_str` must match exactly (including whitespace and indentation).
Returns an error if the string is not found or matches more than once.""",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "path" => Dict{String,Any}(
                "type" => "string", "description" => "Path to the file to edit."
            ),
            "old_str" => Dict{String,Any}(
                "type" => "string",
                "description" => "Exact string to replace. Must appear exactly once in the file.",
            ),
            "new_str" => Dict{String,Any}(
                "type" => "string", "description" => "Replacement string."
            ),
        ),
        "required" => ["path", "old_str", "new_str"],
    ),
    callable=(path::String, old_str::String, new_str::String) -> begin
        isfile(path) || return "Error: file not found: $(path)"
        content = read(path, String)
        n = count(old_str, content)
        n == 0 && return "Error: string not found in $(path)."
        n > 1 &&
            return "Error: string found $(n) times in $(path) — must match exactly once."
        write(path, replace(content, old_str => new_str; count=1))
        "Edit applied to $(path)."
    end,
)
