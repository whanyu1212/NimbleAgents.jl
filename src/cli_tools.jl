###############################################################################
# cli_tools.jl — Expose shell commands as agent tools
#
# CLITool wraps any CLI program as an AbstractTool. Arguments from the LLM
# are substituted into {placeholder} slots in the command vector and passed
# as separate process arguments — never interpolated into a shell string, so
# injection is structurally impossible.
#
# Usage:
#
#   grep_tool = CLITool(
#       name        = "grep",
#       description = "Search for a pattern in files.",
#       command     = ["grep", "-rn", "{pattern}", "{path}"],
#       args        = OrderedDict(
#           "pattern" => CLIArg(String, "Regex pattern to search for."),
#           "path"    => CLIArg(String, "File or directory to search in."),
#       ),
#   )
#
#   agent = Agent(name="Searcher", tools=[grep_tool], ...)
###############################################################################

# ── CLIArg ────────────────────────────────────────────────────────────────────

"""
    CLIArg(type, description; required=true)

Describes one argument of a `CLITool`.

# Fields
- `type::Type`: Julia type for the argument (`String`, `Int`, `Float64`, `Bool`).
- `description::String`: Shown to the LLM in the tool schema.
- `required::Bool`: Whether the argument must be provided (default: `true`).
"""
struct CLIArg
    type::Type
    description::String
    required::Bool
    function CLIArg(type::Type, description::String; required::Bool=true)
        new(type, description, required)
    end
end

# ── CLITool ───────────────────────────────────────────────────────────────────

"""
    CLITool(; name, description, command, args, timeout, working_dir, return_direct)

An `AbstractTool` that runs a shell command as a subprocess.

Arguments from the LLM are substituted into `{arg_name}` placeholders in the
`command` vector. Each argument is passed as a separate process argument — no
shell string is constructed, making injection structurally impossible.

# Fields
- `name::String`: Tool name shown to the LLM.
- `description::String`: What the tool does and when to use it.
- `command::Vector{String}`: Command and arguments with `{placeholder}` slots.
- `args::Vector{Pair{String,CLIArg}}`: Ordered argument definitions.
- `timeout::Float64`: Seconds before the subprocess is killed (default: `30.0`).
- `working_dir::Union{String,Nothing}`: Working directory for the subprocess.
- `return_direct::Bool`: Short-circuit the agent loop after this tool (default: `false`).

# Example
```julia
git_log = CLITool(
    name        = "git_log",
    description = "Show recent git commits.",
    command     = ["git", "log", "--oneline", "-{n}"],
    args        = ["n" => CLIArg(Int, "Number of commits to show.")],
)

agent = Agent(
    name  = "DevBot",
    tools = [git_log],
)
```

# Example — multiple args
```julia
grep_tool = CLITool(
    name        = "grep",
    description = "Search for a pattern in files. Returns matching lines.",
    command     = ["grep", "-rn", "{pattern}", "{path}"],
    args        = [
        "pattern" => CLIArg(String, "Regex pattern to search for."),
        "path"    => CLIArg(String, "File or directory to search in."),
    ],
)
```
"""
struct CLITool <: AbstractTool
    name::String
    description::String
    command::Vector{String}
    args::Vector{Pair{String,CLIArg}}
    timeout::Float64
    working_dir::Union{String,Nothing}
    return_direct::Bool
    return_artifact::Bool

    # Pre-built JSON schema for the LLM (computed once at construction)
    parameters::Dict{String,Any}
    strict::Union{Bool,Nothing}
end

function CLITool(;
    name::String,
    description::String,
    command::Vector{String},
    args::Vector{Pair{String,CLIArg}}=Pair{String,CLIArg}[],
    timeout::Float64=30.0,
    working_dir::Union{String,Nothing}=nothing,
    return_direct::Bool=false,
    return_artifact::Bool=false,
    strict::Union{Bool,Nothing}=nothing,
)
    parameters = _cli_schema(args)
    CLITool(
        name,
        description,
        command,
        args,
        timeout,
        working_dir,
        return_direct,
        return_artifact,
        parameters,
        strict,
    )
end

# ── JSON schema generation ────────────────────────────────────────────────────

_julia_type_to_json(::Type{String}) = "string"
_julia_type_to_json(::Type{Int}) = "integer"
_julia_type_to_json(::Type{Float64}) = "number"
_julia_type_to_json(::Type{Bool}) = "boolean"
_julia_type_to_json(T::Type) = "string"   # fallback: stringify

function _cli_schema(args::Vector{Pair{String,CLIArg}})
    properties = Dict{String,Any}()
    required = String[]

    for (arg_name, arg) in args
        properties[arg_name] = Dict{String,Any}(
            "type" => _julia_type_to_json(arg.type), "description" => arg.description
        )
        arg.required && push!(required, arg_name)
    end

    schema = Dict{String,Any}("type" => "object", "properties" => properties)
    isempty(required) || (schema["required"] = required)
    schema
end

# ── Command rendering ─────────────────────────────────────────────────────────

# Substitute {arg_name} placeholders in each command token.
# Returns a Cmd (Vector{String} under the hood) — never a shell string.
function _render_command(tool::CLITool, args::Dict{Symbol,<:Any})
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

# ── Subprocess execution ──────────────────────────────────────────────────────

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

# ── _call_tool dispatch ───────────────────────────────────────────────────────

# CLITool has no callable field — add a method to the existing _call_tool generic.
_call_tool(tool::CLITool, args::Dict{Symbol,<:Any}) = _run_cli(tool, args)

# ── _is_return_direct ─────────────────────────────────────────────────────────

_is_return_direct(t::CLITool) = t.return_direct
_is_return_artifact(t::CLITool) = t.return_artifact
