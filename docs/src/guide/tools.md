```@meta
CurrentModule = NimbleAgents
```

# Tools

Tools let your agent interact with the outside world. NimbleAgents provides three ways to define tools.

## The `@tool` Macro

The simplest way to create a tool:

```julia
@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end
```

This creates:
1. A Julia function `add(x, y)` you can call directly
2. A [`NimbleTool`](@ref) object `add_tool` with auto-generated JSON schema

The first string literal in the function body becomes the tool's description for the LLM. Parameter types are automatically mapped to JSON schema types.

### Optional Parameters

```julia
@tool function search(query::String, limit::Int=10)
    "Search for documents matching the query."
    # ... implementation
end
```

- `query` is required (no default)
- `limit` is optional with default `10`

### Return Direct

When a tool has `return_direct=true`, its result becomes the agent's final output immediately — the LLM does not process it further:

```julia
@tool return_direct=true function lookup_cache(key::String)
    "Look up a cached value. Returns immediately if found."
    cache[key]
end
```

## Built-in Tools

NimbleAgents includes a library of built-in tools:

| Tool | Description |
|------|-------------|
| `read_file_tool` | Read file contents |
| `write_file_tool` | Write content to a file |
| `edit_file_tool` | Replace a string in a file |
| `list_dir_tool` | List directory contents |
| `glob_tool` | Find files by glob pattern |
| `delete_file_tool` | Delete a file |
| `grep_tool` | Search file contents with regex |
| `find_files_tool` | Find files by name pattern |
| `bash_tool` | Execute shell commands |
| `http_get_tool` | HTTP GET request |
| `http_post_tool` | HTTP POST request |
| `eval_julia_tool` | Evaluate Julia code in a persistent sandbox |
| `save_artifact_tool` | Register a file as a session artifact |

```julia
agent = Agent(
    name = "Coder",
    instructions = "You help with coding tasks.",
    tools = [read_file_tool, write_file_tool, bash_tool, eval_julia_tool],
)
```

## CLITool

Wrap shell commands as tools with typed arguments and placeholder substitution:

```julia
grep_cli = CLITool(
    name        = "grep_cli",
    description = "Search for a pattern in files.",
    command     = ["grep", "-rn", "{pattern}", "{path}"],
    args        = [
        "pattern" => CLIArg(String, "Regex pattern to search for"),
        "path"    => CLIArg(String, "Directory to search in"),
    ],
    timeout     = 10.0,
)
```

The `{placeholder}` tokens in `command` are replaced with the LLM-provided argument values at runtime. The command is executed as a subprocess.

### CLITool Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `String` | required | Tool name |
| `description` | `String` | required | Description for the LLM |
| `command` | `Vector{String}` | required | Command with `{arg}` placeholders |
| `args` | `Vector{Pair{String,CLIArg}}` | required | Argument definitions |
| `timeout` | `Float64` | `30.0` | Subprocess timeout in seconds |
| `working_dir` | `String` or `nothing` | `nothing` | Working directory |
| `return_direct` | `Bool` | `false` | Short-circuit agent loop |
| `return_artifact` | `Bool` | `false` | Register output as artifact |

### CLIArg

```julia
CLIArg(type, description; required=true)
```

- `type`: `String`, `Int`, `Float64`, or `Bool`
- `description`: Description shown to the LLM
- `required`: Whether the argument is mandatory (default: `true`)

## Tool Dispatch

Under the hood, `dispatch_tool` routes LLM tool calls to the correct callable:

```julia
tool_map = build_tool_map([add_tool, greet_tool])
result = dispatch_tool(tool_map, "add", Dict{Symbol,Any}(:x => 10, :y => 32))
# result == 42
```
