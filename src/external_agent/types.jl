###############################################################################
# external_agent/types.jl — external agent tool model
###############################################################################

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
