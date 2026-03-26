# examples/agents/skills_demo.jl
#
# Demonstrates the NimbleAgents Skills system — filesystem-based capability
# packages that agents load on demand (progressive disclosure).
#
# Skill packages live alongside this file in examples/agents/skills/:
#   - julia-expert/  — Julia idioms, performance, type system, ecosystem
#   - code-reviewer/ — structured code review across correctness, perf, readability, security
#
# Run:
#   julia --project examples/agents/skills_demo.jl

using DotEnv
DotEnv.load!()

using NimbleAgents

function example_model(; tier::Symbol=:mini)
    if isempty(get(ENV, "GOOGLE_API_KEY", "")) && !isempty(get(ENV, "GEMINI_API_KEY", ""))
        ENV["GOOGLE_API_KEY"] = ENV["GEMINI_API_KEY"]
    end

    override = strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_MODEL", ""))
    !isempty(override) && return override

    openai_model, gemini_model = if tier === :nano
        ("gpt-5.4-nano-2026-03-17", "gemini-2.5-flash-lite")
    else
        ("gpt-5.4-mini", "gemini-2.5-flash")
    end

    provider = lowercase(strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_PROVIDER", "")))
    provider == "openai" && return openai_model
    provider == "gemini" && return gemini_model
    !isempty(provider) && error(
        "Unsupported NIMBLEAGENTS_EXAMPLE_PROVIDER=$(provider). Use 'openai' or 'gemini'.",
    )

    !isempty(get(ENV, "OPENAI_API_KEY", "")) && return openai_model
    !isempty(get(ENV, "GOOGLE_API_KEY", "")) && return gemini_model

    error(
        "Set OPENAI_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY, or set NIMBLEAGENTS_EXAMPLE_MODEL.",
    )
end

const EXAMPLE_MODEL = example_model(; tier=:nano)

SKILLS_DIR = joinpath(@__DIR__, "skills")  # examples/agents/skills/

# ── Agent with skills attached via skill_dirs ──────────────────────────────────

# Skills are discovered automatically from the directory.
# Only metadata (name + description) is injected into the system prompt —
# full instructions are loaded on demand via the built-in read_skill tool.

agent = Agent(;
    name="DevAssistant",
    instructions="You are a helpful software development assistant.",
    model=EXAMPLE_MODEL,
    skill_dirs=[SKILLS_DIR],
)

println("=" ^ 60)
println("Discovered skills:")
for s in discover_skills(SKILLS_DIR)
    println("  • $(s.name): $(s.description[1:min(60,end)])...")
end
println()

# ── Scenario 1: Julia question — triggers julia-expert skill ──────────────────

println("=" ^ 60)
println("Scenario 1: Julia performance question")
println("-" ^ 60)

session1 = Session(; app_name="skills_demo", user_id="dev")
result1 = run!(
    agent,
    "What are the most important things to check when optimising Julia code for performance?";
    session=session1,
    verbose=false,
)

println(result1)
println()

# ── Scenario 2: Code review — triggers code-reviewer skill ────────────────────

println("=" ^ 60)
println("Scenario 2: Code review request")
println("-" ^ 60)

code_snippet = """
function find_user(users, name)
    for i in 1:length(users)
        if users[i]["name"] == name
            return users[i]
        end
    end
end
"""

session2 = Session(; app_name="skills_demo", user_id="dev")
result2 = run!(
    agent,
    "Please review this Julia code:\n\n```julia\n$(code_snippet)\n```";
    session=session2,
    verbose=false,
)

println(result2)
println()

# ── Scenario 3: Explicit Skill attachment ─────────────────────────────────────

println("=" ^ 60)
println("Scenario 3: Explicit skill attachment")
println("-" ^ 60)

# You can also attach skills directly rather than via directory scan
julia_skill = Skill(
    "julia-expert",
    "Deep Julia language expertise. Use for Julia-specific questions.",
    joinpath(SKILLS_DIR, "julia-expert"),
)

focused_agent = Agent(;
    name="JuliaBot",
    instructions="You are a Julia programming specialist.",
    model=EXAMPLE_MODEL,
    skills=[julia_skill],
)

session3 = Session(; app_name="skills_demo", user_id="dev")
result3 = run!(
    focused_agent,
    "What is the difference between == and === in Julia?";
    session=session3,
    verbose=false,
)

println(result3)
