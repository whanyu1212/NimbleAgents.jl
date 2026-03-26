# examples/builtin_tools_demo.jl
#
# Demonstrates the NimbleAgents built-in tool library.
# Tools are plain NimbleTool constants — pick what you need.
#
# Run:
#   julia --project=. examples/builtin_tools_demo.jl

using DotEnv
DotEnv.load!()

using NimbleAgents

function example_model(; tier::Symbol=:mini)
    if isempty(get(ENV, "GOOGLE_API_KEY", "")) && !isempty(get(ENV, "GEMINI_API_KEY", ""))
        ENV["GOOGLE_API_KEY"] = ENV["GEMINI_API_KEY"]
    end

    override = strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_MODEL", ""))
    !isempty(override) && return override

    openai_model, gemini_model = tier === :nano ?
        ("gpt-5.4-nano-2026-03-17", "gemini-2.5-flash-lite") :
        ("gpt-5.4-mini", "gemini-2.5-flash")

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

# ── Scenario 1: File system agent ─────────────────────────────────────────────
#
# A coding assistant that can read, search, and edit files.

println("=" ^ 60)
println("Scenario 1: Coding assistant (filesystem + search)")
println("-" ^ 60)

coding_agent = Agent(;
    name="CodingAssistant",
    instructions="""
  You are a coding assistant with access to the local filesystem.
  Use read_file to inspect files, grep to search for patterns,
  list_dir to explore directories, and glob to find files by pattern.
  Always show relevant file contents or search results in your response.
  """,
    tools=[read_file_tool, list_dir_tool, glob_tool, grep_tool, find_files_tool],
    model=EXAMPLE_MODEL,
)

result1 = run!(
    coding_agent,
    "How many Julia source files are in the src/ directory, and what are their names?";
    verbose=false,
)
println(result1)
println()

# ── Scenario 2: File editing agent ────────────────────────────────────────────
#
# Agent that creates and edits files.

println("=" ^ 60)
println("Scenario 2: File creation and editing")
println("-" ^ 60)

editor_agent = Agent(;
    name="EditorAgent",
    instructions="""
  You are a file editing assistant. Use write_file to create files
  and edit_file to make targeted changes to existing files.
  Confirm what you did after each operation.
  """,
    tools=[read_file_tool, write_file_tool, edit_file_tool],
    model=EXAMPLE_MODEL,
)

result2 = run!(
    editor_agent,
    """Create a file at /tmp/hello_nimble.txt with the content:
    'Hello from NimbleAgents!'
    Then change 'Hello' to 'Greetings'.""";
    verbose=false,
)
println(result2)
println()

# ── Scenario 3: Shell agent with HITL ─────────────────────────────────────────
#
# bash_tool is powerful — pair with should_interrupt for safety.

println("=" ^ 60)
println("Scenario 3: Shell agent with HITL approval")
println("-" ^ 60)

shell_agent = Agent(;
    name="ShellAgent",
    instructions="""
  You are a shell assistant. Use the bash tool to run commands.
  Prefer safe, read-only commands unless explicitly asked to modify things.
  """,
    tools=[bash_tool, read_file_tool],
    model=EXAMPLE_MODEL,
    hooks=AgentHooks(;
        # Gate all bash commands — require approval before executing
        should_interrupt=(name, args) -> name == "bash",
    ),
)

approval_ch = Channel{String}(1)

# Auto-approve in background for demo purposes
@async begin
    sleep(2)
    isopen(approval_ch) && put!(approval_ch, "approve")
end

result3 = run!(
    shell_agent,
    "What is the current date and time?";
    verbose=false,
    approval_channel=approval_ch,
)
println(result3)
println()

# ── Scenario 4: HTTP agent ────────────────────────────────────────────────────

println("=" ^ 60)
println("Scenario 4: HTTP fetch agent")
println("-" ^ 60)

http_agent = Agent(;
    name="WebAgent",
    instructions="""
  You are a web assistant. Use http_get to fetch URLs and return
  a concise summary of the content.
  """,
    tools=[http_get_tool],
    model=EXAMPLE_MODEL,
)

result4 = run!(
    http_agent,
    "Fetch https://httpbin.org/json and tell me what fields the response contains.";
    verbose=false,
)
println(result4)
