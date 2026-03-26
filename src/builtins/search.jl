###############################################################################
# builtins/search.jl — built-in search tools
###############################################################################

# ── grep_tool ──────────────────────────────────────────────────────────────────

"""
    grep_tool

Built-in `NimbleTool` that searches files/directories with a regular expression.
"""
const grep_tool = NimbleTool(;
    name="grep",
    description="Search for a regex pattern in a file or directory. Returns matching lines with file path and line number.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "pattern" => Dict{String,Any}(
                "type" => "string",
                "description" => "Regular expression pattern to search for.",
            ),
            "path" => Dict{String,Any}(
                "type" => "string",
                "description" => "File or directory to search in.",
            ),
            "case_sensitive" => Dict{String,Any}(
                "type" => "boolean",
                "description" => "Whether the search is case-sensitive. Default true.",
            ),
        ),
        "required" => ["pattern", "path"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        pattern = get(args, :pattern, "")
        path = get(args, :path, "")
        case_sensitive = get(args, :case_sensitive, true)
        (isfile(path) || isdir(path)) || return "Error: path not found: $(path)"
        rx = try
            case_sensitive ? Regex(pattern) : Regex(pattern, "i")
        catch e
            return "Error: invalid regex: $(sprint(showerror, e))"
        end
        matches = String[]
        _grep_path(rx, path, matches)
        isempty(matches) && return "No matches found for: $(pattern)"
        length(matches) > 200 &&
            push!(matches, "... ($(length(matches) - 200) more matches)")
        join(matches[1:min(200, end)], "\n")
    end,
)

function _grep_path(rx::Regex, path::String, matches::Vector{String})
    if isdir(path)
        for entry in readdir(path; join=true)
            _grep_path(rx, entry, matches)
        end
    elseif isfile(path)
        try
            for (i, line) in enumerate(eachline(path))
                !isnothing(match(rx, line)) && push!(matches, "$(path):$(i): $(line)")
            end
        catch
            # Skip binary or unreadable files
        end
    end
end

# ── find_files_tool ────────────────────────────────────────────────────────────

"""
    find_files_tool

Built-in `NimbleTool` that recursively finds file names matching a pattern.
"""
const find_files_tool = NimbleTool(;
    name="find_files",
    description="Find files whose names match a pattern (substring or regex) within a directory tree.",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "pattern" => Dict{String,Any}(
                "type" => "string",
                "description" => "Substring or regex to match against file names.",
            ),
            "base_dir" => Dict{String,Any}(
                "type" => "string",
                "description" => "Directory to search in (default: current directory).",
            ),
            "max_results" => Dict{String,Any}(
                "type" => "integer",
                "description" => "Maximum number of results to return (default: 50).",
            ),
        ),
        "required" => ["pattern"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        pattern = get(args, :pattern, "")
        base_dir = get(args, :base_dir, ".")
        max_results = get(args, :max_results, 50)
        isdir(base_dir) || return "Error: directory not found: $(base_dir)"
        rx = try
            Regex(pattern)
        catch
            ;
            Regex(replace(pattern, r"[.*+?^${}()|[\]\\]" => s"\\\0"))
        end
        results = String[]
        _find_walk(rx, base_dir, results, max_results)
        isempty(results) && return "No files found matching: $(pattern)"
        join(sort(results), "\n")
    end,
)

function _find_walk(rx::Regex, dir::String, results::Vector{String}, max::Int)
    length(results) >= max && return nothing
    for entry in readdir(dir; join=true)
        length(results) >= max && break
        !isnothing(match(rx, basename(entry))) && push!(results, entry)
        isdir(entry) && _find_walk(rx, entry, results, max)
    end
end
