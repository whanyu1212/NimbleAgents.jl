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

include("cli_tools/types.jl")
include("cli_tools/schema.jl")
include("cli_tools/render.jl")
include("cli_tools/runner.jl")
