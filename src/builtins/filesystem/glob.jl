###############################################################################
# builtins/filesystem/glob.jl — glob_tool and helpers
###############################################################################

"""
    glob_tool

Built-in `NimbleTool` that finds files matching glob patterns, including `**`.
"""
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
