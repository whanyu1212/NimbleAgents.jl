###############################################################################
# skills/read_skill_tool.jl — built-in tool factory for skill body loading
###############################################################################

# Builds a NimbleTool that loads SKILL.md body for a named skill.
# Registered automatically when an agent has skills configured.
function _read_skill_tool(skills::Vector{Skill})
    skill_map = Dict(s.name => s for s in skills)
    names = join(keys(skill_map), ", ")

    NimbleTool(;
        name="read_skill",
        description="Load the full instructions for a skill. " *
                    "Available skills: $(names).",
        parameters=Dict{String,Any}(
            "type" => "object",
            "properties" => Dict{String,Any}(
                "name" => Dict{String,Any}(
                    "type" => "string",
                    "description" => "The skill name to load (one of: $(names)).",
                ),
            ),
            "required" => ["name"],
        ),
        callable=(name::String) -> begin
            s = get(skill_map, name, nothing)
            isnothing(s) &&
                return "Error: skill '$(name)' not found. Available: $(names)."
            skill_md = joinpath(s.path, "SKILL.md")
            isfile(skill_md) || return "Error: SKILL.md not found at $(skill_md)."
            body = _skill_body(read(skill_md, String))
            isempty(strip(body)) ? "Skill '$(name)' has no instructions body." : body
        end,
        return_direct=false,
        strict=nothing,
    )
end
