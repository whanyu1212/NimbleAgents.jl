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

include("repl/sandbox.jl")
include("repl/formatting.jl")
include("repl/execution.jl")
include("repl/tool.jl")
