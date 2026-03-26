# examples/cli_tools_demo.jl
#
# Demonstrates CLITool — expose shell commands as agent tools with no
# Julia wrapper code needed.
#
# Run:
#   julia --project=. examples/cli_tools_demo.jl

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

# ── Define CLI tools ───────────────────────────────────────────────────────────

grep_tool = CLITool(;
    name="grep",
    description="Search for a pattern in files or directories. Returns matching lines with line numbers.",
    command=["grep", "-rn", "{pattern}", "{path}"],
    args=[
        "pattern" => CLIArg(String, "Regex pattern to search for."),
        "path" => CLIArg(String, "File or directory path to search in."),
    ],
)

git_log_tool = CLITool(;
    name="git_log",
    description="Show recent git commits as a compact one-line log.",
    command=["git", "log", "--oneline", "-{n}"],
    args=["n" => CLIArg(Int, "Number of recent commits to show (default 10).")],
    working_dir=dirname(dirname(@__DIR__)),   # run from repo root
)

wc_tool = CLITool(;
    name="word_count",
    description="Count lines, words, and characters in a file.",
    command=["wc", "{path}"],
    args=["path" => CLIArg(String, "Path to the file to count.")],
)

# ── Agent ──────────────────────────────────────────────────────────────────────

agent = Agent(;
    name="DevBot",
    instructions="""
  You are a developer assistant with access to shell tools.
  Use grep to search code, git_log to inspect history, and word_count to measure files.
  Always show the raw tool output in your response.
  """,
    tools=[grep_tool, git_log_tool, wc_tool],
    model=EXAMPLE_MODEL,
)

# ── Scenario 1: Code search ────────────────────────────────────────────────────

println("=" ^ 60)
println("Scenario 1: Search the codebase")
println("-" ^ 60)

result1 = run!(
    agent, "Search for all uses of 'CLITool' in the src/ directory."; verbose=false
)
println(result1)
println()

# ── Scenario 2: Git history ────────────────────────────────────────────────────

println("=" ^ 60)
println("Scenario 2: Recent git commits")
println("-" ^ 60)

result2 = run!(agent, "Show me the last 5 git commits."; verbose=false)
println(result2)
println()

# ── Scenario 3: File stats ─────────────────────────────────────────────────────

println("=" ^ 60)
println("Scenario 3: File word count")
println("-" ^ 60)

result3 = run!(agent, "How many lines are in src/agent.jl?"; verbose=false)
println(result3)
