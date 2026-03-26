###############################################################################
# cli_tools/runner.jl — subprocess execution and tool dispatch integration
###############################################################################

function _run_cli(tool::CLITool, args::Dict{Symbol,<:Any})
    cmd = _render_command(tool, args)

    # Apply working directory if set
    if !isnothing(tool.working_dir)
        cmd = Cmd(cmd; dir=tool.working_dir)
    end

    stdout_buf = IOBuffer()
    stderr_buf = IOBuffer()

    proc = run(pipeline(cmd; stdout=stdout_buf, stderr=stderr_buf); wait=false)

    # Wait with timeout
    timed_out = false
    t_start = time()
    while process_running(proc)
        if time() - t_start > tool.timeout
            kill(proc)
            timed_out = true
            break
        end
        sleep(0.05)
    end

    out = String(take!(stdout_buf))
    err = String(take!(stderr_buf))

    if timed_out
        return "Error: command timed out after $(tool.timeout)s.\n" *
               (isempty(out) ? "" : "Partial stdout:\n$(out)")
    end

    exit_code = proc.exitcode

    # Combine stdout and stderr into a single result string
    result = if !isempty(out) && !isempty(err)
        "$(out)\n[stderr]\n$(err)"
    elseif !isempty(out)
        out
    elseif !isempty(err)
        "[stderr]\n$(err)"
    else
        "(no output)"
    end

    exit_code == 0 ? result : "Error (exit code $(exit_code)):\n$(result)"
end

# CLITool has no callable field — add a method to the existing _call_tool generic.
_call_tool(tool::CLITool, args::Dict{Symbol,<:Any}) = _run_cli(tool, args)

_is_return_direct(t::CLITool) = t.return_direct
_is_return_artifact(t::CLITool) = t.return_artifact
