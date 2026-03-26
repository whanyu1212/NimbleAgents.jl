# examples/mcp/langchain_docs.jl
#
# Agent that queries the LangChain documentation via MCP (stdio transport).
# The mcpdoc server is fetched automatically by uvx — no manual install needed.
#
# Prerequisites:
#   uv (https://github.com/astral-sh/uv) must be on your PATH.
#   OPENAI_API_KEY or GOOGLE_API_KEY (GEMINI_API_KEY also works here)
#
# Run:
#   julia --project examples/mcp/langchain_docs.jl

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

# MCPServer (stdio) — spawns `uvx mcpdoc` as a subprocess.
# mcpdoc fetches the LangGraph llms.txt and exposes a search tool over MCP.
langchain_mcp = MCPServer(;
    command="uvx",
    args=[
        "--from",
        "mcpdoc",
        "mcpdoc",
        "--urls",
        "LangGraph:https://langchain-ai.github.io/langgraph/llms.txt",
        "--transport",
        "stdio",
    ],
)

agent = Agent(;
    name="LangChainDocsAgent",
    instructions="""
  You are a helpful assistant with access to the LangChain / LangGraph documentation.
  Use the available MCP tools to look up accurate information before answering.
  """,
    mcp_servers=[langchain_mcp],
    model=EXAMPLE_MODEL,
)

result = run!(
    agent, "What is LangGraph and how does it differ from LangChain?"; verbose=true
)
println(result)
