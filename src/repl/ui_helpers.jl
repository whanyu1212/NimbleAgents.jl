###############################################################################
# repl/ui_helpers.jl — terminal rendering helpers for chat!
###############################################################################

function _chat_header(name::String)
    println()
    printstyled("─" ^ 60; color=:light_black)
    println()
    printstyled("  $name"; color=:cyan, bold=true)
    printstyled(" — interactive chat\n"; color=:light_black)
    printstyled("  Type /help for commands, Ctrl+D or /exit to quit.\n"; color=:light_black)
    printstyled("─" ^ 60; color=:light_black)
    println("\n")
end

function _chat_footer(session::Session)
    n_turns = length(session.events)
    total_input = sum(e.input_tokens for e in session.events; init=0)
    total_output = sum(e.output_tokens for e in session.events; init=0)
    total_cost = sum(e.cost for e in session.events; init=0.0)

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

function _chat_trace(session::Session, _name::String)
    if isempty(session.events)
        printstyled("  No turns recorded yet.\n\n"; color=:yellow)
        return nothing
    end

    trace = Trace(session)
    println()
    printstyled("  ── Trace "; color=:light_black)
    printstyled("─" ^ 48; color=:light_black)
    println()
    printstyled("  Turns:   $(length(trace.turns))\n"; color=:white)
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
