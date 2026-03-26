###############################################################################
# builtins/repl/execution.jl — sandboxed code execution with timeout
###############################################################################

function _eval_in_sandbox(sandbox::Module, code::String, timeout::Real)::String
    # Parse first (outside the task — fast, no need for timeout)
    parsed = try
        Meta.parse(code)
    catch e
        return "ParseError: $(sprint(showerror, e))"
    end
    if parsed isa Expr && parsed.head == :error
        return "ParseError: $(parsed.args[1])"
    end
    if parsed isa Expr && parsed.head == :incomplete
        return "ParseError: incomplete expression"
    end

    result_ref = Ref{Any}(nothing)
    err_ref = Ref{Any}(nothing)
    out_ref = Ref{String}("")
    err_out_ref = Ref{String}("")

    task = Threads.@spawn begin
        # Set up Pipe-based stdout/stderr capture (IOBuffer not supported in 1.12)
        stdout_pipe = Pipe()
        stderr_pipe = Pipe()
        Base.link_pipe!(stdout_pipe; reader_supports_async=true, writer_supports_async=true)
        Base.link_pipe!(stderr_pipe; reader_supports_async=true, writer_supports_async=true)

        try
            redirect_stdout(stdout_pipe.in) do
                redirect_stderr(stderr_pipe.in) do
                    result_ref[] = Core.eval(sandbox, parsed)
                end
            end
        catch e
            err_ref[] = sprint(showerror, e)
        finally
            close(stdout_pipe.in)
            close(stderr_pipe.in)
            out_ref[] = String(read(stdout_pipe.out))
            err_out_ref[] = String(read(stderr_pipe.out))
        end
    end

    status = timedwait(() -> istaskdone(task), float(timeout))
    status == :timed_out && return "Error: execution timed out after $(timeout)s."

    if !isnothing(err_ref[])
        out = strip(out_ref[])
        msg = "Error: $(err_ref[])"
        return isempty(out) ? msg : "$(out)\n$(msg)"
    end

    # Build result: printed output + repr of return value
    parts = String[]
    out = strip(out_ref[])
    err = strip(err_out_ref[])
    isempty(out) || push!(parts, out)
    isempty(err) || push!(parts, "[stderr]\n$(err)")

    result = result_ref[]
    if !isnothing(result) && !(result isa Nothing)
        push!(parts, _format_result(result))
    end

    isempty(parts) ? "" : join(parts, "\n")
end
