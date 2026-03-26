###############################################################################
# skills/types.jl — skill metadata type
###############################################################################

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
    name::String
    description::String
    path::String
end
