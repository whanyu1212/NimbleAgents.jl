# examples/hitl_channel.jl
#
# Human-in-the-Loop via approval_channel (non-blocking, async).
#
# Instead of throwing HumanInterrupt and requiring the caller to re-run,
# the agent pauses mid-loop and waits for a response on a Channel{String}.
# The response can come from any thread — an HTTP handler, a UI callback,
# a Slack webhook, another agent, or a test harness.
#
# The agent holds all its state while waiting. No re-run, no resume! needed.
#
# Comparison:
#   Throw-based  → agent dies, caller re-runs from session history
#   Channel-based → agent pauses, caller puts response, agent continues
#
# Run from the project root:
#   julia --project=. examples/hitl_channel.jl

using DotEnv
DotEnv.load!()

using NimbleAgents
import Term: Panel, tprintln

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

# ── Tools ─────────────────────────────────────────────────────────────────────

@tool function send_email(to::String, subject::String, body::String)
    "Send an email to a recipient."
    "[SIMULATED] Email sent to $(to): \"$(subject)\""
end

@tool function delete_file(path::String)
    "Permanently delete a file at the given path."
    "[SIMULATED] Deleted: $(path)"
end

@tool function read_file(path::String)
    "Read the contents of a file."
    "[SIMULATED] Contents of $(path): 'Hello from the file system.'"
end

const DANGEROUS_TOOLS = ["send_email", "delete_file"]

agent = Agent(;
    name="OpsBot",
    instructions="""
  You are an operations assistant. You can read files, send emails,
  and delete files. Always complete the user's request.
  """,
    tools=[send_email_tool, delete_file_tool, read_file_tool],
    model=EXAMPLE_MODEL,
    hooks=AgentHooks(; should_interrupt=(name, args) -> name in DANGEROUS_TOOLS),
)

# ══════════════════════════════════════════════════════════════════════════════
# Example 1 — approve from another thread (simulates a web handler)
# ══════════════════════════════════════════════════════════════════════════════

tprintln(
    Panel(
        "Example 1 — approve from another thread\n" *
        "Simulates a web handler putting the approval response\n" *
        "while the agent is paused waiting.";
        title="Channel HITL",
        style="cyan",
        padding=(1, 2),
    ),
)

ch1 = Channel{String}(1)
session1 = Session(; app_name="hitl_channel", user_id="user")

# Agent runs in background — does not block this thread
task1 = Threads.@spawn run!(
    agent,
    "Send a status update to boss@company.com";
    session=session1,
    verbose=false,
    approval_channel=ch1,
)

# Simulate web handler receiving approval after a short delay
sleep(0.5)
tprintln("[dim]→ 'web handler' received approval click, putting to channel...[/dim]")
put!(ch1, "approve")

result1 = fetch(task1)
println(result1, "\n")

# ══════════════════════════════════════════════════════════════════════════════
# Example 2 — redirect instead of approve
# ══════════════════════════════════════════════════════════════════════════════

tprintln(
    Panel(
        "Example 2 — redirect instead of approve\n" *
        "Human rejects and gives new instructions.\n" *
        "Agent re-plans without re-running from scratch.";
        title="Channel HITL",
        style="yellow",
        padding=(1, 2),
    ),
)

ch2 = Channel{String}(1)
session2 = Session(; app_name="hitl_channel", user_id="user")

task2 = Threads.@spawn run!(
    agent,
    "Delete /prod/old_backup.tar.gz";
    session=session2,
    verbose=false,
    approval_channel=ch2,
)

sleep(0.5)
tprintln("[dim]→ human rejects delete, redirects to read instead...[/dim]")
put!(ch2, "Rejected — do not delete. Read the file and summarise it instead.")

result2 = fetch(task2)
println(result2, "\n")

# ══════════════════════════════════════════════════════════════════════════════
# Example 3 — timeout (no one responds)
# ══════════════════════════════════════════════════════════════════════════════

tprintln(
    Panel(
        "Example 3 — approval timeout\n" *
        "No response arrives within the timeout window.\n" *
        "Agent throws ApprovalTimeout.";
        title="Channel HITL",
        style="red",
        padding=(1, 2),
    ),
)

ch3 = Channel{String}(1)
session3 = Session(; app_name="hitl_channel", user_id="user")

task3 = Threads.@spawn run!(
    agent,
    "Send the quarterly report to ceo@company.com";
    session=session3,
    verbose=false,
    approval_channel=ch3,
    approval_timeout=3.0,
)   # short timeout for demo

tprintln("[dim]→ no one responds — waiting for timeout...[/dim]")

try
    fetch(task3)
catch e
    if e isa TaskFailedException && e.task.exception isa ApprovalTimeout
        timeout_err = e.task.exception
        println("Caught ApprovalTimeout after $(timeout_err.timeout)s")
        println("Pending: ", join([t.name for t in timeout_err.tool_calls], ", "), "\n")
    else
        rethrow(e)
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# Example 4 — abort by closing the channel
# ══════════════════════════════════════════════════════════════════════════════

tprintln(
    Panel(
        "Example 4 — abort by closing the channel\n" *
        "Closing the channel signals the agent to stop immediately.";
        title="Channel HITL",
        style="magenta",
        padding=(1, 2),
    ),
)

ch4 = Channel{String}(1)
session4 = Session(; app_name="hitl_channel", user_id="user")

task4 = Threads.@spawn run!(
    agent, "Delete /prod/users.db"; session=session4, verbose=false, approval_channel=ch4
)

sleep(0.5)
tprintln("[dim]→ human closes channel to abort...[/dim]")
close(ch4)

try
    fetch(task4)
catch e
    if e isa TaskFailedException
        println("Agent aborted: ", e.task.exception, "\n")
    else
        rethrow(e)
    end
end
