###############################################################################
# skills/frontmatter.jl — SKILL.md frontmatter parsing
###############################################################################

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
    rest = content[4:end]
    close = findfirst(r"\n---(\n|$)", rest)
    isnothing(close) && return nothing

    fm_text = rest[1:(first(close) - 1)]

    name = ""
    description = ""
    current_key = ""
    desc_lines = String[]

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
    (name=name, description=description)
end

# Return the body of SKILL.md (everything after the closing ---)
function _skill_body(content::String)
    m = match(r"^---.*?---\s*\n?"s, content)
    isnothing(m) && return content
    content[(length(m.match) + 1):end]
end
