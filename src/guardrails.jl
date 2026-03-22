###############################################################################
# guardrails.jl — Input and output guardrails for Agent
#
# Guardrails are checks that run at the boundary of the agent loop:
#   - :input  guardrails run on the user's message before the loop starts
#   - :output guardrails run on the agent's final response before it is returned
#
# Each guardrail's check function returns one of:
#   Pass()          — allow execution to continue unchanged
#   Block(reason)   — halt and return reason as the agent's response
#   Modify(value)   — replace the input/output with a new value
#
# Usage:
#
#   no_pii = Guardrail(
#       name  = "no_pii",
#       on    = :input,
#       check = input -> occursin(r"\d{3}-\d{2}-\d{4}", input) ?
#                        Block("Input contains a Social Security Number.") : Pass(),
#   )
#
#   agent = Agent(
#       name       = "SecureBot",
#       guardrails = [no_pii],
#       ...
#   )
###############################################################################

# ── GuardrailResult ───────────────────────────────────────────────────────────

"""
    Pass()

Guardrail result — allow execution to continue unchanged.
"""
struct Pass end

"""
    Block(reason::String)

Guardrail result — halt execution and return `reason` as the agent's response.
"""
struct Block
    reason::String
end

"""
    Modify(value::String)

Guardrail result — replace the current input or output with `value` and continue.
"""
struct Modify
    value::String
end

const GuardrailResult = Union{Pass,Block,Modify}

# ── Guardrail ─────────────────────────────────────────────────────────────────

"""
    Guardrail(; name, check, on=:input)

A check that runs at the boundary of the agent loop.

# Fields
- `name::String`: Human-readable label shown in verbose output.
- `check::Function`: `(value::String) -> GuardrailResult`. Return `Pass()` to
  continue, `Block(reason)` to halt, or `Modify(new_value)` to rewrite.
- `on::Symbol`: When to run — `:input` (before the agent loop) or `:output`
  (after the agent produces its final response). Default: `:input`.

# Examples

```julia
# Rule-based input guardrail
no_pii = Guardrail(
    name  = "no_pii",
    on    = :input,
    check = input -> occursin(r"\\d{3}-\\d{2}-\\d{4}", input) ?
                     Block("Input contains a Social Security Number.") : Pass(),
)

# Sanitising input guardrail
strip_html = Guardrail(
    name  = "strip_html",
    on    = :input,
    check = input -> Modify(replace(input, r"<[^>]+>" => "")),
)

# Output guardrail
no_links = Guardrail(
    name  = "no_links",
    on    = :output,
    check = output -> occursin(r"https?://", output) ?
                      Block("Response contained external links.") : Pass(),
)

agent = Agent(
    name       = "SafeBot",
    guardrails = [no_pii, strip_html, no_links],
    ...
)
```
"""
struct Guardrail
    name::String
    check::Function
    on::Symbol   # :input or :output

    function Guardrail(; name::String, check::Function, on::Symbol=:input)
        on in (:input, :output) ||
            error("Guardrail `on` must be :input or :output, got :$(on)")
        new(name, check, on)
    end
end

# ── _run_guardrails ───────────────────────────────────────────────────────────

# Run all guardrails for a given phase (:input or :output) against `value`.
# Returns either the (possibly modified) value as a String, or throws a
# GuardrailBlocked exception to be caught by run!.

struct GuardrailBlocked <: Exception
    guardrail_name::String
    reason::String
end

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
