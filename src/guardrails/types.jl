###############################################################################
# guardrails/types.jl — guardrail result and configuration types
###############################################################################

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

struct GuardrailBlocked <: Exception
    guardrail_name::String
    reason::String
end
