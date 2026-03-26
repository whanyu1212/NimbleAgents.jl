###############################################################################
# repl/chat_loop.jl — interactive chat loop
###############################################################################

"""
    chat!(agent::Agent; session, model, verbose)

Start an interactive multi-turn conversation with `agent` in the Julia REPL.

Tokens stream to stdout as they arrive. Conversation history accumulates in the
session across turns, so the agent maintains context throughout the conversation.

# Slash Commands
- `/exit` or `/quit` — end the conversation
- `/reset` — clear conversation history and start fresh
- `/trace` — show token usage, cost, and tool call summary
- `/help` — show available commands

# Arguments
- `agent::Agent`: The agent to chat with.
- `session::Session`: Session for conversation history (default: auto-created).
- `verbose::Bool`: Show tool call details (default: `false`).

# Example
```julia
agent = Agent(name="Bot", instructions="You are helpful.", tools=[search_tool])
chat!(agent)
```
"""
function chat!(
    agent::Agent;
    session::Session=Session(app_name="chat", user_id="repl"),
    verbose::Bool=false,
)
    name = agent.name
    _chat_header(name)

    while true
        input = _read_chat_input()::Union{Nothing,String}
        isnothing(input) && break

        input = strip(input)
        isempty(input) && continue

        cmd_state = _handle_chat_command!(input, session, name)
        cmd_state === :exit && break
        cmd_state === :handled && continue
        _run_chat_turn!(agent, input, session, verbose)
    end

    _chat_footer(session)
end

function _read_chat_input()::Union{Nothing,String}
    printstyled("You> "; color=:green, bold=true)
    try
        readline()
    catch e
        e isa InterruptException && return nothing
        rethrow()
    end
end

function _handle_chat_command!(input::String, session::Session, name::String)::Symbol
    startswith(input, "/") || return :none

    cmd = lowercase(strip(input))
    if cmd in ("/exit", "/quit")
        return :exit
    elseif cmd == "/reset"
        reset!(session)
        printstyled("  Session reset.\n\n"; color=:yellow)
    elseif cmd == "/trace"
        _chat_trace(session, name)
    elseif cmd == "/help"
        _chat_help()
    else
        printstyled("  Unknown command: $(input). Type /help for options.\n\n"; color=:red)
    end

    :handled
end

function _run_chat_turn!(agent::Agent, input::String, session::Session, verbose::Bool)
    printstyled("$(agent.name)> "; color=:cyan, bold=true)
    try
        run!(
            agent,
            input;
            session=session,
            verbose=verbose,
            on_token=token -> print(token),
        )
    catch e
        if e isa HumanInterrupt
            _resume_chat_after_interrupt!(agent, e, session, verbose)
        else
            printstyled("\n  Error: $(sprint(showerror, e))\n"; color=:red)
        end
    end
    println("\n")
end

function _resume_chat_after_interrupt!(
    agent::Agent,
    e::HumanInterrupt,
    session::Session,
    verbose::Bool,
)
    printstyled("\n  [Interrupted — tool approval required]\n"; color=:yellow)
    printstyled("  Tools: $(join([t.name for t in e.tool_calls], ", "))\n"; color=:yellow)
    printstyled("  Type 'approve' or a redirect message:\n"; color=:yellow)
    printstyled("  > "; color=:yellow)
    response = strip(readline())
    if lowercase(response) == "approve"
        resume!(session, "Approved. Please proceed.")
    else
        resume!(session, "Rejected. $(response)")
    end

    # Re-run to continue
    printstyled("$(agent.name)> "; color=:cyan, bold=true)
    run!(agent, ""; session=session, verbose=verbose, on_token=token -> print(token))
end
