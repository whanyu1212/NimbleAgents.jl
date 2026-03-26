###############################################################################
# agent/types/context.jl — context-window compaction config
###############################################################################

"""
    ContextConfig(; context_window, compact_threshold, keep_last, summary_model)

Controls automatic context-window management for long-running sessions.

When `session.history` grows large enough to risk hitting the model's context
limit, NimbleAgents compacts it using a **hybrid strategy**:

1. The most recent `keep_last` messages are always kept verbatim — they carry
   the immediate context the model needs for the current turn.
2. Everything older is summarised into a single compressed message by the LLM,
   replacing the raw history.

This mirrors the approach used by Claude Code and Codex: compact at ~80% of the
context window, not at 100%, so there is always headroom for the current turn's
input and the model's output.

# Fields
- `context_window::Int`: Total token capacity of the model (default: `400_000`).
  Set to match Claude Opus 4.5/4.6 (400k context, 128k max output).
- `compact_threshold::Float64`: Fraction of `context_window` at which compaction
  is triggered (default: `0.80`).  At 80% × 400k = 320k tokens, there is still
  80k of headroom — enough for a large current-turn input plus a full output.
  Claude Code and Codex both use ~80% as their trigger.
- `keep_last::Int`: Number of recent messages to preserve verbatim after
  compaction (default: `20`). These are never summarised so the agent retains
  immediate conversational context.
- `summary_model::Union{String,Nothing}`: Model used for the summarisation call.
  Defaults to `nothing`, which means the agent's own model is used.

# Example
```julia
# Long-running session with aggressive compaction
session_agent = Agent(
    name    = "LongBot",
    instructions = "...",
    context = ContextConfig(keep_last=10),
)
```
"""
Base.@kwdef struct ContextConfig
    # Claude Opus 4.5/4.6: 400k context window, 128k max output.
    context_window::Int = 400_000
    # Trigger at 80% — same heuristic as Claude Code and Codex.
    # Leaves 80k headroom for current-turn input + model output.
    compact_threshold::Float64 = 0.80
    # Keep the 20 most recent messages verbatim so the agent has
    # immediate context; only older messages are summarised.
    keep_last::Int = 20
    summary_model::Union{String,Nothing} = nothing
end
