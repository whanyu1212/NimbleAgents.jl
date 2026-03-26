###############################################################################
# cli_tools/render.jl — command rendering from tool arguments
###############################################################################

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
