###############################################################################
# agent/types/interrupts.jl — human approval interrupts and resume helper
###############################################################################

"""
    HumanInterrupt(tool_calls; message)

Thrown from `after_llm_call` to pause the agent loop before any tool executes.

The LLM has produced a plan (`tool_calls`) but no side-effects have occurred yet.
The caller catches this, presents the pending actions to a human, and either:
- **Approves** → calls `resume!(session, "Approved")` and re-runs `run!`
- **Rejects**  → calls `resume!(session, "Rejected — do X instead")` and re-runs `run!`
- **Aborts**   → discards the session entirely

# Fields
- `tool_calls`: The pending tool calls the LLM intended to execute.
- `message::String`: Optional context message (default: `"Human approval required"`).

# Example
```julia
hooks = AgentHooks(
    after_llm_call = (agent, iter, msg) -> begin
        dangerous = ["delete_file", "send_email", "write_db"]
        pending   = filter(t -> t.name in dangerous, something(msg.tool_calls, []))
        isempty(pending) && return
        throw(HumanInterrupt(pending;
            message = "About to: " * join([t.name for t in pending], ", ")))
    end
)
```
"""
struct HumanInterrupt <: Exception
    tool_calls::Any     # Vector of PT ToolMessage objects
    message::String
    function HumanInterrupt(tool_calls; message::String="Human approval required")
        new(tool_calls, message)
    end
end

function Base.showerror(io::IO, e::HumanInterrupt)
    print(
        io,
        "HumanInterrupt: ",
        e.message,
        "\n  Pending tool calls: ",
        join([t.name for t in e.tool_calls], ", "),
    )
end

"""
    ApprovalTimeout(tool_calls, timeout)

Thrown when an `approval_channel` is provided but no response arrives within
`approval_timeout` seconds.
"""
struct ApprovalTimeout <: Exception
    tool_calls::Any
    timeout::Float64
end

function Base.showerror(io::IO, e::ApprovalTimeout)
    print(
        io,
        "ApprovalTimeout: no response received within $(e.timeout)s\n",
        "  Pending tool calls: ",
        join([t.name for t in e.tool_calls], ", "),
    )
end

"""
    resume!(session, human_response)

Inject a human approval/rejection into `session.history` so the agent can
continue after a `HumanInterrupt`. Call `run!` again after this.

```julia
try
    run!(agent, input; session=session)
catch e
    e isa HumanInterrupt || rethrow(e)
    println("Pending: ", e.message)
    response = readline()
    resume!(session, response)
    run!(agent, input; session=session)
end
```
"""
function resume!(session::Session, human_response::String)
    lock(session.lock) do
        push!(session.history, UserMessage(human_response))
    end
end
