###############################################################################
# external_agent.jl — Wrap external CLI agents (Claude Code, Codex) as tools
#
# ExternalAgentTool runs an external CLI agent as a subprocess, streaming its
# stdout line-by-line so callers can observe progress in real-time. Designed
# for long-running agents that produce structured (JSON) output.
#
# Usage:
#
#   coder = ExternalAgentTool(
#       name        = "claude_code",
#       description = "Delegate coding tasks to Claude Code.",
#       command     = ["claude", "-p", "{task}", "--output-format", "stream-json",
#                      "--verbose", "--model", "sonnet"],
#       args        = ["task" => CLIArg(String, "The coding task to perform.")],
#       timeout     = 300.0,
#       on_output   = line -> println("[claude] ", line),
#   )
#
#   agent = Agent(name="PM", tools=[coder], ...)
#
# A convenience constructor `claude_code_tool(; ...)` is provided for the
# common case of wrapping Claude Code.
###############################################################################

using JSON3: JSON3

include("external_agent/types.jl")
include("external_agent/execution.jl")
include("external_agent/parser.jl")
include("external_agent/constructors.jl")
