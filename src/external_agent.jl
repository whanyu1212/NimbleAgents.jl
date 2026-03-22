###############################################################################
# external_agent.jl — Wrap external CLI agents (Claude Code, Codex) as tools
#
# ExternalAgentTool runs an external CLI agent as a subprocess, streaming its
# stdout line-by-line so callers can observe progress in real-time. Designed
# for long-running agents that produce structured (JSON) output.
#
# Usage:
#
#   coder = ExternalAgentTool(
#       name        = "claude_code",
#       description = "Delegate coding tasks to Claude Code.",
#       command     = ["claude", "-p", "{task}", "--output-format", "stream-json",
#                      "--verbose", "--model", "sonnet"],
#       args        = ["task" => CLIArg(String, "The coding task to perform.")],
#       timeout     = 300.0,
#       on_output   = line -> println("[claude] ", line),
#   )
#
#   agent = Agent(name="PM", tools=[coder], ...)
#
# A convenience constructor `claude_code_tool(; ...)` is provided for the
# common case of wrapping Claude Code.
###############################################################################

using JSON3: JSON3

# ── ExternalAgentTool ────────────────────────────────────────────────────────

"""
    ExternalAgentTool(; name, description, command, args, timeout, working_dir,
                        on_output, parse_result)

An `AbstractTool` for running external CLI agents (Claude Code, Codex, etc.)
as subprocesses with real-time progress streaming.

Unlike `CLITool` (which buffers all output), `ExternalAgentTool` reads stdout
line-by-line and fires `on_output(line)` for each line as it arrives. This
enables progress visibility for long-running agents.

# Fields
- `name::String`: Tool name shown to the LLM.
- `description::String`: What the tool does and when to use it.
- `command::Vector{String}`: Command with `{placeholder}` slots (same as `CLITool`).
- `args::Vector{Pair{String,CLIArg}}`: Ordered argument definitions.
- `timeout::Float64`: Seconds before the subprocess is killed (default: `300.0`).
- `working_dir::Union{String,Nothing}`: Working directory for the subprocess.
- `on_output::Union{Function,Nothing}`: Called with each stdout line as it arrives.
  Use for progress logging (default: `nothing` — silent).
- `parse_result::Union{Function,Nothing}`: Post-process the collected output lines
  into a final result string. Receives `Vector{String}` of all stdout lines.
  Default: `nothing` (returns raw output joined by newlines).
- `return_direct::Bool`: Short-circuit the agent loop after this tool (default: `false`).

# Example
```julia
coder = ExternalAgentTool(
    name        = "coder",
    description = "Run Claude Code to implement a task.",
    command     = ["claude", "-p", "{task}", "--output-format", "stream-json",
                   "--verbose", "--model", "sonnet"],
    args        = ["task" => CLIArg(String, "The coding task.")],
    timeout     = 300.0,
    on_output   = line -> println("[coder] ", line),
)
```
"""
struct ExternalAgentTool <: AbstractTool
    name::String
    description::String
    command::Vector{String}
    args::Vector{Pair{String,CLIArg}}
    timeout::Float64
    working_dir::Union{String,Nothing}
    on_output::Union{Function,Nothing}
    parse_result::Union{Function,Nothing}
    return_direct::Bool
    return_artifact::Bool

    # Pre-built JSON schema (computed once at construction)
    parameters::Dict{String,Any}
    strict::Union{Bool,Nothing}
end

function ExternalAgentTool(;
    name::String,
    description::String,
    command::Vector{String},
    args::Vector{Pair{String,CLIArg}}=Pair{String,CLIArg}[],
    timeout::Float64=300.0,
    working_dir::Union{String,Nothing}=nothing,
    on_output::Union{Function,Nothing}=nothing,
    parse_result::Union{Function,Nothing}=nothing,
    return_direct::Bool=false,
    return_artifact::Bool=false,
    strict::Union{Bool,Nothing}=nothing,
)
    parameters = _cli_schema(args)
    ExternalAgentTool(
        name,
        description,
        command,
        args,
        timeout,
        working_dir,
        on_output,
        parse_result,
        return_direct,
        return_artifact,
        parameters,
        strict,
    )
end

# ── Subprocess execution with line-by-line streaming ─────────────────────────

function _run_external_agent(tool::ExternalAgentTool, args::Dict{Symbol,<:Any})
    cmd = _render_command_ext(tool, args)

    if !isnothing(tool.working_dir)
        cmd = Cmd(cmd; dir=tool.working_dir)
    end

    stderr_buf = IOBuffer()
    stdout_lines = String[]

    # Start subprocess with stdout as a readable pipe
    proc = open(pipeline(cmd; stderr=stderr_buf), "r")

    timed_out = Ref(false)

    # Async watchdog — kills the subprocess if it exceeds the timeout.
    # This is necessary because eof(proc) blocks when the subprocess
    # produces no output, so an in-loop time check would never fire.
    watchdog = @async begin
        sleep(tool.timeout)
        if process_running(proc)
            timed_out[] = true
            kill(proc)
        end
    end

    try
        # Read stdout line-by-line for real-time progress
        while !eof(proc)
            line = readline(proc)
            push!(stdout_lines, line)

            if !isnothing(tool.on_output)
                try
                    tool.on_output(line)
                catch
                    # Don't let callback errors kill the read loop
                end
            end
        end
    catch e
        # IOError when process is killed by watchdog or exits — expected
        e isa Base.IOError || rethrow()
    end

    # Cancel watchdog if process finished before timeout
    if !istaskdone(watchdog)
        Base.schedule(watchdog, InterruptException(); error=true)
    end

    if timed_out[]
        close(proc)
        partial = join(stdout_lines, "\n")
        return "Error: external agent timed out after $(tool.timeout)s.\n" *
               (isempty(partial) ? "" : "Partial output:\n$(partial)")
    end

    close(proc)
    err = String(take!(stderr_buf))

    # Parse result
    if !isnothing(tool.parse_result)
        try
            return tool.parse_result(stdout_lines)
        catch e
            return "Error parsing result: $(sprint(showerror, e))\nRaw output:\n$(join(stdout_lines, "\n"))"
        end
    end

    out = join(stdout_lines, "\n")

    if !isempty(out) && !isempty(err)
        "$(out)\n[stderr]\n$(err)"
    elseif !isempty(out)
        out
    elseif !isempty(err)
        "[stderr]\n$(err)"
    else
        "(no output)"
    end
end

# Reuse CLITool's placeholder substitution logic
function _render_command_ext(tool::ExternalAgentTool, args::Dict{Symbol,<:Any})
    rendered = map(tool.command) do token
        result = token
        for (arg_name, _) in tool.args
            val = get(args, Symbol(arg_name), nothing)
            isnothing(val) && continue
            result = replace(result, "{$(arg_name)}" => string(val))
        end
        result
    end
    Cmd(rendered)
end

# ── Tool interface ───────────────────────────────────────────────────────────

function _call_tool(tool::ExternalAgentTool, args::Dict{Symbol,<:Any})
    _run_external_agent(tool, args)
end
_is_return_direct(t::ExternalAgentTool) = t.return_direct
_is_return_artifact(t::ExternalAgentTool) = t.return_artifact

# ── Claude Code convenience constructor ──────────────────────────────────────

"""
    claude_code_tool(; name, description, model, working_dir, timeout,
                       max_budget, permission_mode, allowed_tools, on_output,
                       system_prompt, session_id, resume, extra_flags)

Create an `ExternalAgentTool` that delegates tasks to Claude Code via `claude -p`.

Uses `--output-format stream-json --verbose` for structured streaming output.
The `on_output` callback receives each line of stream-json as it arrives,
enabling real-time progress monitoring.

!!! note "Authentication"
    Claude Code must be authenticated before use. Either:
    1. Run `claude login` once in your terminal (stores credentials in `~/.claude/`), or
    2. Set `ANTHROPIC_API_KEY` in your `.env` or environment (inherited by subprocess).
    Login cannot be done programmatically — it requires an interactive browser OAuth flow.

# Arguments
- `name::String`: Tool name (default: `"claude_code"`).
- `description::String`: Description shown to the LLM.
- `model::String`: Claude model to use (default: `"sonnet"`).
- `working_dir::Union{String,Nothing}`: Working directory for Claude Code.
- `timeout::Float64`: Seconds before kill (default: `300.0`).
- `max_budget::Union{Float64,Nothing}`: Max USD budget per invocation.
- `permission_mode::String`: Permission mode (default: `"bypassPermissions"`).
- `allowed_tools::Union{Vector{String},Nothing}`: Restrict available tools.
- `on_output::Union{Function,Nothing}`: Called per stream-json line.
- `system_prompt::Union{String,Nothing}`: Custom system prompt for Claude Code.
- `session_id::Union{String,Nothing}`: Session ID to continue a previous conversation.
  When set, Claude Code resumes the specified session, retaining full conversation context.
- `resume::Bool`: If `true`, resume the most recent session (default: `false`).
  Mutually exclusive with `session_id` — if both are set, `session_id` takes precedence.
- `extra_flags::Vector{String}`: Additional CLI flags.

# Example
```julia
coder = claude_code_tool(
    working_dir = "/path/to/repo",
    model       = "sonnet",
    max_budget  = 2.00,
    on_output   = line -> begin
        try
            event = JSON3.read(line)
            if event.type == "assistant"
                println("[claude] ", get(event.message.content[1], :text, ""))
            end
        catch; end
    end,
)

agent = Agent(
    name = "PM",
    instructions = "Delegate implementation tasks to claude_code.",
    tools = [coder],
)

# Resume a previous Claude Code session by ID
coder_resume = claude_code_tool(session_id = "abc-123", working_dir = "/path/to/repo")

# Resume the most recent session
coder_latest = claude_code_tool(resume = true, working_dir = "/path/to/repo")
```
"""
function claude_code_tool(;
    name::String="claude_code",
    description::String="""Delegate a coding task to Claude Code — an autonomous coding agent.
It can read, write, and edit files, run shell commands, search code, and manage git.
Use this for implementation work: writing code, fixing bugs, refactoring, running tests.
The task should be a clear, specific description of what to do.""",
    model::String="sonnet",
    working_dir::Union{String,Nothing}=nothing,
    timeout::Float64=300.0,
    max_budget::Union{Float64,Nothing}=nothing,
    permission_mode::String="bypassPermissions",
    allowed_tools::Union{Vector{String},Nothing}=nothing,
    on_output::Union{Function,Nothing}=nothing,
    system_prompt::Union{String,Nothing}=nothing,
    session_id::Union{String,Nothing}=nothing,
    resume::Bool=false,
    extra_flags::Vector{String}=String[],
)
    cmd = [
        "claude",
        "-p",
        "{task}",
        "--output-format",
        "stream-json",
        "--verbose",
        "--model",
        model,
        "--permission-mode",
        permission_mode,
    ]

    !isnothing(max_budget) && append!(cmd, ["--max-budget-usd", string(max_budget)])
    !isnothing(allowed_tools) && append!(cmd, ["--allowedTools", join(allowed_tools, ",")])
    !isnothing(system_prompt) && append!(cmd, ["--system-prompt", system_prompt])
    if !isnothing(session_id)
        append!(cmd, ["--session-id", session_id])
    elseif resume
        push!(cmd, "--resume")
    end
    append!(cmd, extra_flags)

    ExternalAgentTool(;
        name=name,
        description=description,
        command=cmd,
        args=["task" => CLIArg(String, "Clear description of the coding task to perform.")],
        timeout=timeout,
        working_dir=working_dir,
        on_output=on_output,
        parse_result=_parse_claude_code_result,
    )
end

"""
    codex_tool(; name, description, model, working_dir, timeout, on_output, extra_flags)

Create an `ExternalAgentTool` that delegates tasks to OpenAI Codex CLI via `codex -q`.

# Example
```julia
coder = codex_tool(working_dir="/path/to/repo")
```
"""
function codex_tool(;
    name::String="codex",
    description::String="""Delegate a coding task to Codex — an autonomous coding agent.
It can read, write, and edit files, run commands, and manage code.
The task should be a clear, specific description of what to do.""",
    model::String="o4-mini",
    working_dir::Union{String,Nothing}=nothing,
    timeout::Float64=300.0,
    on_output::Union{Function,Nothing}=nothing,
    extra_flags::Vector{String}=String[],
)
    cmd = ["codex", "-q", "{task}", "--model", model]
    append!(cmd, extra_flags)

    ExternalAgentTool(;
        name=name,
        description=description,
        command=cmd,
        args=["task" => CLIArg(String, "Clear description of the coding task to perform.")],
        timeout=timeout,
        working_dir=working_dir,
        on_output=on_output,
    )
end

# ── Claude Code stream-json result parser ────────────────────────────────────

# Parse Claude Code's stream-json output to extract the final result.
# Looks for the last `{"type":"result",...}` line and extracts the result field.
function _parse_claude_code_result(lines::Vector{String})
    # Walk backwards to find the result line
    for i in length(lines):-1:1
        line = strip(lines[i])
        isempty(line) && continue
        try
            event = JSON3.read(line)
            if get(event, :type, nothing) == "result"
                is_error = get(event, :is_error, false)
                result = get(event, :result, nothing)
                cost = get(event, :total_cost_usd, nothing)
                subtype = get(event, :subtype, "")
                session_id = get(event, :session_id, nothing)

                parts = String[]
                if is_error || subtype != "success"
                    push!(parts, "Error ($(subtype)):")
                end
                if !isnothing(result) && !isempty(string(result))
                    push!(parts, string(result))
                end
                if !isnothing(cost)
                    push!(parts, "\n[Cost: \$$(round(cost; digits=4))]")
                end
                if !isnothing(session_id)
                    push!(parts, "[Session: $(session_id)]")
                end
                return join(parts, " ")
            end
        catch
            continue
        end
    end

    # No result line found — return raw output
    join(lines, "\n")
end
