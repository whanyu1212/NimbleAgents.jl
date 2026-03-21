```@meta
CurrentModule = NimbleAgents
```

# Guardrails

Guardrails are safety checks attached directly to an `Agent`. They run at the boundary of the agent loop — before the LLM is called (input) or after the final response is assembled (output) — and can allow, block, or rewrite content.

## Overview

```
User input → [input guardrails] → Agent loop → [output guardrails] → Response
```

Each guardrail's `check` function returns one of three results:

| Result | Effect |
|---|---|
| `Pass()` | Continue unchanged |
| `Block(reason)` | Halt and return `reason` as the agent's response |
| `Modify(value)` | Replace the input or output with `value` and continue |

Guardrails run in the order they are declared. With `Modify`, each guardrail sees the output of the previous one.

## Basic Usage

```julia
no_pii = Guardrail(
    name  = "no_pii",
    on    = :input,
    check = input -> occursin(r"\d{3}-\d{2}-\d{4}", input) ?
                     Block("I'm not able to process inputs containing SSNs.") :
                     Pass(),
)

agent = Agent(
    name         = "SecureBot",
    instructions = "You are a helpful assistant.",
    guardrails   = [no_pii],
)

run!(agent, "My SSN is 123-45-6789")
# → "I'm not able to process inputs containing SSNs."
```

## Input Guardrails

Input guardrails run on the user's message **before the agent loop starts**. A `Block` short-circuits immediately — the LLM is never called, saving tokens.

```julia
# Rule-based
length_check = Guardrail(
    name  = "length_check",
    on    = :input,
    check = input -> length(input) > 500 ?
                     Block("Input too long (max 500 characters).") : Pass(),
)

# Sanitising with Modify
strip_html = Guardrail(
    name  = "strip_html",
    on    = :input,
    check = input -> Modify(replace(input, r"<[^>]+>" => "")),
)
```

## Output Guardrails

Output guardrails run on the agent's **final assembled response** before it is returned to the caller.

```julia
no_links = Guardrail(
    name  = "no_links",
    on    = :output,
    check = output -> occursin(r"https?://", output) ?
                      Block("Response blocked: contained external links.") : Pass(),
)

truncate = Guardrail(
    name  = "truncate",
    on    = :output,
    check = output -> length(output) > 300 ?
                      Modify(output[1:300] * "… [truncated]") : Pass(),
)
```

!!! note "Streaming and output guardrails"
    Output guardrails only apply to the final assembled response string. They do
    not fire mid-stream when `on_token` streaming is active — the full response
    is assembled first, then checked.

## Chaining Guardrails

Multiple guardrails run in declaration order. Each sees the value as potentially modified by the previous one:

```julia
agent = Agent(
    name         = "FilterBot",
    instructions = "You are a helpful assistant.",
    guardrails   = [
        strip_html,      # Modify: remove HTML tags
        length_check,    # Block: reject if still too long after stripping
        no_pii,          # Block: reject if PII detected
    ],
)
```

## Guardrail Options

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | `String` | required | Label shown in verbose output |
| `check` | `Function` | required | `(value::String) -> GuardrailResult` |
| `on` | `Symbol` | `:input` | When to run — `:input` or `:output` |

## Error Handling

If a guardrail's `check` function throws an exception, it is treated as a `Block` — the agent halts and returns the error message. This ensures guardrails **fail safe** rather than letting a buggy check silently pass bad content through.

## Runnable Examples

The examples directory has two complete scripts:

```bash
# Input guardrails: Block on SSN, Modify to strip HTML, chaining
julia --project examples/guardrails/input_guardrails.jl

# Output guardrails: Block on links, Modify to truncate, combined input+output
julia --project examples/guardrails/output_guardrails.jl
```
