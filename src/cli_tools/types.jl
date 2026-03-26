###############################################################################
# cli_tools/types.jl — CLITool public types and constructors
###############################################################################

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
