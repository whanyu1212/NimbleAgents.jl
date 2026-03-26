###############################################################################
# mcp.jl — Model Context Protocol (MCP) client — stdio + HTTP transports
#
# Implements just enough of the MCP spec (2024-11-05) to:
#   1. Connect to an MCP server (subprocess for stdio, HTTP.post for http)
#   2. Perform the JSON-RPC initialize handshake
#   3. Discover tools via tools/list
#   4. Invoke tools via tools/call
#
# Stdio wire format: newline-delimited JSON-RPC 2.0 over process stdin/stdout.
# HTTP wire format:  JSON-RPC 2.0 POST requests to a URL endpoint.
#
# Usage (stdio):
#   server = MCPServer(command="uvx", args=["--from","mcpdoc","mcpdoc","--urls","LangGraph:https://langchain-ai.github.io/langgraph/llms.txt"])
#   client = connect!(MCPClient(server))
#   tools  = list_tools(client)
#   close!(client)
#
# Usage (HTTP):
#   server = MCPServer(url="https://docs.langchain.com/mcp")
#   server = MCPServer(url="https://huggingface.co/mcp",
#                      headers=Dict("Authorization" => "Bearer hf_xxx"))
#   client = connect!(MCPClient(server))
#   tools  = list_tools(client)
#   close!(client)
###############################################################################

using JSON3: JSON3

include("mcp/types.jl")

include("mcp/common_helpers.jl")
include("mcp/http_client.jl")
include("mcp/stdio_client.jl")

include("mcp/orchestration.jl")
