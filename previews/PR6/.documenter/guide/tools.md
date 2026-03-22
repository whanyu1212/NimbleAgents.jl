


# Tools {#Tools}

Tools let your agent interact with the outside world. NimbleAgents provides three ways to define tools.

## The `@tool` Macro {#The-@tool-Macro}

The simplest way to create a tool:

```julia
@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end
```


This creates:
1. A Julia function `add(x, y)` you can call directly
  
2. A [`NimbleTool`](/reference#NimbleAgents.NimbleTool) object `add_tool` with auto-generated JSON schema
  

The first string literal in the function body becomes the tool&#39;s description for the LLM. Parameter types are automatically mapped to JSON schema types.

### Optional Parameters {#Optional-Parameters}

```julia
@tool function search(query::String, limit::Int=10)
    "Search for documents matching the query."
    # ... implementation
end
```

- `query` is required (no default)
  
- `limit` is optional with default `10`
  

### Return Direct {#Return-Direct}

When a tool has `return_direct=true`, its result becomes the agent&#39;s final output immediately — the LLM does not process it further:

```julia
@tool return_direct=true function lookup_cache(key::String)
    "Look up a cached value. Returns immediately if found."
    cache[key]
end
```


### Example: FAQ bot with return_direct {#Example:-FAQ-bot-with-return_direct}

```julia
# examples/tools/return_direct.jl
const FAQ = Dict(
    "refund"   => "Refunds are processed within 5–7 business days.",
    "shipping" => "Standard shipping takes 3–5 business days. Express is 1–2.",
    "password" => "Click 'Forgot password' on the login page to reset.",
)

@tool return_direct=true function lookup_faq(topic::String)
    "Look up a frequently asked question by topic keyword."
    get(FAQ, lowercase(topic), "No FAQ found for topic: $(topic)")
end

agent = Agent(
    name         = "SupportBot",
    instructions = "You are a customer support assistant. Use lookup_faq for support topics.",
    tools        = [lookup_faq_tool],
)

# The tool result is returned directly — no LLM call to rephrase it
run!(agent, "How long do refunds take?")
# → "Refunds are processed within 5–7 business days."
```


Run it with:

```bash
julia --project examples/tools/return_direct.jl
```


## Built-in Tools {#Built-in-Tools}

NimbleAgents includes a library of built-in tools:

|                 Tool |                                 Description |
| --------------------:| -------------------------------------------:|
|     `read_file_tool` |                          Read file contents |
|    `write_file_tool` |                     Write content to a file |
|     `edit_file_tool` |                  Replace a string in a file |
|      `list_dir_tool` |                     List directory contents |
|          `glob_tool` |                  Find files by glob pattern |
|   `delete_file_tool` |                               Delete a file |
|          `grep_tool` |             Search file contents with regex |
|    `find_files_tool` |                  Find files by name pattern |
|          `bash_tool` |                      Execute shell commands |
|      `http_get_tool` |                            HTTP GET request |
|     `http_post_tool` |                           HTTP POST request |
|    `eval_julia_tool` | Evaluate Julia code in a persistent sandbox |
| `save_artifact_tool` |       Register a file as a session artifact |


```julia
agent = Agent(
    name = "Coder",
    instructions = "You help with coding tasks.",
    tools = [read_file_tool, write_file_tool, bash_tool, eval_julia_tool],
)
```


## CLITool {#CLITool}

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

### Example: Developer tools agent {#Example:-Developer-tools-agent}

```julia
# examples/tools/cli_tools_demo.jl
grep_tool = CLITool(
    name        = "grep",
    description = "Search for a pattern in files or directories.",
    command     = ["grep", "-rn", "{pattern}", "{path}"],
    args        = [
        "pattern" => CLIArg(String, "Regex pattern to search for."),
        "path"    => CLIArg(String, "File or directory path to search in."),
    ],
)

git_log_tool = CLITool(
    name        = "git_log",
    description = "Show recent git commits as a compact one-line log.",
    command     = ["git", "log", "--oneline", "-{n}"],
    args        = ["n" => CLIArg(Int, "Number of recent commits to show.")],
)

agent = Agent(
    name         = "DevBot",
    instructions = "You are a developer assistant with access to shell tools.",
    tools        = [grep_tool, git_log_tool],
)

run!(agent, "Search for all uses of 'CLITool' in the src/ directory.")
run!(agent, "Show me the last 5 git commits.")
```


Run it with:

```bash
julia --project examples/tools/cli_tools_demo.jl
```


### CLITool Options {#CLITool-Options}

|             Field |                          Type |   Default |                       Description |
| -----------------:| -----------------------------:| ---------:| ---------------------------------:|
|            `name` |                      `String` |  required |                         Tool name |
|     `description` |                      `String` |  required |           Description for the LLM |
|         `command` |              `Vector{String}` |  required | Command with `{arg}` placeholders |
|            `args` | `Vector{Pair{String,CLIArg}}` |  required |              Argument definitions |
|         `timeout` |                     `Float64` |    `30.0` |     Subprocess timeout in seconds |
|     `working_dir` |         `String` or `nothing` | `nothing` |                 Working directory |
|   `return_direct` |                        `Bool` |   `false` |          Short-circuit agent loop |
| `return_artifact` |                        `Bool` |   `false` |       Register output as artifact |


### CLIArg {#CLIArg}

```julia
CLIArg(type, description; required=true)
```

- `type`: `String`, `Int`, `Float64`, or `Bool`
  
- `description`: Description shown to the LLM
  
- `required`: Whether the argument is mandatory (default: `true`)
  

## Tool Dispatch {#Tool-Dispatch}

Under the hood, `dispatch_tool` routes LLM tool calls to the correct callable:

```julia
tool_map = build_tool_map([add_tool, greet_tool])
result = dispatch_tool(tool_map, "add", Dict{Symbol,Any}(:x => 10, :y => 32))
# result == 42
```


## A Note on Provider-Native Tools {#A-Note-on-Provider-Native-Tools}

Some LLM providers offer built-in server-side tools — for example, Google Search in Gemini, web search in Claude, or code interpreter in OpenAI. These are not standard function-calling tools; they require provider-specific API parameters and return results in different formats.

NimbleAgents (via [PromptingTools.jl](https://github.com/svilupp/PromptingTools.jl)) currently supports standard function-calling tools across all providers. Provider-native tools are not yet supported — this is an area of active development in the Julia LLM ecosystem and something we&#39;d like to add in the future.

In the meantime, NimbleAgents includes built-in tools that cover similar ground:

|    Provider-native tool |                         NimbleAgents equivalent |
| -----------------------:| -----------------------------------------------:|
|    Gemini Google Search | `search_web` (via Tavily API) + `fetch_webpage` |
|       Claude web search |                  `search_web` + `fetch_webpage` |
| OpenAI code interpreter |    `eval_julia_tool` (persistent Julia sandbox) |


These work across all providers since they use standard function calling.
