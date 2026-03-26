###############################################################################
# builtins/shell.jl — built-in shell execution tool
#
# WARNING: bash_tool executes arbitrary shell commands. Pair with
# should_interrupt or approval_channel in any production context.
###############################################################################

"""
    bash_tool

Built-in `NimbleTool` that executes shell commands and returns combined output.
"""
const bash_tool = NimbleTool(;
    name="bash",
    description="""Run a shell command and return its output.
Use for tasks that require shell utilities, build tools, package managers, or
anything not covered by the other built-in tools.

⚠ Runs with the same permissions as the Julia process. Use with care.""",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "command" => Dict{String,Any}(
                "type" => "string", "description" => "Shell command to execute."
            ),
            "working_dir" => Dict{String,Any}(
                "type" => "string",
                "description" => "Working directory for the command (default: current directory).",
            ),
            "timeout" => Dict{String,Any}(
                "type" => "integer",
                "description" => "Timeout in seconds (default: 30).",
            ),
        ),
        "required" => ["command"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        command = get(args, :command, "")
        working_dir = get(args, :working_dir, ".")
        timeout = get(args, :timeout, 30)
        isdir(working_dir) ||
            return "Error: working directory not found: $(working_dir)"

        stdout_buf = IOBuffer()
        stderr_buf = IOBuffer()

        cmd = Cmd(`sh -c $command`; dir=working_dir)
        proc = run(pipeline(cmd; stdout=stdout_buf, stderr=stderr_buf); wait=false)

        t_start = time()
        while process_running(proc)
            if time() - t_start > timeout
                kill(proc)
                out = String(take!(stdout_buf))
                return "Error: command timed out after $(timeout)s." *
                       (isempty(out) ? "" : "\nPartial output:\n$(out)")
            end
            sleep(0.05)
        end

        out = strip(String(take!(stdout_buf)))
        err = strip(String(take!(stderr_buf)))
        code = proc.exitcode

        result = if !isempty(out) && !isempty(err)
            "$(out)\n[stderr]\n$(err)"
        elseif !isempty(out)
            out
        elseif !isempty(err)
            "[stderr]\n$(err)"
        else
            "(no output)"
        end

        code == 0 ? result : "Error (exit $(code)):\n$(result)"
    end,
)
