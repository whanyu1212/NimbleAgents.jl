###############################################################################
# guardrails.jl — Input and output guardrails for Agent
#
# Guardrails are checks that run at the boundary of the agent loop:
#   - :input  guardrails run on the user's message before the loop starts
#   - :output guardrails run on the agent's final response before it is returned
#
# Each guardrail's check function returns one of:
#   Pass()          — allow execution to continue unchanged
#   Block(reason)   — halt and return reason as the agent's response
#   Modify(value)   — replace the input/output with a new value
#
# Usage:
#
#   no_pii = Guardrail(
#       name  = "no_pii",
#       on    = :input,
#       check = input -> occursin(r"\d{3}-\d{2}-\d{4}", input) ?
#                        Block("Input contains a Social Security Number.") : Pass(),
#   )
#
#   agent = Agent(
#       name       = "SecureBot",
#       guardrails = [no_pii],
#       ...
#   )
###############################################################################

include("guardrails/types.jl")
include("guardrails/runner.jl")
