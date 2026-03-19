```@meta
CurrentModule = NimbleAgents
```

# MCP (Model Context Protocol)

NimbleAgents has native support for MCP, allowing your agents to use tools from any MCP-compatible server over stdio.

## What is MCP?

MCP is a protocol for connecting AI models to external tools and data sources via JSON-RPC 2.0. NimbleAgents implements the client side — it spawns the server as a subprocess, performs the initialize handshake, discovers tools, and routes tool calls.

## Connecting to MCP Servers

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

When `run!` starts, it spawns each MCP server, calls `tools/list` to discover available tools, and adds them to the agent's tool set. On completion (or error), all MCP connections are closed.

## MCPServer Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `command` | `String` | required | Executable to run |
| `args` | `Vector{String}` | `[]` | Arguments passed to the command |
| `env` | `Dict{String,String}` | `Dict()` | Extra environment variables |
| `timeout` | `Float64` | `60.0` | Seconds to wait for JSON-RPC responses |
| `cache_tools` | `Bool` | `true` | Cache tool list after first discovery |

## Direct Client Usage

For advanced use cases, you can manage the MCP client directly:

```julia
server = MCPServer(command="uvx", args=["--from", "mcpdoc", "mcpdoc"])
client = MCPClient(server)

# Connect and discover tools
connect!(client)
tools = list_tools(client)   # Vector{NimbleTool}

# Use a tool
result = tools[1].callable(Dict{Symbol,Any}(:query => "search term"))

# Clean up
close!(client)
```

## Popular MCP Servers

- **@modelcontextprotocol/server-filesystem** — file system access
- **@modelcontextprotocol/server-postgres** — PostgreSQL queries
- **@modelcontextprotocol/server-github** — GitHub API
- **mcpdoc** — documentation search via llms.txt
