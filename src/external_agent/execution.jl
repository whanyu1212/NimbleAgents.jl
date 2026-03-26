###############################################################################
# external_agent/execution.jl — subprocess execution and tool dispatch
###############################################################################

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

function _call_tool(tool::ExternalAgentTool, args::Dict{Symbol,<:Any})
    _run_external_agent(tool, args)
end
_is_return_direct(t::ExternalAgentTool) = t.return_direct
_is_return_artifact(t::ExternalAgentTool) = t.return_artifact
