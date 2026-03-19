# examples/hitl_on_llm_result.jl
#
# Human-in-the-Loop via the on_llm_result hook (Pattern B — advanced).
#
# on_llm_result = (agent, iteration, msg) -> nothing
#
# Fires after every LLM response, before any tool executes. You receive the
# full raw response object (msg) and can inspect tool_calls, content, tokens,
# finish_reason, etc. Throw HumanInterrupt manually when approval is needed.
#
# Use this when:
#   - You need to inspect argument values to decide whether to interrupt
#     (e.g. only block delete_file when path starts with "/prod/")
#   - You want a rich, context-aware approval message
#   - You need conditional logic that goes beyond a name allowlist
#
# Run from the project root:
#   julia --project=. examples/hitl_on_llm_result.jl

using DotEnv
DotEnv.load!()

using NimbleAgents
import Term: Panel, tprintln

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

# ── Hook — argument-aware interruption ────────────────────────────────────────
#
# This hook goes beyond a simple name check:
#   • delete_file is only blocked when the path starts with "/prod/"
#   • send_email is always blocked for external domains
#   • The approval message shows full argument values so the human
#     knows exactly what will happen

const INTERNAL_DOMAIN = "company.com"

function smart_hitl_hook(agent, iteration, msg)
    isempty(something(msg.tool_calls, [])) && return

    pending = filter(msg.tool_calls) do t
        args = something(t.args, Dict())
        if t.name == "delete_file"
            # Only block production paths
            path = get(args, :path, get(args, "path", ""))
            startswith(path, "/prod/")
        elseif t.name == "send_email"
            # Block emails to external domains
            to = get(args, :to, get(args, "to", ""))
            !endswith(to, INTERNAL_DOMAIN)
        else
            false
        end
    end

    isempty(pending) && return

    # Build a detailed approval message showing argument values
    lines = map(pending) do t
        args    = something(t.args, Dict())
        arg_str = join(["    $(k) = $(repr(v))" for (k, v) in pairs(args)], "\n")
        "  • $(t.name)\n$(arg_str)"
    end

    throw(HumanInterrupt(pending;
        message = "The agent wants to:\n\n" * join(lines, "\n\n")))
end

# ── Agent ─────────────────────────────────────────────────────────────────────

agent = Agent(
    name         = "OpsBot",
    instructions = """
    You are an operations assistant. You can read files, list directories,
    send emails, and delete files. Always complete the user's request.
    """,
    tools = [send_email, delete_file, read_file, list_files],
    model = "gpt-4o-mini",
    hooks = AgentHooks(on_llm_result = smart_hitl_hook),
)

# ── Approval loop ─────────────────────────────────────────────────────────────

function ask_human(interrupt::HumanInterrupt)::String
    tprintln(Panel(
        "[bold red]Approval Required[/bold red]\n\n" *
        interrupt.message * "\n\n" *
        "[dim]Type [bold]approve[/bold] to allow, or describe what to do instead:[/dim]",
        title = "HITL", style = "red", padding = (1, 2),
    ))
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

# ── Example 1 — delete safe path (no interrupt) ───────────────────────────────

tprintln(Panel(
    "Example 1 — delete /tmp/ path (not production)\nNo approval needed — path does not start with /prod/.",
    title = "on_llm_result", style = "cyan", padding = (0, 2),
))

session1 = Session(app_name="hitl", user_id="user")
result1  = run_with_hitl(agent,
    "Delete the file /tmp/old_backup.log",
    session1)
println(result1, "\n")

# ── Example 2 — delete production path (interrupt) ────────────────────────────

tprintln(Panel(
    "Example 2 — delete /prod/ path\nApproval required — production path detected.",
    title = "on_llm_result", style = "yellow", padding = (0, 2),
))

session2 = Session(app_name="hitl", user_id="user")
result2  = run_with_hitl(agent,
    "Delete /prod/database/users.db — it is no longer needed",
    session2)
println(result2, "\n")

# ── Example 3 — external email (interrupt) ────────────────────────────────────

tprintln(Panel(
    "Example 3 — email to external domain\nApproval required — recipient is outside $(INTERNAL_DOMAIN).",
    title = "on_llm_result", style = "magenta", padding = (0, 2),
))

session3 = Session(app_name="hitl", user_id="user")
result3  = run_with_hitl(agent,
    "Send our Q1 report to partner@external-vendor.com",
    session3)
println(result3, "\n")

# ── Example 4 — internal email (no interrupt) ─────────────────────────────────

tprintln(Panel(
    "Example 4 — email to internal domain\nNo approval needed — recipient is @$(INTERNAL_DOMAIN).",
    title = "on_llm_result", style = "green", padding = (0, 2),
))

session4 = Session(app_name="hitl", user_id="user")
result4  = run_with_hitl(agent,
    "Email alice@company.com to let her know the deployment is done",
    session4)
println(result4, "\n")
