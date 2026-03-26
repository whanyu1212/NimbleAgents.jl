# examples/guardrails/output_guardrails.jl
#
# Demonstrates output guardrails — checks that run on the agent's final
# response before it is returned to the caller.
#
# Useful for catching things the LLM produced that it shouldn't have:
#   - External links in responses meant to be self-contained
#   - PII that leaked into the output
#   - Responses that are too long for the target interface
#
# Note: output guardrails only apply to the final assembled string response.
#       They do not fire mid-stream when on_token streaming is used.
#
# Run from the repo root:
#   julia --project examples/guardrails/output_guardrails.jl

using DotEnv
DotEnv.load!()

using NimbleAgents

function example_model(; tier::Symbol=:mini)
    if isempty(get(ENV, "GOOGLE_API_KEY", "")) && !isempty(get(ENV, "GEMINI_API_KEY", ""))
        ENV["GOOGLE_API_KEY"] = ENV["GEMINI_API_KEY"]
    end

    override = strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_MODEL", ""))
    !isempty(override) && return override

    openai_model, gemini_model = tier === :nano ?
        ("gpt-5.4-nano-2026-03-17", "gemini-2.5-flash-lite") :
        ("gpt-5.4-mini", "gemini-2.5-flash")

    provider = lowercase(strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_PROVIDER", "")))
    provider == "openai" && return openai_model
    provider == "gemini" && return gemini_model
    !isempty(provider) && error(
        "Unsupported NIMBLEAGENTS_EXAMPLE_PROVIDER=$(provider). Use 'openai' or 'gemini'.",
    )

    !isempty(get(ENV, "OPENAI_API_KEY", "")) && return openai_model
    !isempty(get(ENV, "GOOGLE_API_KEY", "")) && return gemini_model

    error(
        "Set OPENAI_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY, or set NIMBLEAGENTS_EXAMPLE_MODEL.",
    )
end

const EXAMPLE_MODEL = example_model()

# ── Pattern 1: Block responses containing external links ─────────────────────

no_links = Guardrail(;
    name="no_external_links",
    on=:output,
    check=output -> if occursin(r"https?://", output)
        Block("Response was blocked: contained external links.")
    else
        Pass()
    end,
)

agent = Agent(;
    name="NoLinkBot",
    instructions="You are a helpful assistant. Never include URLs in responses.",
    guardrails=[no_links],
    model=EXAMPLE_MODEL,
)

println("=== Pattern 1: Block output with links ===")
# Simulate what _apply_output_guardrails does on a response that slipped through
dummy_response = "Check out https://example.com for more info."
result = NimbleAgents._apply_output_guardrails(
    dummy_response,
    agent,
    NimbleAgents.TurnEvent("NoLinkBot", String(EXAMPLE_MODEL), "test"),
    time(),
    nothing,
    [],
    0,
    AgentHooks(),
    nothing,
    true,
)
println("Result: ", result)
# → "Response was blocked: contained external links."

# ── Pattern 2: Modify — truncate long responses ───────────────────────────────

truncate_output = Guardrail(;
    name="truncate",
    on=:output,
    check=output ->
        length(output) > 200 ? Modify(output[1:200] * "... [truncated]") : Pass(),
)

agent2 = Agent(;
    name="TruncateBot",
    instructions="You are a helpful assistant.",
    guardrails=[truncate_output],
    model=EXAMPLE_MODEL,
)

println("\n=== Pattern 2: Modify — truncate long output ===")
long_response = "A" ^ 300
result2 = NimbleAgents._apply_output_guardrails(
    long_response,
    agent2,
    NimbleAgents.TurnEvent("TruncateBot", String(EXAMPLE_MODEL), "test"),
    time(),
    nothing,
    [],
    0,
    AgentHooks(),
    nothing,
    true,
)
println("Length: ", length(result2), " (original was 300)")
println("Ends with: ", result2[(end - 14):end])

# ── Pattern 3: Input + output combined ───────────────────────────────────────

no_ssn_input = Guardrail(;
    name="no_ssn_input",
    on=:input,
    check=input ->
        occursin(r"\d{3}-\d{2}-\d{4}", input) ? Block("Cannot process SSNs.") : Pass(),
)

no_ssn_output = Guardrail(;
    name="no_ssn_output",
    on=:output,
    check=output -> if occursin(r"\d{3}-\d{2}-\d{4}", output)
        Block("Response blocked: contained SSN-like patterns.")
    else
        Pass()
    end,
)

agent3 = Agent(;
    name="FullGuardBot",
    instructions="You are a helpful assistant.",
    guardrails=[no_ssn_input, no_ssn_output],
    model=EXAMPLE_MODEL,
)

println("\n=== Pattern 3: Input + output guardrails ===")
# Input block fires before the LLM is called
result3 = run!(agent3, "My SSN is 123-45-6789"; verbose=false)
println("Input blocked: ", result3)
