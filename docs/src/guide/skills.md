```@meta
CurrentModule = NimbleAgents
```

# Skills

Skills are filesystem-based capability packages that agents can load on demand. Only metadata is injected into the system prompt — full instructions are loaded lazily via the built-in `read_skill` tool when the agent needs them.

## Skill Structure

A skill is a directory containing a `SKILL.md` file:

```
skills/
└── code-reviewer/
    └── SKILL.md
```

## SKILL.md Format

```markdown
---
name: code-reviewer
description: Reviews Julia code for style and correctness.
---

## Instructions

Review the code carefully. Check for:
- Type stability issues
- Missing error handling
- Style violations
```

The YAML frontmatter requires exactly two fields:
- `name` — skill identifier
- `description` — one-line description used in the system prompt

Everything after the closing `---` is the instruction body, loaded on demand.

## Discovering Skills

Scan directories for skill packages:

```julia
skills = discover_skills(["./skills", joinpath(homedir(), ".nimble", "skills")])
```

`discover_skills` walks each directory, finds subdirectories with a valid `SKILL.md`, and returns a `Vector{Skill}`.

## Using Skills with an Agent

```julia
agent = Agent(
    name         = "CodeBot",
    instructions = "You help with Julia development.",
    skills       = skills,
)
```

Or discover skills automatically from directories:

```julia
agent = Agent(
    name         = "CodeBot",
    instructions = "You help with Julia development.",
    skill_dirs   = ["./skills"],
)
```

## How It Works

1. At startup, skill metadata (name + description) is appended to the system prompt
2. The agent sees a list of available skills and their descriptions
3. When a skill is relevant, the agent calls the auto-generated `read_skill` tool
4. `read_skill` loads and returns the full instruction body from `SKILL.md`
5. The agent uses those instructions to handle the task

This lazy-loading approach keeps context lean (only metadata in the prompt) while making full capability details available on demand.

## Constructing Skills Directly

```julia
skill = Skill("code-reviewer", "Reviews Julia code for issues.", "./skills/code-reviewer")
```
