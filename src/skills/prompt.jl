###############################################################################
# skills/prompt.jl — system prompt augmentation for skills
###############################################################################

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
