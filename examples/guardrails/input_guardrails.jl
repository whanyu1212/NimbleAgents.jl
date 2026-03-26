# examples/guardrails/input_guardrails.jl
#
# Demonstrates input guardrails — checks that run on the user's message
# before the agent loop starts.
#
# Three patterns shown:
#   1. Block  — halt immediately and return a reason string
#   2. Modify — rewrite the input before the agent sees it
#   3. LLM-based — use a second LLM call to classify the input
#
# Run from the repo root:
#   julia --project examples/guardrails/input_guardrails.jl

using DotEnv
DotEnv.load!()

using NimbleAgents

function example_model(; tier::Symbol=:mini)
    if isempty(get(ENV, "GOOGLE_API_KEY", "")) && !isempty(get(ENV, "GEMINI_API_KEY", ""))
        ENV["GOOGLE_API_KEY"] = ENV["GEMINI_API_KEY"]
    end

    override = strip(get(ENV, "NIMBLEAGENTS_EXAMPLE_MODEL", ""))
    !isempty(override) && return override

    openai_model, gemini_model = if tier === :nano
        ("gpt-5.4-nano-2026-03-17", "gemini-2.5-flash-lite")
    else
        ("gpt-5.4-mini", "gemini-2.5-flash")
    end

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

# ── Pattern 1: Rule-based Block ───────────────────────────────────────────────
# Reject inputs that look like they contain a Social Security Number.

no_ssn = Guardrail(;
    name="no_ssn",
    on=:input,
    check=input -> if occursin(r"\d{3}-\d{2}-\d{4}", input)
        Block("I'm not able to process inputs containing SSNs.")
    else
        Pass()
    end,
)

agent = Agent(;
    name="SecureBot",
    instructions="You are a helpful assistant.",
    guardrails=[no_ssn],
    model=EXAMPLE_MODEL,
)

println("=== Pattern 1: Block on SSN ===")
result = run!(agent, "My SSN is 123-45-6789, can you help me?")
println("Response: ", result)
# → "I'm not able to process inputs containing SSNs."

println()
result2 = run!(agent, "What is the capital of France?")
println("Response: ", result2)
# → Normal agent response

# ── Pattern 2: Modify — sanitise input ───────────────────────────────────────
# Strip HTML tags from user input before passing to the agent.

strip_html = Guardrail(;
    name="strip_html", on=:input, check=input -> Modify(replace(input, r"<[^>]+>" => ""))
)

agent2 = Agent(;
    name="CleanBot",
    instructions="You are a helpful assistant. Repeat back what the user said.",
    guardrails=[strip_html],
    model=EXAMPLE_MODEL,
)

println("=== Pattern 2: Modify — strip HTML ===")
result3 = run!(agent2, "Hello <script>alert('xss')</script> world")
println("Response: ", result3)
# The agent sees "Hello  world" — the script tag is gone

# ── Pattern 3: Chaining multiple guardrails ───────────────────────────────────
# Guardrails run in order. Each sees the output of the previous Modify.

no_profanity = Guardrail(;
    name="no_profanity",
    on=:input,
    check=input -> if occursin(r"badword", lowercase(input))
        Block("Input contains inappropriate language.")
    else
        Pass()
    end,
)

length_check = Guardrail(;
    name="length_check",
    on=:input,
    check=input ->
        length(input) > 500 ? Block("Input is too long (max 500 characters).") : Pass(),
)

agent3 = Agent(;
    name="FilterBot",
    instructions="You are a helpful assistant.",
    guardrails=[no_profanity, length_check],
    model=EXAMPLE_MODEL,
)

println("=== Pattern 3: Chained guardrails ===")
result4 = run!(agent3, "This contains a badword in it")
println("Profanity blocked: ", result4)

result5 = run!(agent3, "x" ^ 501)
println("Length blocked: ", result5)
