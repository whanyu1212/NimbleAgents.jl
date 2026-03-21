


# MCP (Model Context Protocol) {#MCP-Model-Context-Protocol}

NimbleAgents has native support for MCP, allowing your agents to use tools from MCP-compatible servers over **stdio** or **HTTP**.

::: warning Experimental — hand-rolled implementation, limited server coverage

There is no official Julia SDK for MCP. The [modelcontextprotocol org](https://github.com/orgs/modelcontextprotocol/repositories) publishes SDKs for Python, TypeScript, Kotlin, Swift, C#, and Rust — but not Julia. The client in NimbleAgents is implemented from scratch directly against the spec, using `HTTP.jl` and `JSON3.jl`. It covers enough of the protocol to be useful, but it is not a full SDK and may have gaps or rough edges that a dedicated library would handle more robustly.

Two transports are implemented: stdio and HTTP (Streamable HTTP / SSE, MCP spec 2025-03-26).

**stdio** has been tested against a handful of local servers (mcpdoc, @modelcontextprotocol/server-filesystem).

**HTTP transport is newer and has only been tested against two servers**: the public LangChain docs endpoint (`https://docs.langchain.com/mcp`) and the HuggingFace Hub MCP endpoint (`https://huggingface.co/mcp`). Compatibility with other HTTP MCP servers is not yet confirmed — behaviour may vary depending on how strictly a server follows the spec, particularly around SSE framing and the initialize handshake. If you run into issues, please open an issue with the server URL and any error details.

:::

## What is MCP? {#What-is-MCP?}

MCP is a protocol for connecting AI models to external tools and data sources via JSON-RPC 2.0. NimbleAgents implements the client side — it spawns the server as a subprocess, performs the initialize handshake, discovers tools, and routes tool calls.

## Connecting to MCP Servers {#Connecting-to-MCP-Servers}

Two transports are supported: **stdio** (local subprocess) and **HTTP** (remote endpoint).

### stdio {#stdio}

```julia
server = MCPServer(
    command = "npx",
    args    = ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/files"],
)

agent = Agent(
    name         = "FileBot",
    instructions = "You help with file operations.",
    mcp_servers  = [server],
)

# run! automatically connects, discovers tools, and closes on completion
result = run!(agent, "List the files in /path/to/files")
```


### HTTP {#HTTP}

```julia
# Public endpoint — no auth required
server = MCPServer(url="https://docs.langchain.com/mcp")

# With authentication
server = MCPServer(
    url     = "https://huggingface.co/mcp",
    headers = Dict("Authorization" => "Bearer hf_xxx"),
)

agent = Agent(
    name         = "ResearchBot",
    instructions = "You help search HuggingFace for models and papers.",
    mcp_servers  = [server],
)

result = run!(agent, "Find me transformer models for text classification")
```


When `run!` starts, it connects to each MCP server, calls `tools/list` to discover available tools, and adds them to the agent&#39;s tool set. On completion (or error), all connections are closed.

## MCPServer Options {#MCPServer-Options}

### stdio fields {#stdio-fields}

|     Field |                  Type |  Default |                     Description |
| ---------:| ---------------------:| --------:| -------------------------------:|
| `command` |              `String` | required |               Executable to run |
|    `args` |      `Vector{String}` |     `[]` | Arguments passed to the command |
|     `env` | `Dict{String,String}` | `Dict()` |     Extra environment variables |


### HTTP fields {#HTTP-fields}

|     Field |                  Type |  Default |                        Description |
| ---------:| ---------------------:| --------:| ----------------------------------:|
|     `url` |              `String` | required |                  HTTP endpoint URL |
| `headers` | `Dict{String,String}` | `Dict()` | Request headers (e.g. auth tokens) |


### Shared fields {#Shared-fields}

|         Field |      Type | Default |                            Description |
| -------------:| ---------:| -------:| --------------------------------------:|
|     `timeout` | `Float64` |  `60.0` | Seconds to wait for JSON-RPC responses |
| `cache_tools` |    `Bool` |  `true` |  Cache tool list after first discovery |


## Direct Client Usage {#Direct-Client-Usage}

For advanced use cases, you can manage the MCP client directly. Use `MCPClient` for stdio servers and `MCPHTTPClient` for HTTP servers:

```julia
# stdio
server = MCPServer(command="uvx", args=["--from", "mcpdoc", "mcpdoc"])
client = MCPClient(server)
connect!(client)
tools = list_tools(client)   # Vector{NimbleTool}
result = tools[1].callable(Dict{Symbol,Any}(:query => "search term"))
close!(client)

# HTTP
server = MCPServer(url="https://docs.langchain.com/mcp")
client = MCPHTTPClient(server)
connect!(client)
tools = list_tools(client)
result = tools[1].callable(Dict{Symbol,Any}(:query => "LangGraph agents"))
close!(client)
```


## Popular MCP Servers {#Popular-MCP-Servers}

**stdio (local)**
- **@modelcontextprotocol/server-filesystem** — file system access
  
- **@modelcontextprotocol/server-postgres** — PostgreSQL queries
  
- **@modelcontextprotocol/server-github** — GitHub API
  
- **mcpdoc** — documentation search via llms.txt
  

**HTTP (remote)**
- **https://docs.langchain.com/mcp** — LangChain documentation search (no auth)
  
- **https://huggingface.co/mcp** — HuggingFace Hub (models, datasets, papers, jobs; requires HF token)
  

## Example: LangChain Docs Agent (stdio) {#Example:-LangChain-Docs-Agent-stdio}

A complete working example using `uvx mcpdoc` to serve the LangGraph documentation over stdio MCP. Requires [`uv`](https://github.com/astral-sh/uv) on your PATH.

```julia
# examples/mcp/langchain_docs.jl
using DotEnv; DotEnv.load!()
using NimbleAgents

langchain_mcp = MCPServer(
    command = "uvx",
    args    = [
        "--from", "mcpdoc", "mcpdoc",
        "--urls", "LangGraph:https://langchain-ai.github.io/langgraph/llms.txt",
        "--transport", "stdio",
    ],
)

agent = Agent(
    name         = "LangChainDocsAgent",
    instructions = """
    You are a helpful assistant with access to the LangChain / LangGraph documentation.
    Use the available MCP tools to look up accurate information before answering.
    """,
    mcp_servers  = [langchain_mcp],
    model        = "gpt-5.4-mini",
)

result = run!(agent, "What is LangGraph and how does it differ from LangChain?"; verbose = true)
println(result)
```


Run it with:

```bash
julia --project examples/mcp/langchain_docs.jl
```

