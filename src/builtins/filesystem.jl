###############################################################################
# builtins/filesystem.jl — built-in file system tools
###############################################################################

# ── read_file_tool ─────────────────────────────────────────────────────────────

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

# ── write_file_tool ────────────────────────────────────────────────────────────

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

# ── edit_file_tool ─────────────────────────────────────────────────────────────

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

# ── list_dir_tool ──────────────────────────────────────────────────────────────

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
                    "$(round(sz/1024, digits=1)) KB"
                else
                    "$(round(sz/1024^2, digits=1)) MB"
                end
                "  $(basename(entry))  ($(sz_str))"
            end
        end
        join(lines, "\n")
    end,
)

# ── glob_tool ──────────────────────────────────────────────────────────────────

const glob_tool = NimbleTool(;
    name="glob",
    description="Find files matching a glob pattern. Use ** for recursive matching.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "pattern" => Dict{String,Any}(
                "type" => "string",
                "description" => "Glob pattern, e.g. 'src/**/*.jl' or '*.md'.",
            ),
            "base_dir" => Dict{String,Any}(
                "type" => "string",
                "description" => "Base directory to search from. Defaults to current directory.",
            ),
        ),
        "required" => ["pattern"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        pattern = get(args, :pattern, "")
        base_dir = get(args, :base_dir, ".")
        isdir(base_dir) || return "Error: directory not found: $(base_dir)"
        results = String[]
        _glob_walk(base_dir, pattern, results)
        isempty(results) && return "No files matched: $(pattern)"
        join(sort(results), "\n")
    end,
)

# Simple recursive glob implementation (handles ** and * wildcards)
function _glob_walk(dir::String, pattern::String, results::Vector{String})
    # Split pattern into first segment and rest
    parts = split(pattern, r"[/\\]"; limit=2)
    seg = String(parts[1])
    rest = length(parts) > 1 ? String(parts[2]) : ""

    isdir(dir) || return nothing

    if seg == "**"
        # ** matches zero or more path segments.
        # Zero-segment case: treat rest as the pattern for the current dir.
        isempty(rest) || _glob_walk(dir, rest, results)
        # One-or-more-segments case: descend into each subdir with ** still active.
        for entry in readdir(dir; join=true)
            if isempty(rest)
                push!(results, entry)
            end
            isdir(entry) && _glob_walk(entry, pattern, results)
        end
        return nothing
    end

    for entry in readdir(dir; join=true)
        name = basename(entry)
        if _glob_match(seg, name)
            if isempty(rest)
                push!(results, entry)
            elseif isdir(entry)
                _glob_walk(entry, rest, results)
            end
        end
    end
end

# Match a single glob segment (* wildcard only) against a filename
function _glob_match(pattern::String, name::String)::Bool
    pattern == "*" && return true
    pattern == name && return true
    # Convert glob pattern to regex: escape special chars, replace * with .*
    escaped = replace(pattern, r"([.+^${}()|\\])" => s"\\\1")
    rx = replace(escaped, "*" => ".*")
    !isnothing(match(Regex("^$(rx)\$"), name))
end

# ── delete_file_tool ───────────────────────────────────────────────────────────

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
