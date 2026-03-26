###############################################################################
# external_agent/constructors.jl — convenience constructors for popular CLIs
###############################################################################

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
