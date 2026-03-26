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

include("skills/types.jl")
include("skills/frontmatter.jl")
include("skills/discovery.jl")
include("skills/prompt.jl")
include("skills/read_skill_tool.jl")
