###############################################################################
# builtins/repl.jl — persistent Julia REPL tool
#
# Evaluates Julia code in a persistent sandbox Module that lives for the
# duration of a session. State accumulates across calls:
#
#   eval_julia("x = [1, 2, 3]")   → "3-element Vector{Int64}: ..."
#   eval_julia("sum(x)")           → "6"
#   eval_julia("using Statistics") → ""
#   eval_julia("mean(x)")          → "2.0"
#
# The sandbox is stored in session.state["_julia_sandbox"]. When no session
# is provided, a fresh module is created per tool call (stateless).
#
# Execution happens in a Threads.@spawn task so a timeout can be enforced
# without blocking the agent thread.
###############################################################################

# ── Sandbox management ────────────────────────────────────────────────────────

# Create or retrieve the persistent sandbox module for a session.
# Key in session.state: "_julia_sandbox"
function _get_sandbox(session_state::Union{Dict{String,Any},Nothing})::Module
    if !isnothing(session_state)
        if !haskey(session_state, "_julia_sandbox")
            session_state["_julia_sandbox"] = _new_sandbox()
        end
        return session_state["_julia_sandbox"]
    end
    _new_sandbox()   # stateless fallback: fresh module each call
end

function _new_sandbox()::Module
    # Anonymous module inheriting from Main so stdlib is available
    m = Module(gensym("NimbleSandbox"))
    # Bring Core and Base into scope
    Core.eval(m, :(using Base))
    m
end

# ── Result formatting ─────────────────────────────────────────────────────────

# Format an eval result for the LLM:
# - Primitives and collections: repr()
# - Functions / Modules / DataTypes: suppress (return "")
# - Anything that responds to savefig (Plots, Makie, etc.): save to a temp
#   file and return the path so the agent knows where to find it.
function _format_result(result)::String
    # Suppress implementation-detail types that are noise for the LLM
    result isa Function && return ""
    result isa Module && return ""
    result isa DataType && return ""

    # Plot-like: anything that has a savefig method defined for it.
    # We check without importing Plots/Makie — just look for the method.
    if _has_savefig(result)
        path = tempname() * ".png"
        try
            # Call savefig via the generic name — works for Plots, Makie, etc.
            savefig_fn = getfield(parentmodule(typeof(result)), :savefig)
            savefig_fn(result, path)
            # Register as session artifact if a session is active
            session = get(task_local_storage(), :_current_session, nothing)
            store = get(task_local_storage(), :_current_store, nothing)
            if !isnothing(session)
                register_artifact!(
                    session,
                    path;
                    name="plot_" * basename(path),
                    store=store,
                    metadata=Dict{String,Any}("source" => "eval_julia"),
                )
            end
            return "Plot saved to: $(path)"
        catch e
            return "Plot result (could not save: $(sprint(showerror, e)))"
        end
    end

    # Everything else: use repr, but guard against repr() itself throwing
    try
        repr(result)
    catch
        "(result of type $(typeof(result)))"
    end
end

# Check if a savefig method exists for this value's type without importing
# any plotting package — avoids hard dependencies.
function _has_savefig(result)::Bool
    T = typeof(result)
    m = parentmodule(T)
    isdefined(m, :savefig) || return false
    fn = getfield(m, :savefig)
    !isempty(methods(fn, (T, String))) || !isempty(methods(fn, (T, AbstractString)))
end

# ── Code execution ────────────────────────────────────────────────────────────

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

# ── eval_julia_tool ───────────────────────────────────────────────────────────

"""
    eval_julia_tool

Built-in tool that evaluates Julia code in a persistent sandbox.

The sandbox persists for the lifetime of the session — variables, imports,
and function definitions all carry over between calls. The project environment
is active, so any package in `Project.toml` can be loaded with `using`.

Pair with a `Session` to get persistent state across turns:

```julia
session = Session(app_name="DataSession", user_id="alice")
agent   = Agent(
    name  = "DataBot",
    tools = [eval_julia_tool],
)
run!(agent, "Load DataFrames and create a DataFrame with columns a and b"; session=session)
run!(agent, "Now compute the mean of column a"; session=session)
```
"""
const eval_julia_tool = NimbleTool(;
    name="eval_julia",
    description="""Evaluate Julia code in a persistent sandbox and return the result.

The sandbox retains state across calls within the same session — variables,
imports, and function definitions all persist. The full project environment
is available: use `using PackageName` to load any package in Project.toml.

Use this tool to:
- Perform calculations and data analysis
- Load and manipulate data (DataFrames, arrays, etc.)
- Generate plots and visualisations
- Run any Julia code that requires computation

Stdout output and the return value of the last expression are both captured
and returned. Errors are caught and returned as strings.""",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "code" => Dict{String,Any}(
                "type" => "string", "description" => "Julia code to evaluate."
            ),
            "timeout" => Dict{String,Any}(
                "type" => "number",
                "description" => "Timeout in seconds (default: 60).",
            ),
        ),
        "required" => ["code"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        code = get(args, :code, "")
        timeout = get(args, :timeout, 60)

        # Retrieve sandbox from session state if available.
        # session_state is injected via the _REPL_SESSION_STATE task-local
        # set by run! when eval_julia_tool is in the tool list.
        session_state = get(task_local_storage(), :_repl_session_state, nothing)
        sandbox = _get_sandbox(session_state)

        _eval_in_sandbox(sandbox, code, timeout)
    end,
)
