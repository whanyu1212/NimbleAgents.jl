# examples/mcp/langchain_docs.jl
#
# Agent that queries the LangChain documentation via MCP (stdio transport).
# The mcpdoc server is fetched automatically by uvx — no manual install needed.
#
# Prerequisites:
#   uv (https://github.com/astral-sh/uv) must be on your PATH.
#
# Run:
#   julia --project examples/mcp/langchain_docs.jl

using DotEnv
DotEnv.load!()

using NimbleAgents

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
    model="gpt-5.4-mini",
)

result = run!(
    agent, "What is LangGraph and how does it differ from LangChain?"; verbose=true
)
println(result)
