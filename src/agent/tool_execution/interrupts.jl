###############################################################################
# agent/tool_execution/interrupts.jl — human-in-the-loop gating for tools
###############################################################################

function _handle_tool_interrupts!(
    conversation,
    last_msg::AIToolRequest,
    agent::Agent,
    hooks::AgentHooks,
    approval_channel::Union{Channel{String},Nothing},
    approval_timeout::Float64,
    verbose::Bool,
)::Bool
    isnothing(hooks.should_interrupt) && return true

    # should_interrupt: scan all pending tool calls before executing any.
    # Collect every flagged call so the human sees the full batch at once.
    flagged = filter(last_msg.tool_calls) do t
        hooks.should_interrupt(t.name, something(t.args, Dict()))
    end
    isempty(flagged) && return true

    names = join([t.name for t in flagged], ", ")
    if !isnothing(approval_channel)
        # Non-blocking path: pause mid-loop and wait for a response on the
        # channel. The agent holds all state — no re-run needed.
        verbose && println("[$(agent.name)] waiting for approval: $(names)")
        status = timedwait(approval_timeout) do
            isready(approval_channel) || !isopen(approval_channel)
        end
        if status == :timed_out
            throw(ApprovalTimeout(flagged, approval_timeout))
        end
        if !isopen(approval_channel)
            error("[$(agent.name)] approval_channel closed — aborting")
        end
        response = take!(approval_channel)
        # Inject the human's response into the conversation so the agent has
        # context when it continues.
        push!(conversation, UserMessage(response))
        return lowercase(strip(response)) == "approve"
    end

    # Blocking path: throw and let the caller handle it.
    throw(HumanInterrupt(flagged; message="About to call: $(names)"))
end
