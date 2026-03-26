###############################################################################
# eval.jl — Eval harness for testing agent behaviour against known cases
#
# Usage:
#
#   cases = [
#       EvalCase(input="What is 2+2?", expected="4",
#                expected_tools=["add"], tags=["math"]),
#   ]
#   report = run_eval(agent, cases; metrics=[exact_match, tool_trajectory])
#   print_eval(report)
#   save_eval(report, "eval_results.json")
###############################################################################

using JSON3: JSON3

include("eval/types.jl")
include("eval/metrics.jl")
include("eval/runner.jl")
include("eval/display.jl")
include("eval/persistence.jl")
