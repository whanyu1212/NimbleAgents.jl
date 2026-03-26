###############################################################################
# skills/discovery.jl — skill discovery from directories
###############################################################################

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
