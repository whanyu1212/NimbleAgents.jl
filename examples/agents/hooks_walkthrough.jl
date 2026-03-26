# examples/hooks_walkthrough.jl
#
# A multi-turn conversation that inspects every callback in detail.
# Run from the project root:
#
#   julia --project=. examples/hooks_walkthrough.jl

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

# ── Tools ─────────────────────────────────────────────────────────────────────

@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end

@tool function multiply(x::Int, y::Int)
    "Multiply two integers together."
    x * y
end

@tool function factorial(n::Int)
    "Compute the factorial of a non-negative integer."
    n < 0 && error("factorial is not defined for negative numbers")
    n == 0 ? 1 : prod(1:n)
end

# ── Helpers ───────────────────────────────────────────────────────────────────

divider(char='─', n=60) = println(char ^ n)

function pretty_args(args)
    isnothing(args) && return "()"
    join(["$(k)=$(repr(v))" for (k, v) in args], ", ")
end

# ── Hooks ─────────────────────────────────────────────────────────────────────

hooks = AgentHooks(;
    before_llm_call=(agent, iteration, msgs) -> begin
        divider()
        println("  [before_llm_call] #$(iteration)")
        println("     agent    : $(agent.name)")
        println("     model    : $(agent.model)")
        println("     tools    : $(join([t.name for t in agent.tools], ", "))")
        println("     messages : $(length(msgs))")
        divider()
        msgs
    end,
    after_llm_call=(agent, iteration, response) -> begin
        println("  [after_llm_call] #$(iteration)")
        println("     type          : $(nameof(typeof(response)))")
        println("     finish_reason : $(get(response.extras, :finish_reason, "—"))")
        usage = response.usage
        if !isnothing(usage)
            println("     tokens in/out : $(usage.input_tokens) / $(usage.output_tokens)")
        end
        if response isa NimbleAgents.AIToolRequest && !isempty(response.tool_calls)
            println(
                "     tool_calls    : $(join([tc.name for tc in response.tool_calls], ", "))",
            )
        end
        println()
    end,
    on_tool_call=(agent, name, args) -> begin
        println("  [on_tool_call]")
        println("     tool : $(name)")
        println("     args : $(pretty_args(args))")
    end,
    on_tool_result=(agent, name, result) -> begin
        println("  [on_tool_result]")
        println("     tool   : $(name)")
        println("     result : $(repr(result))")
        println()
    end,
    on_complete=(agent, result) -> begin
        divider('═')
        println("  [on_complete]")
        println("     agent  : $(agent.name)")
        println("     result : $(result)")
        divider('═')
    end,
)

# ── Agent ─────────────────────────────────────────────────────────────────────

agent = Agent(;
    name="MathBot",
    instructions="""You are a precise math assistant. Always use the available
tools to compute answers — never calculate in your head.""",
    tools=[add_tool, multiply_tool, factorial_tool],
    model=EXAMPLE_MODEL,
    hooks=hooks,
)

# ── Multi-turn conversation ───────────────────────────────────────────────────

turns = [
    "What is 8 + 14?",
    "Now multiply that result by 3.",
    "What is the factorial of 5? Then add it to the previous result.",
]

session = Session()

println()
println("=" ^ 60)
println("  NimbleAgents — Hooks Walkthrough")
println("  Agent : $(agent.name)  |  Model : $(agent.model)")
println("=" ^ 60)

for (i, prompt) in enumerate(turns)
    println()
    println("┌─ Turn $(i) ", "─" ^ (54 - ndigits(i)))
    println("│  User: $(prompt)")
    println("│  Session messages so far: $(length(session))")
    println("└", "─" ^ 59)
    println()

    response = run!(agent, prompt; session=session, verbose=false)

    println()
    println("  Agent: $(response)")
    println()
end
