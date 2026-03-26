# examples/hitl_should_interrupt.jl
#
# Human-in-the-Loop via the should_interrupt hook (Pattern A — recommended).
#
# should_interrupt = (tool_name, args) -> Bool
#
# The framework calls this before executing each tool. If it returns true for
# any pending call, all flagged calls are collected and a HumanInterrupt is
# thrown before any tool executes. The human approves or redirects, then
# resume!(session, response) + run! continues from where it left off.
#
# Use this when:
#   - You want a simple, declarative gate on specific tool names
#   - You don't need to inspect argument values to decide
#   - You want the framework to handle the throw for you
#
# Run from the project root:
#   julia --project=. examples/hitl_should_interrupt.jl

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

@tool function list_files(directory::String)
    "List files in a directory."
    "[SIMULATED] Files in $(directory): [report.txt, backup.log, config.yaml]"
end

# ── Agent ─────────────────────────────────────────────────────────────────────

const DANGEROUS_TOOLS = ["send_email", "delete_file"]

agent = Agent(;
    name="OpsBot",
    instructions="""
  You are an operations assistant. You can read files, list directories,
  send emails, and delete files. Always complete the user's request.
  """,
    tools=[send_email_tool, delete_file_tool, read_file_tool, list_files_tool],
    model=EXAMPLE_MODEL,
    hooks=AgentHooks(; should_interrupt=(name, args) -> name in DANGEROUS_TOOLS),
)

# ── Approval loop ─────────────────────────────────────────────────────────────

function ask_human(interrupt::HumanInterrupt)::String
    names = join([t.name for t in interrupt.tool_calls], ", ")
    tprintln(
        Panel(
            "[bold red]Approval Required[/bold red]\n\n" *
            "About to call: [bold]$(names)[/bold]\n\n" *
            "[dim]Type [bold]approve[/bold] to allow, or describe what to do instead:[/dim]";
            title="HITL",
            style="red",
            padding=(1, 2),
        ),
    )
    print("> ")
    strip(readline())
end

function run_with_hitl(agent, input, session; max_interrupts=5)
    for _ in 1:max_interrupts
        try
            return run!(agent, input; session=session, verbose=false)
        catch e
            e isa HumanInterrupt || rethrow(e)
            response = ask_human(e)
            if lowercase(response) == "approve"
                resume!(session, "Approved. Please proceed.")
            else
                resume!(session, "Rejected. $(response)")
            end
        end
    end
    error("Too many interrupts — aborting")
end

# ── Example 1 — safe request, no interrupt ────────────────────────────────────

tprintln(
    Panel(
        "Example 1 — safe tools only (read + list)\nNo approval prompt will appear.";
        title="should_interrupt",
        style="cyan",
        padding=(0, 2),
    ),
)

session1 = Session(; app_name="hitl", user_id="user")
result1 = run!(
    agent, "List files in /tmp and read /tmp/report.txt"; session=session1, verbose=false
)
println(result1, "\n")

# ── Example 2 — dangerous request, single interrupt ───────────────────────────

tprintln(
    Panel(
        "Example 2 — dangerous tools (email + delete)\nApproval prompt appears once.";
        title="should_interrupt",
        style="yellow",
        padding=(0, 2),
    ),
)

session2 = Session(; app_name="hitl", user_id="user")
result2 = run_with_hitl(
    agent, "Send a summary to boss@company.com and delete /tmp/backup.log", session2
)
println(result2, "\n")

# ── Example 3 — multi-step: safe then dangerous ───────────────────────────────

tprintln(
    Panel(
        "Example 3 — safe step first, then dangerous\nApproval fires only for the dangerous step.";
        title="should_interrupt",
        style="magenta",
        padding=(0, 2),
    ),
)

session3 = Session(; app_name="hitl", user_id="user")
result3 = run_with_hitl(
    agent, "Read /tmp/config.yaml, then email ops@company.com with its contents", session3
)
println(result3, "\n")
