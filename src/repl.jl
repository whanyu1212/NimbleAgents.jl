###############################################################################
# repl.jl — Interactive REPL chat with an agent
#
# Provides `chat!` for multi-turn conversational interaction inside the Julia
# REPL. Supports streaming, session persistence, and slash commands.
#
# Usage:
#
#   # Chat with any agent
#   chat!(my_agent)
#
#   # Chat with the built-in NimbleAgents docs bot
#   chat!()
#
#   # With an existing session
#   chat!(my_agent; session=my_session)
#
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

    chat!(; model)

Start a conversation with the built-in NimbleAgents documentation bot. It has
access to the framework's source code, docs, and examples via filesystem tools.

Requires an LLM API key — set `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or
`GOOGLE_API_KEY` in your environment or `.env` file.

# Arguments
- `model::String`: LLM model to use (default: `"gpt-4.1-nano"`).

# Example
```julia
using NimbleAgents
chat!()
# You> How do I add guardrails to an agent?
# NimbleAgents> ...
```
"""
function chat!(agent::Agent;
    session ::Session = Session(app_name="chat", user_id="repl"),
    verbose ::Bool    = false,
)
    name = agent.name
    _chat_header(name)

    while true
        # Prompt
        printstyled("You> "; color=:green, bold=true)
        input = try
            readline()
        catch e
            e isa InterruptException && break
            rethrow()
        end

        # EOF (Ctrl+D)
        isnothing(input) && break
        input = strip(input)
        isempty(input) && continue

        # Slash commands
        if startswith(input, "/")
            cmd = lowercase(strip(input))
            if cmd in ("/exit", "/quit")
                break
            elseif cmd == "/reset"
                reset!(session)
                printstyled("  Session reset.\n\n"; color=:yellow)
                continue
            elseif cmd == "/trace"
                _chat_trace(session, name)
                continue
            elseif cmd == "/help"
                _chat_help()
                continue
            else
                printstyled("  Unknown command: $(input). Type /help for options.\n\n";
                            color=:red)
                continue
            end
        end

        # Run agent with streaming
        printstyled("$(name)> "; color=:cyan, bold=true)
        try
            run!(agent, input;
                 session  = session,
                 verbose  = verbose,
                 on_token = token -> print(token))
        catch e
            if e isa HumanInterrupt
                printstyled("\n  [Interrupted — tool approval required]\n";
                            color=:yellow)
                printstyled("  Tools: $(join([t.name for t in e.tool_calls], ", "))\n";
                            color=:yellow)
                printstyled("  Type 'approve' or a redirect message:\n"; color=:yellow)
                printstyled("  > "; color=:yellow)
                response = strip(readline())
                if lowercase(response) == "approve"
                    resume!(session, "Approved. Please proceed.")
                else
                    resume!(session, "Rejected. $(response)")
                end
                # Re-run to continue
                printstyled("$(name)> "; color=:cyan, bold=true)
                run!(agent, "";
                     session  = session,
                     verbose  = verbose,
                     on_token = token -> print(token))
            else
                printstyled("\n  Error: $(sprint(showerror, e))\n"; color=:red)
            end
        end
        println("\n")
    end

    _chat_footer(session)
end

# No-arg version: NimbleAgents docs bot
function chat!(; model::String = "gpt-4.1-nano")
    pkg_dir = pkgdir(@__MODULE__)
    if isnothing(pkg_dir)
        error("Cannot locate NimbleAgents package directory. " *
              "Are you running from a development checkout?")
    end

    agent = Agent(
        name         = "NimbleAgents",
        model        = model,
        instructions = """You are a documentation assistant for NimbleAgents.jl — a Julia framework for building AI agents.

You answer questions about the framework by reading its source code, documentation, and examples.
Always base your answers on the actual files — do not guess or hallucinate APIs.

The project root is: $(pkg_dir)

Key directories:
- $(pkg_dir)/docs/src/guide/ — user-facing documentation (Markdown)
- $(pkg_dir)/src/ — source code
- $(pkg_dir)/examples/ — runnable examples organized by topic
- $(pkg_dir)/CLAUDE.md — architecture overview and conventions
- $(pkg_dir)/README.md — project overview

When answering:
1. Search for relevant files first using grep or glob
2. Read the specific file(s) to get accurate information
3. Include code examples from the actual source when helpful
4. Reference file paths so the user can find more details""",
        tools = [read_file_tool, glob_tool, grep_tool, list_dir_tool],
    )

    chat!(agent)
end

# ── Helpers ──────────────────────────────────────────────────────────────────

function _chat_header(name::String)
    println()
    printstyled("─" ^ 60; color=:light_black)
    println()
    printstyled("  $name"; color=:cyan, bold=true)
    printstyled(" — interactive chat\n"; color=:light_black)
    printstyled("  Type /help for commands, Ctrl+D or /exit to quit.\n";
                color=:light_black)
    printstyled("─" ^ 60; color=:light_black)
    println("\n")
end

function _chat_footer(session::Session)
    n_turns = length(session.events)
    total_input  = sum(e.input_tokens  for e in session.events; init=0)
    total_output = sum(e.output_tokens for e in session.events; init=0)
    total_cost   = sum(e.cost          for e in session.events; init=0.0)

    println()
    printstyled("─" ^ 60; color=:light_black)
    println()
    printstyled("  Session ended. "; color=:light_black)
    printstyled("$(n_turns) turns"; color=:white, bold=true)
    printstyled(", $(total_input + total_output) tokens"; color=:light_black)
    if total_cost > 0
        printstyled(", \$$(round(total_cost; digits=4))"; color=:light_black)
    end
    println()
    printstyled("─" ^ 60; color=:light_black)
    println("\n")
end

function _chat_trace(session::Session, name::String)
    if isempty(session.events)
        printstyled("  No turns recorded yet.\n\n"; color=:yellow)
        return
    end

    trace = Trace(session)
    println()
    printstyled("  ── Trace "; color=:light_black)
    printstyled("─" ^ 48; color=:light_black)
    println()
    printstyled("  Turns:   $(trace.total_turns)\n"; color=:white)
    printstyled("  Input:   $(trace.total_input_tokens) tokens\n"; color=:white)
    printstyled("  Output:  $(trace.total_output_tokens) tokens\n"; color=:white)
    printstyled("  Tools:   $(trace.total_tool_calls) calls\n"; color=:white)
    if trace.total_cost > 0
        printstyled("  Cost:    \$$(round(trace.total_cost; digits=4))\n"; color=:white)
    end
    printstyled("  "; color=:light_black)
    printstyled("─" ^ 58; color=:light_black)
    println("\n")
end

function _chat_help()
    println()
    printstyled("  Commands:\n"; color=:white, bold=true)
    printstyled("    /help    "; color=:cyan)
    printstyled("Show this help message\n"; color=:light_black)
    printstyled("    /reset   "; color=:cyan)
    printstyled("Clear conversation history\n"; color=:light_black)
    printstyled("    /trace   "; color=:cyan)
    printstyled("Show token usage and cost summary\n"; color=:light_black)
    printstyled("    /exit    "; color=:cyan)
    printstyled("End the conversation\n"; color=:light_black)
    println()
end
