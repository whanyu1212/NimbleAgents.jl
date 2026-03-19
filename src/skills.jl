###############################################################################
# skills.jl — filesystem-based Skill packages
#
# A Skill is a directory containing:
#   SKILL.md        — YAML frontmatter (name, description) + instruction body
#   *.md            — optional additional reference files
#   scripts/        — optional bundled scripts
#
# Agents discover skills at startup (metadata only, ~0 tokens), then load
# the full SKILL.md body on demand via the built-in read_skill tool.
###############################################################################

# ── Skill struct ──────────────────────────────────────────────────────────────

"""
    Skill(; name, description, path)

A filesystem-based capability package. Contains a `SKILL.md` file with
instructions that the agent can load on demand.

Use `discover_skills(dirs)` to auto-discover skills from directories, or
construct directly with an explicit `path`.

# Fields
- `name::String`: Skill identifier (from YAML frontmatter).
- `description::String`: One-line description used in the agent's system prompt
  to help it decide when to load this skill.
- `path::String`: Absolute path to the skill directory.
"""
struct Skill
    name        ::String
    description ::String
    path        ::String
end

# ── YAML frontmatter parser ───────────────────────────────────────────────────

# Minimal parser for SKILL.md frontmatter. Handles only the two required fields
# (name, description) without a YAML dependency.
#
# Expected format:
#   ---
#   name: my-skill
#   description: What this skill does and when to use it.
#   ---
#
# Multi-line description values are joined into a single string.

function _parse_frontmatter(content::String)
    # Must start with ---
    startswith(content, "---") || return nothing

    # Find closing ---
    rest  = content[4:end]
    close = findfirst(r"\n---(\n|$)", rest)
    isnothing(close) && return nothing

    fm_text = rest[1:first(close)-1]

    name        = ""
    description = ""
    current_key = ""
    desc_lines  = String[]

    for line in split(fm_text, "\n")
        # New key: name or description
        m = match(r"^(name|description):\s*(.*)", line)
        if !isnothing(m)
            # Flush previous multi-line description
            if current_key == "description" && !isempty(desc_lines)
                description = join(desc_lines, " ")
                empty!(desc_lines)
            end
            current_key = m.captures[1]
            val = strip(m.captures[2])
            if current_key == "name"
                name = val
            else
                isempty(val) || push!(desc_lines, val)
            end
        elseif current_key == "description" && startswith(line, "  ")
            # Continuation line (indented)
            push!(desc_lines, strip(line))
        end
    end

    # Flush trailing description lines
    if current_key == "description" && !isempty(desc_lines)
        description = join(desc_lines, " ")
    end

    (isempty(name) || isempty(description)) && return nothing
    (name = name, description = description)
end

# Return the body of SKILL.md (everything after the closing ---)
function _skill_body(content::String)
    m = match(r"^---.*?---\s*\n?"s, content)
    isnothing(m) && return content
    content[length(m.match) + 1:end]
end

# ── Discovery ─────────────────────────────────────────────────────────────────

"""
    discover_skills(dirs::Vector{String}) -> Vector{Skill}

Scan each directory in `dirs` for skill subdirectories. A valid skill directory
must contain a `SKILL.md` file with `name` and `description` frontmatter.

Returns all discovered skills. Silently skips directories with missing or
malformed `SKILL.md` files.

# Example
```julia
skills = discover_skills([".nimble/skills", joinpath(homedir(), ".nimble", "skills")])
```
"""
function discover_skills(dirs::Vector{String})
    skills = Skill[]
    for dir in dirs
        isdir(dir) || continue
        for entry in readdir(dir; join=true)
            isdir(entry) || continue
            skill_md = joinpath(entry, "SKILL.md")
            isfile(skill_md) || continue
            content = read(skill_md, String)
            fm = _parse_frontmatter(content)
            isnothing(fm) && continue
            push!(skills, Skill(fm.name, fm.description, entry))
        end
    end
    skills
end

discover_skills(dir::String) = discover_skills([dir])

# ── System prompt injection ───────────────────────────────────────────────────

# Appends a compact skill registry to the agent's system prompt.
# Only metadata (name + description) is included — no token cost for unused skills.
function _skills_prompt(skills::Vector{Skill})
    isempty(skills) && return ""
    lines = String[
        "",
        "---",
        "## Available Skills",
        "",
        "You have access to the following skills. Use the `read_skill` tool to load",
        "a skill's full instructions when it is relevant to the current task.",
        "",
    ]
    for s in skills
        push!(lines, "- **$(s.name)**: $(s.description)")
    end
    push!(lines, "")
    join(lines, "\n")
end

# ── Built-in read_skill tool ──────────────────────────────────────────────────

# Builds a NimbleTool that loads SKILL.md body for a named skill.
# Registered automatically when an agent has skills configured.
function _read_skill_tool(skills::Vector{Skill})
    skill_map = Dict(s.name => s for s in skills)
    names     = join(keys(skill_map), ", ")

    NimbleTool(
        name        = "read_skill",
        description = "Load the full instructions for a skill. " *
                      "Available skills: $(names).",
        parameters  = Dict{String,Any}(
            "type"       => "object",
            "properties" => Dict{String,Any}(
                "name" => Dict{String,Any}(
                    "type"        => "string",
                    "description" => "The skill name to load (one of: $(names)).",
                ),
            ),
            "required"   => ["name"],
        ),
        callable     = (name::String) -> begin
            s = get(skill_map, name, nothing)
            isnothing(s) && return "Error: skill '$(name)' not found. Available: $(names)."
            skill_md = joinpath(s.path, "SKILL.md")
            isfile(skill_md) || return "Error: SKILL.md not found at $(skill_md)."
            body = _skill_body(read(skill_md, String))
            isempty(strip(body)) ? "Skill '$(name)' has no instructions body." : body
        end,
        return_direct = false,
        strict        = nothing,
    )
end
