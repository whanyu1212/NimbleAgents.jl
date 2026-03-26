###############################################################################
# guardrails/runner.jl — guardrail execution
###############################################################################

# Run all guardrails for a given phase (:input or :output) against `value`.
# Returns either the (possibly modified) value as a String, or throws a
# GuardrailBlocked exception to be caught by run!.
function _run_guardrails(
    guardrails::Vector{Guardrail},
    phase::Symbol,
    value::String,
    agent_name::String,
    verbose::Bool,
)::String
    current = value
    for g in guardrails
        g.on == phase || continue
        result = try
            g.check(current)
        catch e
            # Guardrail errors are treated as blocks to fail safe
            throw(GuardrailBlocked(g.name, "Guardrail error: $(sprint(showerror, e))"))
        end
        if result isa Pass
            continue
        elseif result isa Block
            verbose &&
                println("[$(agent_name)] guardrail '$(g.name)' blocked: $(result.reason)")
            throw(GuardrailBlocked(g.name, result.reason))
        elseif result isa Modify
            verbose && println("[$(agent_name)] guardrail '$(g.name)' modified $(phase)")
            current = result.value
        end
    end
    current
end
