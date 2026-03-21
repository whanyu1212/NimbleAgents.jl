###############################################################################
# claude_code_agent.jl — Use Claude Code as a sub-agent tool
#
# Demonstrates ExternalAgentTool: an orchestrator agent delegates coding tasks
# to Claude Code (running as a subprocess) with real-time progress streaming.
#
# Prerequisites:
#   - Claude Code CLI installed: npm install -g @anthropic-ai/claude-code
#   - Authenticated via ONE of:
#       • `claude login` (interactive, stores creds in ~/.claude/)
#       • ANTHROPIC_API_KEY in .env or environment (inherited by subprocess)
#
# Run:  julia --project examples/multi_agent/claude_code_agent.jl
###############################################################################

using DotEnv
DotEnv.load!()

using NimbleAgents
import JSON3

# ── Create the Claude Code tool ─────────────────────────────────────────────
#
# claude_code_tool() is a convenience constructor that wraps `claude -p`
# with stream-json output. The `on_output` callback fires for every line
# of output, enabling real-time progress visibility.

coder = claude_code_tool(
    working_dir = @__DIR__,
    model       = "sonnet",
    timeout     = 120.0,
    # Stream Claude Code's progress to the terminal
    on_output = line -> begin
        try
            event = JSON3.read(line)
            type = get(event, :type, "")
            if type == "assistant"
                # Print assistant text as it arrives
                for block in get(event, :message, (;)).content
                    text = get(block, :text, nothing)
                    !isnothing(text) && print("[claude] ", text, "\n")
                end
            elseif type == "result"
                cost = get(event, :total_cost_usd, nothing)
                !isnothing(cost) && println("[claude] Cost: \$$(round(cost; digits=4))")
            end
        catch
            # Not all lines are JSON (e.g. progress indicators)
        end
    end,
)

# ── Create the orchestrator agent ────────────────────────────────────────────
#
# The PM agent decides what to build and delegates to Claude Code.
# It receives the final result (extracted from stream-json) and can
# iterate or ask follow-up questions.

pm = Agent(
    name         = "PM",
    instructions = """You are a project manager. When the user asks for a coding task,
delegate it to the claude_code tool with a clear, specific description.
Review the result and report back to the user.""",
    tools        = [coder],
    max_iterations = 3,
)

# ── Run it ───────────────────────────────────────────────────────────────────

println("=" ^ 60)
println("PM Agent with Claude Code sub-agent")
println("=" ^ 60)
println()

result = run!(pm, "Create a simple Julia function in a file called fibonacci.jl that computes the nth Fibonacci number efficiently using memoization. Include docstrings and a few test cases at the bottom.")
println("\n", "=" ^ 60)
println("PM says: ", result)

# ── Session continuity (optional) ────────────────────────────────────────────
#
# Claude Code returns a session_id in its result. You can use it to continue
# the conversation in a follow-up call, preserving full context:
#
#   coder_resume = claude_code_tool(
#       session_id  = "the-session-id-from-previous-result",
#       working_dir = @__DIR__,
#   )
#
# Or resume the most recent session:
#
#   coder_latest = claude_code_tool(resume = true, working_dir = @__DIR__)
