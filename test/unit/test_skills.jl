@testset "Skill struct" begin
    s = Skill("my-skill", "Does things.", "/some/path")
    @test s.name        == "my-skill"
    @test s.description == "Does things."
    @test s.path        == "/some/path"
end

@testset "_parse_frontmatter" begin
    content = """---
name: code-reviewer
description: Reviews Julia code for style and correctness.
---

## Instructions

Review the code carefully.
"""
    fm = NimbleAgents._parse_frontmatter(content)
    @test !isnothing(fm)
    @test fm.name        == "code-reviewer"
    @test fm.description == "Reviews Julia code for style and correctness."

    # No frontmatter → nothing
    @test isnothing(NimbleAgents._parse_frontmatter("just plain text"))

    # Malformed (no closing ---) → nothing
    @test isnothing(NimbleAgents._parse_frontmatter("---\nname: foo\n"))
end

@testset "_skill_body strips frontmatter" begin
    content = "---\nname: foo\ndescription: bar\n---\n\nBody text here.\n"
    body = NimbleAgents._skill_body(content)
    @test !occursin("name:", body)
    @test occursin("Body text here.", body)

    # No frontmatter → full content returned
    plain = "Just instructions."
    @test NimbleAgents._skill_body(plain) == plain
end

@testset "discover_skills" begin
    # Build a temp skill directory tree
    dir = mktempdir()
    skill1_dir = joinpath(dir, "julia-expert")
    skill2_dir = joinpath(dir, "code-reviewer")
    mkpath(skill1_dir)
    mkpath(skill2_dir)

    write(joinpath(skill1_dir, "SKILL.md"), """---
name: julia-expert
description: Expert Julia programming assistant.
---

You are an expert Julia programmer.
""")
    write(joinpath(skill2_dir, "SKILL.md"), """---
name: code-reviewer
description: Reviews code for quality issues.
---

Review all code carefully.
""")
    # A dir without SKILL.md — should be ignored
    mkpath(joinpath(dir, "no-skill"))

    skills = discover_skills([dir])
    @test length(skills) == 2
    names = Set(s.name for s in skills)
    @test "julia-expert"  in names
    @test "code-reviewer" in names

    # Non-existent dir → empty, no error
    @test discover_skills(["/nonexistent/path/xyz"]) == Skill[]

    # Empty dir list → empty
    @test discover_skills(String[]) == Skill[]
end

@testset "_skills_prompt" begin
    skills = [
        Skill("foo", "Does foo.", "/tmp/foo"),
        Skill("bar", "Does bar.", "/tmp/bar"),
    ]

    prompt = NimbleAgents._skills_prompt(skills)
    @test occursin("foo",      prompt)
    @test occursin("Does foo", prompt)
    @test occursin("bar",      prompt)
    @test occursin("Does bar", prompt)

    # Empty skills → empty string (no injection)
    @test NimbleAgents._skills_prompt(Skill[]) == ""
end

@testset "_read_skill_tool" begin
    dir = mktempdir()
    skill_dir = joinpath(dir, "test-skill")
    mkpath(skill_dir)
    write(joinpath(skill_dir, "SKILL.md"), """---
name: test-skill
description: A test skill.
---

These are the full instructions for test-skill.
""")

    skills = discover_skills([dir])
    @test length(skills) == 1

    tool = NimbleAgents._read_skill_tool(skills)
    @test tool isa NimbleTool
    @test tool.name == "read_skill"

    # Calling it with the skill name returns the body
    result = tool.callable("test-skill")
    @test occursin("full instructions", result)

    # Unknown skill name → error message
    result2 = tool.callable("unknown-skill")
    @test occursin("unknown", lowercase(result2))
end
