---
outline: deep
---


# Reference {#Reference}
- [`NimbleAgents.eval_julia_tool`](#NimbleAgents.eval_julia_tool)
- [`NimbleAgents.AbstractMemoryService`](#NimbleAgents.AbstractMemoryService)
- [`NimbleAgents.AbstractSessionStore`](#NimbleAgents.AbstractSessionStore)
- [`NimbleAgents.Agent`](#NimbleAgents.Agent)
- [`NimbleAgents.AgentHooks`](#NimbleAgents.AgentHooks)
- [`NimbleAgents.ApprovalTimeout`](#NimbleAgents.ApprovalTimeout)
- [`NimbleAgents.Artifact`](#NimbleAgents.Artifact)
- [`NimbleAgents.Block`](#NimbleAgents.Block)
- [`NimbleAgents.CLIArg`](#NimbleAgents.CLIArg)
- [`NimbleAgents.CLITool`](#NimbleAgents.CLITool)
- [`NimbleAgents.ContextConfig`](#NimbleAgents.ContextConfig)
- [`NimbleAgents.EvalCase`](#NimbleAgents.EvalCase)
- [`NimbleAgents.EvalReport`](#NimbleAgents.EvalReport)
- [`NimbleAgents.EvalResult`](#NimbleAgents.EvalResult)
- [`NimbleAgents.ExternalAgentTool`](#NimbleAgents.ExternalAgentTool)
- [`NimbleAgents.GeminiOpenAISchema`](#NimbleAgents.GeminiOpenAISchema)
- [`NimbleAgents.Guardrail`](#NimbleAgents.Guardrail)
- [`NimbleAgents.Handoff`](#NimbleAgents.Handoff)
- [`NimbleAgents.HandoffFilter`](#NimbleAgents.HandoffFilter)
- [`NimbleAgents.HumanInterrupt`](#NimbleAgents.HumanInterrupt)
- [`NimbleAgents.InMemoryMemoryService`](#NimbleAgents.InMemoryMemoryService)
- [`NimbleAgents.InMemorySessionStore`](#NimbleAgents.InMemorySessionStore)
- [`NimbleAgents.JSONSessionStore`](#NimbleAgents.JSONSessionStore)
- [`NimbleAgents.MCPClient`](#NimbleAgents.MCPClient)
- [`NimbleAgents.MCPHTTPClient`](#NimbleAgents.MCPHTTPClient)
- [`NimbleAgents.MCPServer`](#NimbleAgents.MCPServer)
- [`NimbleAgents.MemoryEntry`](#NimbleAgents.MemoryEntry)
- [`NimbleAgents.Modify`](#NimbleAgents.Modify)
- [`NimbleAgents.NamedMetric`](#NimbleAgents.NamedMetric)
- [`NimbleAgents.NimbleTool`](#NimbleAgents.NimbleTool)
- [`NimbleAgents.Pass`](#NimbleAgents.Pass)
- [`NimbleAgents.RateLimiter`](#NimbleAgents.RateLimiter)
- [`NimbleAgents.RetryConfig`](#NimbleAgents.RetryConfig)
- [`NimbleAgents.SQLiteMemoryService`](#NimbleAgents.SQLiteMemoryService)
- [`NimbleAgents.SQLiteSessionStore`](#NimbleAgents.SQLiteSessionStore)
- [`NimbleAgents.Session`](#NimbleAgents.Session)
- [`NimbleAgents.Skill`](#NimbleAgents.Skill)
- [`NimbleAgents.ToolEvent`](#NimbleAgents.ToolEvent)
- [`NimbleAgents.Trace`](#NimbleAgents.Trace)
- [`NimbleAgents.TurnEvent`](#NimbleAgents.TurnEvent)
- [`Base.delete!`](#Base.delete!-Tuple{JSONSessionStore,%20String})
- [`NimbleAgents._acquire_rate_limit!`](#NimbleAgents._acquire_rate_limit!-Tuple{String})
- [`NimbleAgents._edit_distance`](#NimbleAgents._edit_distance-Tuple{AbstractString,%20AbstractString})
- [`NimbleAgents._keyword_score`](#NimbleAgents._keyword_score-Tuple{String,%20String})
- [`NimbleAgents._memory_prompt`](#NimbleAgents._memory_prompt-Tuple{Union{Nothing,%20AbstractMemoryService},%20String,%20Union{Nothing,%20Session}})
- [`NimbleAgents._metric_name`](#NimbleAgents._metric_name-Tuple{Function})
- [`NimbleAgents._resolve_instructions`](#NimbleAgents._resolve_instructions-Tuple{String,%20Any,%20Any})
- [`NimbleAgents.acquire!`](#NimbleAgents.acquire!-Tuple{RateLimiter})
- [`NimbleAgents.agent_as_tool`](#NimbleAgents.agent_as_tool-Tuple{Agent})
- [`NimbleAgents.build_tool_map`](#NimbleAgents.build_tool_map-Tuple{Vector{<:AbstractTool}})
- [`NimbleAgents.chat!`](#NimbleAgents.chat!-Tuple{Agent})
- [`NimbleAgents.claude_code_tool`](#NimbleAgents.claude_code_tool-Tuple{})
- [`NimbleAgents.close!`](#NimbleAgents.close!-Tuple{MCPClient})
- [`NimbleAgents.close!`](#NimbleAgents.close!-Tuple{MCPHTTPClient})
- [`NimbleAgents.close!`](#NimbleAgents.close!-Tuple{SQLiteSessionStore})
- [`NimbleAgents.codex_tool`](#NimbleAgents.codex_tool-Tuple{})
- [`NimbleAgents.compact!`](#NimbleAgents.compact!-Tuple{Session,%20Any})
- [`NimbleAgents.connect!`](#NimbleAgents.connect!-Tuple{MCPClient})
- [`NimbleAgents.connect!`](#NimbleAgents.connect!-Tuple{MCPHTTPClient})
- [`NimbleAgents.cost_budget`](#NimbleAgents.cost_budget-Tuple{Real})
- [`NimbleAgents.discover_skills`](#NimbleAgents.discover_skills-Tuple{Vector{String}})
- [`NimbleAgents.dispatch_tool`](#NimbleAgents.dispatch_tool-Tuple{Dict{String,%20<:AbstractTool},%20ToolMessage})
- [`NimbleAgents.dispatch_tool`](#NimbleAgents.dispatch_tool-Tuple{Dict{String,%20<:AbstractTool},%20String,%20Dict{Symbol}})
- [`NimbleAgents.exact_match`](#NimbleAgents.exact_match-Tuple{EvalCase,%20Any,%20Any})
- [`NimbleAgents.fan_out`](#NimbleAgents.fan_out-Tuple{Agent,%20Vector{String}})
- [`NimbleAgents.fuzzy_match`](#NimbleAgents.fuzzy_match-Tuple{EvalCase,%20Any,%20Any})
- [`NimbleAgents.get_model_pricing`](#NimbleAgents.get_model_pricing-Tuple{String})
- [`NimbleAgents.handoff_tool`](#NimbleAgents.handoff_tool-Tuple{Agent})
- [`NimbleAgents.latency_budget`](#NimbleAgents.latency_budget-Tuple{Real})
- [`NimbleAgents.list`](#NimbleAgents.list-Tuple{JSONSessionStore})
- [`NimbleAgents.list_tools`](#NimbleAgents.list_tools-Tuple{MCPClient})
- [`NimbleAgents.load`](#NimbleAgents.load-Tuple{JSONSessionStore,%20String})
- [`NimbleAgents.load_eval`](#NimbleAgents.load_eval-Tuple{String})
- [`NimbleAgents.load_trace`](#NimbleAgents.load_trace-Tuple{String})
- [`NimbleAgents.loop_pipeline!`](#NimbleAgents.loop_pipeline!-Tuple{Vector{Agent},%20String})
- [`NimbleAgents.print_eval`](#NimbleAgents.print_eval-Tuple{EvalReport})
- [`NimbleAgents.print_trace`](#NimbleAgents.print_trace-Tuple{Trace})
- [`NimbleAgents.register_artifact!`](#NimbleAgents.register_artifact!-Tuple{Session,%20String})
- [`NimbleAgents.remove_model_pricing!`](#NimbleAgents.remove_model_pricing!-Tuple{String})
- [`NimbleAgents.remove_rate_limit!`](#NimbleAgents.remove_rate_limit!-Tuple{String})
- [`NimbleAgents.reset!`](#NimbleAgents.reset!-Tuple{Session})
- [`NimbleAgents.resume!`](#NimbleAgents.resume!-Tuple{Session,%20String})
- [`NimbleAgents.run!`](#NimbleAgents.run!-Tuple{Agent,%20String})
- [`NimbleAgents.run_eval`](#NimbleAgents.run_eval-Tuple{Agent,%20Vector{EvalCase}})
- [`NimbleAgents.run_pipeline!`](#NimbleAgents.run_pipeline!-Tuple{Agent,%20String})
- [`NimbleAgents.save!`](#NimbleAgents.save!-Tuple{JSONSessionStore,%20Session})
- [`NimbleAgents.save_eval`](#NimbleAgents.save_eval-Tuple{EvalReport,%20String})
- [`NimbleAgents.save_trace`](#NimbleAgents.save_trace-Tuple{Trace,%20String})
- [`NimbleAgents.serve`](#NimbleAgents.serve-Tuple{Vector{<:Agent}})
- [`NimbleAgents.set_model_pricing!`](#NimbleAgents.set_model_pricing!-Tuple{String,%20Real,%20Real})
- [`NimbleAgents.set_rate_limit!`](#NimbleAgents.set_rate_limit!-Tuple{String,%20Real})
- [`NimbleAgents.spawn_subagents`](#NimbleAgents.spawn_subagents-Tuple{Vector{<:Tuple{Agent,%20String}}})
- [`NimbleAgents.tool_coverage`](#NimbleAgents.tool_coverage-Tuple{EvalCase,%20Any,%20Any})
- [`NimbleAgents.tool_trajectory`](#NimbleAgents.tool_trajectory-Tuple{EvalCase,%20Any,%20Any})
- [`NimbleAgents.tools_schema`](#NimbleAgents.tools_schema-Tuple{Vector{<:AbstractTool}})
- [`NimbleAgents.@tool`](#NimbleAgents.@tool-Tuple)

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.eval_julia_tool' href='#NimbleAgents.eval_julia_tool'><span class="jlbinding">NimbleAgents.eval_julia_tool</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



```julia
eval_julia_tool
```


Built-in tool that evaluates Julia code in a persistent sandbox.

The sandbox persists for the lifetime of the session — variables, imports, and function definitions all carry over between calls. The project environment is active, so any package in `Project.toml` can be loaded with `using`.

Pair with a `Session` to get persistent state across turns:

```julia
session = Session(app_name="DataSession", user_id="alice")
agent   = Agent(
    name  = "DataBot",
    tools = [eval_julia_tool],
)
run!(agent, "Load DataFrames and create a DataFrame with columns a and b"; session=session)
run!(agent, "Now compute the mean of column a"; session=session)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/builtins/repl.jl#L167-L187" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.AbstractMemoryService' href='#NimbleAgents.AbstractMemoryService'><span class="jlbinding">NimbleAgents.AbstractMemoryService</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
AbstractMemoryService
```


Abstract type for memory backends. Implementations must define:
- `add_memory!(service, content; user_id, app_name, metadata, session_id) -> MemoryEntry`
  
- `search_memory(service, query; user_id, app_name, top_k) -> Vector{MemoryEntry}`
  
- `delete_memory!(service, id)`
  
- `list_memories(service; user_id, app_name) -> Vector{MemoryEntry}`
  
- `close!(service)`
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/memory.jl#L55-L64" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.AbstractSessionStore' href='#NimbleAgents.AbstractSessionStore'><span class="jlbinding">NimbleAgents.AbstractSessionStore</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
AbstractSessionStore
```


Interface for session persistence backends. Implement:
- `save!(store, session)`
  
- `load(store, session_id) -> Union{Session, Nothing}`
  
- `delete!(store, session_id)`
  
- `list(store; app_name, user_id) -> Vector{String}`
  
- `store_artifacts_dir(store) -> String`
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L87-L96" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Agent' href='#NimbleAgents.Agent'><span class="jlbinding">NimbleAgents.Agent</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Agent(; name, instructions, tools, model, max_iterations, output_type, hooks)
```


A configured AI agent with a system prompt, a set of tools, and a model.

**Fields**
- `name::String`: Human-readable name for the agent.
  
- `instructions::Union{String, Function}`: The system prompt — what the agent does and how it behaves. Can be a static `String` or a callable `(session, agent) -> String` for dynamic prompts (e.g. per-user context, RAG injection, time-aware instructions).
  
- `tools::Vector{Tool}`: Tools the agent can call.
  
- `model::String`: Model identifier (default: `"gpt-5.4-mini"`).
  
- `max_iterations::Int`: Maximum number of LLM calls before the loop stops (default: `10`).
  
- `output_type::Union{Type, Nothing}`: When set, the final response is parsed into this Julia struct instead of returned as a plain `String`.
  
- `api_kwargs::NamedTuple`: Extra keyword arguments passed through to every PromptingTools LLM call (`aitools`, `aigenerate`, `aiextract`). Use this for model-specific features like OpenAI reasoning config or Anthropic thinking config (default: `NamedTuple()`).
  
- `hooks::AgentHooks`: Optional lifecycle callbacks (default: all no-ops).
  
- `sub_agents::Vector{Agent}`: Child agents the LLM can hand off to. A `handoff_tool` is generated automatically for each one — no manual wiring needed.
  
- `retry::RetryConfig`: Exponential-backoff retry policy for LLM API calls (default: 3 retries, 0.5s–60s window). Set `retry=RetryConfig(max_retries=0)` to disable.
  
- `context::ContextConfig`: Context-window management policy. When `session.history` exceeds `context.compact_threshold × context.context_window` tokens, older messages are summarised and replaced, keeping the most recent `context.keep_last` messages verbatim.
  
- `skills::Vector{Skill}`: Explicitly attached skills. Metadata is injected into the system prompt; full instructions are loaded on demand via the built-in `read_skill` tool.
  
- `skill_dirs::Vector{String}`: Directories to scan for skill subdirectories at run time. Discovered skills are merged with any explicitly listed in `skills`.
  

**Example — plain text output**

```julia
@tool function add(x::Int, y::Int)
    "Add two integers."
    x + y
end

agent = Agent(
    name         = "MathBot",
    instructions = "You are a helpful assistant that can do arithmetic.",
    tools        = [add_tool],
)

result = run!(agent, "What is 3 + 4?")  # String
```


**Example — with session memory**

```julia
session = Session(app_name="MyApp", user_id="alice")
run!(agent, "What is 8 + 14?"; session=session)
run!(agent, "Now multiply that by 3"; session=session)  # remembers 22
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L311-L365" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.AgentHooks' href='#NimbleAgents.AgentHooks'><span class="jlbinding">NimbleAgents.AgentHooks</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
AgentHooks(; before_llm_call, after_llm_call, should_interrupt, on_tool_call, on_tool_result, on_complete)
```


Optional lifecycle callbacks for an `Agent`. All fields default to `nothing` (no-op). Provide a function to observe or log that event.

**Callbacks**

|              Field |                                  Signature |                                                                         Fired |
| ------------------:| ------------------------------------------:| -----------------------------------------------------------------------------:|
|  `before_llm_call` | `(agent, iteration, messages) -> messages` |                      Before each LLM request — can modify the messages vector |
|   `after_llm_call` |             `(agent, iteration, response)` |                            After each LLM response — before any tool executes |
| `should_interrupt` |                `(tool_name, args) -> Bool` | Before each tool executes — return `true` to pause and require human approval |
|     `on_tool_call` |                 `(agent, tool_name, args)` |                                 Before each tool is executed (after approval) |
|   `on_tool_result` |               `(agent, tool_name, result)` |                                                       After each tool returns |
|      `on_complete` |                          `(agent, result)` |                                                When `run!` is about to return |


`should_interrupt` is the recommended way to gate dangerous tools. When it returns `true` for any pending tool call, the framework collects all flagged calls, throws a `HumanInterrupt`, and no tools execute. Call `resume!(session, response)` then re-run `run!` to continue.

**Example — gate dangerous tools**

```julia
hooks = AgentHooks(
    should_interrupt = (name, args) -> name in ["send_email", "delete_file"]
)
agent = Agent(name="Bot", instructions="...", hooks=hooks)

try
    run!(agent, "Send an email and delete the log"; session=session)
catch e
    e isa HumanInterrupt || rethrow(e)
    println(e.message)           # "About to call: send_email, delete_file"
    resume!(session, readline()) # inject human response
    run!(agent, "Send an email and delete the log"; session=session)
end
```


**Example — observability only**

```julia
hooks = AgentHooks(
    on_tool_call   = (ag, name, args)   -> println("calling $name with $args"),
    on_tool_result = (ag, name, result) -> println("$name returned $result"),
    on_complete    = (ag, result)       -> println("done: $result"),
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L243-L289" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.ApprovalTimeout' href='#NimbleAgents.ApprovalTimeout'><span class="jlbinding">NimbleAgents.ApprovalTimeout</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
ApprovalTimeout(tool_calls, timeout)
```


Thrown when an `approval_channel` is provided but no response arrives within `approval_timeout` seconds.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L53-L58" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Artifact' href='#NimbleAgents.Artifact'><span class="jlbinding">NimbleAgents.Artifact</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Artifact(; session_id, name, type, content_type, path, metadata)
```


A named, typed output produced by an agent during a session.

**Fields**
- `id::String`: UUID identifying this artifact.
  
- `session_id::String`: Session that produced this artifact.
  
- `name::String`: Human-readable label.
  
- `type::Symbol`: `:file`, `:plot`, `:data`, or `:text`.
  
- `content_type::String`: MIME type (`"image/png"`, `"text/csv"`, etc.).
  
- `path::String`: Path to the artifact file.
  
- `metadata::Dict{String,Any}`: Arbitrary extra info (source tool, size, etc.).
  
- `created_at::Float64`: `time()` when registered.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L17-L31" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Block' href='#NimbleAgents.Block'><span class="jlbinding">NimbleAgents.Block</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Block(reason::String)
```


Guardrail result — halt execution and return `reason` as the agent&#39;s response.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/guardrails.jl#L38-L42" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.CLIArg' href='#NimbleAgents.CLIArg'><span class="jlbinding">NimbleAgents.CLIArg</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
CLIArg(type, description; required=true)
```


Describes one argument of a `CLITool`.

**Fields**
- `type::Type`: Julia type for the argument (`String`, `Int`, `Float64`, `Bool`).
  
- `description::String`: Shown to the LLM in the tool schema.
  
- `required::Bool`: Whether the argument must be provided (default: `true`).
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/cli_tools.jl#L26-L35" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.CLITool' href='#NimbleAgents.CLITool'><span class="jlbinding">NimbleAgents.CLITool</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
CLITool(; name, description, command, args, timeout, working_dir, return_direct)
```


An `AbstractTool` that runs a shell command as a subprocess.

Arguments from the LLM are substituted into `{arg_name}` placeholders in the `command` vector. Each argument is passed as a separate process argument — no shell string is constructed, making injection structurally impossible.

**Fields**
- `name::String`: Tool name shown to the LLM.
  
- `description::String`: What the tool does and when to use it.
  
- `command::Vector{String}`: Command and arguments with `{placeholder}` slots.
  
- `args::Vector{Pair{String,CLIArg}}`: Ordered argument definitions.
  
- `timeout::Float64`: Seconds before the subprocess is killed (default: `30.0`).
  
- `working_dir::Union{String,Nothing}`: Working directory for the subprocess.
  
- `return_direct::Bool`: Short-circuit the agent loop after this tool (default: `false`).
  

**Example**

```julia
git_log = CLITool(
    name        = "git_log",
    description = "Show recent git commits.",
    command     = ["git", "log", "--oneline", "-{n}"],
    args        = ["n" => CLIArg(Int, "Number of commits to show.")],
)

agent = Agent(
    name  = "DevBot",
    tools = [git_log],
)
```


**Example — multiple args**

```julia
grep_tool = CLITool(
    name        = "grep",
    description = "Search for a pattern in files. Returns matching lines.",
    command     = ["grep", "-rn", "{pattern}", "{path}"],
    args        = [
        "pattern" => CLIArg(String, "Regex pattern to search for."),
        "path"    => CLIArg(String, "File or directory to search in."),
    ],
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/cli_tools.jl#L46-L91" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.ContextConfig' href='#NimbleAgents.ContextConfig'><span class="jlbinding">NimbleAgents.ContextConfig</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
ContextConfig(; context_window, compact_threshold, keep_last, summary_model)
```


Controls automatic context-window management for long-running sessions.

When `session.history` grows large enough to risk hitting the model&#39;s context limit, NimbleAgents compacts it using a **hybrid strategy**:
1. The most recent `keep_last` messages are always kept verbatim — they carry the immediate context the model needs for the current turn.
  
2. Everything older is summarised into a single compressed message by the LLM, replacing the raw history.
  

This mirrors the approach used by Claude Code and Codex: compact at ~80% of the context window, not at 100%, so there is always headroom for the current turn&#39;s input and the model&#39;s output.

**Fields**
- `context_window::Int`: Total token capacity of the model (default: `400_000`). Set to match Claude Opus 4.5/4.6 (400k context, 128k max output).
  
- `compact_threshold::Float64`: Fraction of `context_window` at which compaction is triggered (default: `0.80`).  At 80% × 400k = 320k tokens, there is still 80k of headroom — enough for a large current-turn input plus a full output. Claude Code and Codex both use ~80% as their trigger.
  
- `keep_last::Int`: Number of recent messages to preserve verbatim after compaction (default: `20`). These are never summarised so the agent retains immediate conversational context.
  
- `summary_model::Union{String,Nothing}`: Model used for the summarisation call. Defaults to `nothing`, which means the agent&#39;s own model is used.
  

**Example**

```julia
# Long-running session with aggressive compaction
session_agent = Agent(
    name    = "LongBot",
    instructions = "...",
    context = ContextConfig(keep_last=10),
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L187-L226" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.EvalCase' href='#NimbleAgents.EvalCase'><span class="jlbinding">NimbleAgents.EvalCase</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
EvalCase(; input, expected, expected_tools, reference, tags)
```


A single evaluation test case.

**Fields**
- `input::String`: User message to send to the agent.
  
- `expected::Union{String, Nothing}`: Expected answer text (for text-matching metrics).
  
- `expected_tools::Union{Vector{String}, Nothing}`: Expected tool call names in order.
  
- `reference::Union{Dict{String,Any}, Nothing}`: Arbitrary ground-truth metadata.
  
- `tags::Vector{String}`: Tags for filtering/grouping results.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L19-L30" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.EvalReport' href='#NimbleAgents.EvalReport'><span class="jlbinding">NimbleAgents.EvalReport</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
EvalReport(results)
```


Aggregate report over all eval results. Computes pass rate, mean scores, total cost, and total duration from the individual results.

**Fields**
- `results::Vector{EvalResult}`: All individual results.
  
- `pass_rate::Float64`: Fraction of cases that passed.
  
- `mean_scores::Dict{String, Float64}`: Mean score per metric across all cases.
  
- `total_cost::Float64`: Sum of trace costs.
  
- `total_duration::Float64`: Sum of elapsed times.
  
- `timestamp::Float64`: When the report was created.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L73-L86" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.EvalResult' href='#NimbleAgents.EvalResult'><span class="jlbinding">NimbleAgents.EvalResult</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
EvalResult
```


Result for a single eval case.

**Fields**
- `case::EvalCase`: The original test case.
  
- `output::Any`: Actual agent response.
  
- `trace::Union{Trace, Nothing}`: Full trace from `run!`.
  
- `scores::Dict{String, Float64}`: Metric name =&gt; score (0.0–1.0).
  
- `passed::Bool`: Whether all scores met the pass threshold.
  
- `error::Union{String, Nothing}`: Error message if `run!` threw.
  
- `elapsed::Float64`: Wall-clock time for this case.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L49-L62" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.ExternalAgentTool' href='#NimbleAgents.ExternalAgentTool'><span class="jlbinding">NimbleAgents.ExternalAgentTool</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
ExternalAgentTool(; name, description, command, args, timeout, working_dir,
                    on_output, parse_result)
```


An `AbstractTool` for running external CLI agents (Claude Code, Codex, etc.) as subprocesses with real-time progress streaming.

Unlike `CLITool` (which buffers all output), `ExternalAgentTool` reads stdout line-by-line and fires `on_output(line)` for each line as it arrives. This enables progress visibility for long-running agents.

**Fields**
- `name::String`: Tool name shown to the LLM.
  
- `description::String`: What the tool does and when to use it.
  
- `command::Vector{String}`: Command with `{placeholder}` slots (same as `CLITool`).
  
- `args::Vector{Pair{String,CLIArg}}`: Ordered argument definitions.
  
- `timeout::Float64`: Seconds before the subprocess is killed (default: `300.0`).
  
- `working_dir::Union{String,Nothing}`: Working directory for the subprocess.
  
- `on_output::Union{Function,Nothing}`: Called with each stdout line as it arrives. Use for progress logging (default: `nothing` — silent).
  
- `parse_result::Union{Function,Nothing}`: Post-process the collected output lines into a final result string. Receives `Vector{String}` of all stdout lines. Default: `nothing` (returns raw output joined by newlines).
  
- `return_direct::Bool`: Short-circuit the agent loop after this tool (default: `false`).
  

**Example**

```julia
coder = ExternalAgentTool(
    name        = "coder",
    description = "Run Claude Code to implement a task.",
    command     = ["claude", "-p", "{task}", "--output-format", "stream-json",
                   "--verbose", "--model", "sonnet"],
    args        = ["task" => CLIArg(String, "The coding task.")],
    timeout     = 300.0,
    on_output   = line -> println("[coder] ", line),
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/external_agent.jl#L30-L67" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.GeminiOpenAISchema' href='#NimbleAgents.GeminiOpenAISchema'><span class="jlbinding">NimbleAgents.GeminiOpenAISchema</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
GeminiOpenAISchema <: PT.AbstractOpenAISchema
```


Schema for calling the Gemini API via Google&#39;s OpenAI-compatible endpoint.

Fixes two bugs in PromptingTools.jl&#39;s built-in `GoogleOpenAISchema`:
1. Uses the correct base URL (`/v1beta/openai/` instead of `/v1beta/`)
  
2. Supports streaming via `streamcallback`
  

Inherits all message rendering, tool calling, structured output, and response parsing from PT&#39;s `AbstractOpenAISchema`.

**Supported features (via OpenAI compatibility)**
- Chat completions (`aigenerate`)
  
- Tool/function calling (`aitools`)
  
- Structured output (`aiextract`)
  
- Streaming
  
- Thinking/reasoning (`reasoning_effort` parameter)
  
- Image input (base64 via `image_url`)
  

**Example**

```julia
using NimbleAgents

# Automatic — GeminiOpenAISchema is selected for "gemini-*" models
agent = Agent(name="Bot", model="gemini-2.5-flash", instructions="You are helpful.")
run!(agent, "Hello!")

# With thinking/reasoning
agent = Agent(
    name="Thinker", model="gemini-2.5-flash",
    instructions="Think step by step.",
    api_kwargs=(; reasoning_effort="medium"),
)

# Manual schema selection
schema = GeminiOpenAISchema()
msg = PT.aigenerate(schema, "Hello!"; model="gemini-2.5-flash")
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/gemini.jl#L35-L74" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Guardrail' href='#NimbleAgents.Guardrail'><span class="jlbinding">NimbleAgents.Guardrail</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Guardrail(; name, check, on=:input)
```


A check that runs at the boundary of the agent loop.

**Fields**
- `name::String`: Human-readable label shown in verbose output.
  
- `check::Function`: `(value::String) -> GuardrailResult`. Return `Pass()` to continue, `Block(reason)` to halt, or `Modify(new_value)` to rewrite.
  
- `on::Symbol`: When to run — `:input` (before the agent loop) or `:output` (after the agent produces its final response). Default: `:input`.
  

**Examples**

```julia
# Rule-based input guardrail
no_pii = Guardrail(
    name  = "no_pii",
    on    = :input,
    check = input -> occursin(r"\d{3}-\d{2}-\d{4}", input) ?
                     Block("Input contains a Social Security Number.") : Pass(),
)

# Sanitising input guardrail
strip_html = Guardrail(
    name  = "strip_html",
    on    = :input,
    check = input -> Modify(replace(input, r"<[^>]+>" => "")),
)

# Output guardrail
no_links = Guardrail(
    name  = "no_links",
    on    = :output,
    check = output -> occursin(r"https?://", output) ?
                      Block("Response contained external links.") : Pass(),
)

agent = Agent(
    name       = "SafeBot",
    guardrails = [no_pii, strip_html, no_links],
    ...
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/guardrails.jl#L60-L104" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Handoff' href='#NimbleAgents.Handoff'><span class="jlbinding">NimbleAgents.Handoff</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Handoff
```


A signal returned by an agent indicating that control should transfer to another agent. Use `handoff_tool(agent)` to create a `Tool` that an agent can call to trigger the transfer.

**Fields**
- `target::Agent`: The agent to hand off to.
  
- `message::String`: The message to pass to the target agent (defaults to the current user input if empty).
  
- `history_filter::HandoffFilter`: How to transform conversation history on handoff.
  

The orchestrator loop in `run_pipeline!` detects `Handoff` results and re-runs with the new agent automatically.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L76-L91" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.HandoffFilter' href='#NimbleAgents.HandoffFilter'><span class="jlbinding">NimbleAgents.HandoffFilter</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
HandoffFilter
```


Controls how conversation history is transformed when handing off to the next agent. Pass a `HandoffFilter` to `handoff_tool` or `run_pipeline!` to filter the session history before the receiving agent sees it.

**Built-in filters (symbols)**
- `:all`          — pass full history unchanged (default)
  
- `:none`         — clear history; receiving agent starts fresh
  
- `:strip_tools`  — remove all tool-call and tool-result messages
  
- `:last_n`       — keep only the last N messages (use `HandoffFilter(:last_n, 5)`)
  

**Custom filter (function)**

Pass a function `(history::Vector{PT.AbstractMessage}) -> Vector{PT.AbstractMessage}` for full control over what the receiving agent sees.

**Examples**

```julia
# Strip tool messages on handoff
handoff_tool(billing; history_filter = HandoffFilter(:strip_tools))

# Keep only last 3 messages
handoff_tool(billing; history_filter = HandoffFilter(:last_n, 3))

# Custom function
handoff_tool(billing; history_filter = HandoffFilter(msgs -> filter(m -> m isa PT.UserMessage, msgs)))
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L11-L39" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.HumanInterrupt' href='#NimbleAgents.HumanInterrupt'><span class="jlbinding">NimbleAgents.HumanInterrupt</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
HumanInterrupt(tool_calls; message)
```


Thrown from `after_llm_call` to pause the agent loop before any tool executes.

The LLM has produced a plan (`tool_calls`) but no side-effects have occurred yet. The caller catches this, presents the pending actions to a human, and either:
- **Approves** → calls `resume!(session, "Approved")` and re-runs `run!`
  
- **Rejects**  → calls `resume!(session, "Rejected — do X instead")` and re-runs `run!`
  
- **Aborts**   → discards the session entirely
  

**Fields**
- `tool_calls`: The pending tool calls the LLM intended to execute.
  
- `message::String`: Optional context message (default: `"Human approval required"`).
  

**Example**

```julia
hooks = AgentHooks(
    after_llm_call = (agent, iter, msg) -> begin
        dangerous = ["delete_file", "send_email", "write_db"]
        pending   = filter(t -> t.name in dangerous, something(msg.tool_calls, []))
        isempty(pending) && return
        throw(HumanInterrupt(pending;
            message = "About to: " * join([t.name for t in pending], ", ")))
    end
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L13-L40" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.InMemoryMemoryService' href='#NimbleAgents.InMemoryMemoryService'><span class="jlbinding">NimbleAgents.InMemoryMemoryService</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
InMemoryMemoryService()
```


In-memory memory backend using keyword search. Good for testing and short-lived applications. All data is lost when the process exits.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/memory.jl#L102-L107" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.InMemorySessionStore' href='#NimbleAgents.InMemorySessionStore'><span class="jlbinding">NimbleAgents.InMemorySessionStore</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
InMemorySessionStore()
```


An in-memory session store. Sessions are kept for the lifetime of the process and lost on restart. Suitable as the default for `serve()` and for testing.

Artifacts are stored in a temp directory that is also ephemeral.

```julia
store   = InMemorySessionStore()
session = Session(app_name="MyApp", user_id="alice")
save!(store, session)
load(store, session.id)  # → same Session object
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L101-L115" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.JSONSessionStore' href='#NimbleAgents.JSONSessionStore'><span class="jlbinding">NimbleAgents.JSONSessionStore</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
JSONSessionStore(dir)
```


Persist sessions as JSON files in `dir`. Artifacts are copied into `dir/../artifacts/<session_id>/`.

```julia
store = JSONSessionStore(".nimble/sessions")
save!(store, session)
session = load(store, session_id)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L198-L209" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.MCPClient' href='#NimbleAgents.MCPClient'><span class="jlbinding">NimbleAgents.MCPClient</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
MCPClient(server)
```


A live connection to one MCP server via stdio. Created via `connect!(MCPClient(server))`. Not constructed directly by users — attach `MCPServer` objects to an `Agent` and the framework manages client lifetime.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L106-L112" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.MCPHTTPClient' href='#NimbleAgents.MCPHTTPClient'><span class="jlbinding">NimbleAgents.MCPHTTPClient</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
MCPHTTPClient(server)
```


A live connection to one MCP server via HTTP POST. Created automatically when an `MCPServer` is constructed with a `url` field.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L130-L135" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.MCPServer' href='#NimbleAgents.MCPServer'><span class="jlbinding">NimbleAgents.MCPServer</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
MCPServer(; command, args, env, timeout, cache_tools)
MCPServer(; url, headers, timeout, cache_tools)
```


Describes an MCP server that NimbleAgents can connect to.

Two transports are supported:
- **stdio** — spawns the server as a local subprocess. Provide `command` (and optionally `args` / `env`).
  
- **HTTP** — connects to a remote MCP endpoint via HTTP POST. Provide `url` (and optionally `headers` for authentication).
  

**Fields (stdio)**
- `command::String`: Executable to run (e.g. `"uvx"`, `"npx"`, `"python"`).
  
- `args::Vector{String}`: Arguments passed to the command.
  
- `env::Dict{String,String}`: Extra environment variables for the subprocess.
  

**Fields (HTTP)**
- `url::String`: HTTP endpoint URL (e.g. `"https://docs.langchain.com/mcp"`).
  
- `headers::Dict{String,String}`: Request headers, e.g. for auth tokens.
  

**Fields (shared)**
- `timeout::Float64`: Seconds to wait for each JSON-RPC response (default: `60.0`).
  
- `cache_tools::Bool`: Cache tool list after first discovery (default: `true`).
  

**Examples**

```julia
# stdio
server = MCPServer(
    command = "uvx",
    args    = ["--from", "mcpdoc", "mcpdoc",
               "--urls", "LangGraph:https://langchain-ai.github.io/langgraph/llms.txt",
               "--transport", "stdio"],
)

# HTTP — no auth
server = MCPServer(url="https://docs.langchain.com/mcp")

# HTTP — with Bearer token
server = MCPServer(
    url     = "https://huggingface.co/mcp",
    headers = Dict("Authorization" => "Bearer hf_xxx"),
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L32-L77" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.MemoryEntry' href='#NimbleAgents.MemoryEntry'><span class="jlbinding">NimbleAgents.MemoryEntry</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
MemoryEntry(; content, user_id, app_name, metadata, source_session_id)
```


A single stored fact in the memory system.

**Fields**
- `id::String`: Unique identifier (auto-generated UUID).
  
- `content::String`: The fact text.
  
- `user_id::String`: User who owns this memory.
  
- `app_name::String`: Application scope.
  
- `metadata::Dict{String,Any}`: Arbitrary key-value metadata.
  
- `source_session_id::Union{String,Nothing}`: Session that created this memory.
  
- `created_at::Float64`: `time()` when the memory was created.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/memory.jl#L17-L30" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Modify' href='#NimbleAgents.Modify'><span class="jlbinding">NimbleAgents.Modify</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Modify(value::String)
```


Guardrail result — replace the current input or output with `value` and continue.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/guardrails.jl#L47-L51" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.NamedMetric' href='#NimbleAgents.NamedMetric'><span class="jlbinding">NimbleAgents.NamedMetric</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
NamedMetric(name, fn)
```


Wrapper for a metric closure (e.g. from a factory like `cost_budget`) that carries a display name. Made callable: `(m::NamedMetric)(case, output, trace)`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L124-L129" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.NimbleTool' href='#NimbleAgents.NimbleTool'><span class="jlbinding">NimbleAgents.NimbleTool</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
NimbleTool(; name, parameters, description, callable, return_direct, strict)
```


A tool with all the fields of `PT.Tool` plus `return_direct::Bool`.

When `return_direct = true`, the agent loop short-circuits immediately after this tool executes — its return value becomes the agent&#39;s final output without any further LLM call.

Use `@tool` (or `@tool return_direct=true`) to create tools; you rarely need to construct `NimbleTool` directly.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tools.jl#L18-L29" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Pass' href='#NimbleAgents.Pass'><span class="jlbinding">NimbleAgents.Pass</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Pass()
```


Guardrail result — allow execution to continue unchanged.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/guardrails.jl#L31-L35" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.RateLimiter' href='#NimbleAgents.RateLimiter'><span class="jlbinding">NimbleAgents.RateLimiter</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
RateLimiter
```


Token-bucket rate limiter. Allows up to `rate` requests per second, with a burst capacity equal to `rate`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/rate_limit.jl#L23-L28" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.RetryConfig' href='#NimbleAgents.RetryConfig'><span class="jlbinding">NimbleAgents.RetryConfig</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
RetryConfig(; max_retries, initial_delay, max_delay, multiplier, jitter,
              retry_on_status, max_parse_retries)
```


Exponential-backoff retry policy for LLM API calls made inside `run!`.

**Fields**
- `max_retries::Int`: Maximum number of retry attempts after the first failure (default: `3`).
  
- `initial_delay::Float64`: Seconds to wait before the first retry (default: `0.5`). Consensus across Anthropic SDK and LangGraph; fast enough for transient errors.
  
- `max_delay::Float64`: Maximum seconds to wait between retries (default: `60.0`). Chosen to match the standard 1-minute rate-limit reset window used by both OpenAI and Anthropic — capping here means later retries will wait long enough to clear a sustained 429 burst without hanging indefinitely.
  
- `multiplier::Float64`: Exponential growth factor (default: `2.0`). Universal across all reference SDKs (OpenAI, Anthropic, ADK, LangGraph).
  
- `jitter::Bool`: When `true`, multiplies each delay by a random factor in `[0.75, 1.0]` (Anthropic-style multiplicative jitter). Prevents thundering-herd when many parallel agents retry simultaneously (default: `true`).
  
- `retry_on_status::Vector{Int}`: HTTP status codes that warrant a retry.
  - `408` request timeout, `429` rate limit — always transient
    
  - `500/502/503/504` server-side errors — usually transient
    
  - `529` Anthropic-specific overload status
    
  4xx errors outside this list (401, 400, 403, 404) are permanent failures and are never retried regardless of this setting.
  
- `max_parse_retries::Int`: Maximum number of re-prompts when `output_type` parsing fails (default: `2`). On each failure the parse error is fed back to the LLM as a user message so it can correct its response. Set to `0` to disable.
  

**Example**

```julia
agent = Agent(
    name   = "Bot",
    instructions = "...",
    retry  = RetryConfig(max_retries=5, max_delay=120.0),
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L97-L134" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.SQLiteMemoryService' href='#NimbleAgents.SQLiteMemoryService'><span class="jlbinding">NimbleAgents.SQLiteMemoryService</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
SQLiteMemoryService(path)
```


Persist memories in a SQLite database at `path`. The database and table are created automatically on first use.

**Example**

```julia
mem = SQLiteMemoryService("memory.db")
add_memory!(mem, "User prefers dark mode"; user_id="alice", app_name="MyApp")
results = search_memory(mem, "dark mode"; user_id="alice", app_name="MyApp")
close!(mem)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/sqlite_memory.jl#L17-L30" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.SQLiteSessionStore' href='#NimbleAgents.SQLiteSessionStore'><span class="jlbinding">NimbleAgents.SQLiteSessionStore</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
SQLiteSessionStore(path; artifacts_dir)
```


Persist sessions in a SQLite database at `path`. The database and tables are created automatically on first use.

Artifacts are stored in `artifacts_dir` (defaults to a sibling `artifacts/` directory next to the database file).

**Example**

```julia
store = SQLiteSessionStore("sessions.db")
session = Session(app_name="MyApp", user_id="alice")
run!(agent, "Hello"; session, store)

# Later — restore the session
session = load(store, session.id)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/sqlite_store.jl#L17-L35" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Session' href='#NimbleAgents.Session'><span class="jlbinding">NimbleAgents.Session</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Session(; id, app_name, user_id)
```


An in-memory session that persists conversation state across multiple `run!` calls.

Inspired by Google ADK&#39;s Session model. Holds three things:
- **`history`** — the message log the LLM sees on every turn
  
- **`state`** — a free-form key-value store for cross-turn variables
  
- **`events`** — an audit log of every turn (inputs, outputs, tool calls, token usage)
  

**Fields**
- `id::String`: Unique session identifier (auto-generated UUID if not provided).
  
- `app_name::String`: Name of the application using this session.
  
- `user_id::String`: Identifier for the user (default `"default"`).
  
- `history::Vector{PT.AbstractMessage}`: Accumulated message history.
  
- `state::Dict{String,Any}`: Cross-turn key-value store.
  
- `events::Vector{TurnEvent}`: Ordered log of every completed turn.
  
- `created_at::Float64`: `time()` when the session was created.
  
- `lock::ReentrantLock`: Protects `history` and `events` for concurrent `fan_out` / `spawn_subagents` calls.
  

**Example**

```julia
session = Session(app_name="MathApp", user_id="alice")

run!(agent, "What is 8 + 14?"; session=session)
run!(agent, "Now multiply that by 3"; session=session)

# Inspect history
length(session)           # number of messages
session.state["score"]    # cross-turn variable set by a tool or hook
session.events[1]         # TurnEvent for the first run! call
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L79-L112" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Skill' href='#NimbleAgents.Skill'><span class="jlbinding">NimbleAgents.Skill</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Skill(; name, description, path)
```


A filesystem-based capability package. Contains a `SKILL.md` file with instructions that the agent can load on demand.

Use `discover_skills(dirs)` to auto-discover skills from directories, or construct directly with an explicit `path`.

**Fields**
- `name::String`: Skill identifier (from YAML frontmatter).
  
- `description::String`: One-line description used in the agent&#39;s system prompt to help it decide when to load this skill.
  
- `path::String`: Absolute path to the skill directory.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/skills.jl#L15-L29" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.ToolEvent' href='#NimbleAgents.ToolEvent'><span class="jlbinding">NimbleAgents.ToolEvent</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
ToolEvent
```


A record of one tool call made during a `run!` turn.

**Fields**
- `name::String`: Tool name.
  
- `args::Dict{Symbol,Any}`: Arguments passed to the tool.
  
- `result::Any`: Return value (or `nothing` if an error occurred).
  
- `error::Union{String,Nothing}`: Error message if the tool threw, otherwise `nothing`.
  
- `timestamp::Float64`: `time()` when the tool was called.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L11-L22" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.Trace' href='#NimbleAgents.Trace'><span class="jlbinding">NimbleAgents.Trace</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Trace(session)
Trace(turns::Vector{TurnEvent})
```


A lightweight view over a session&#39;s event log.

Aggregates token usage, cost, elapsed time, and tool call statistics across all turns. No new data is collected — everything comes from `TurnEvent` / `ToolEvent` already recorded by `run!`.

**Fields**
- `turns::Vector{TurnEvent}`: All turns in order.
  
- `total_input_tokens::Int`: Sum of input tokens across all turns.
  
- `total_output_tokens::Int`: Sum of output tokens across all turns.
  
- `total_tokens::Int`: `total_input_tokens + total_output_tokens`.
  
- `total_cost::Float64`: Estimated total USD cost across all turns.
  
- `total_llm_calls::Int`: Total number of LLM requests made.
  
- `total_tool_calls::Int`: Total number of tool calls made.
  
- `duration::Float64`: Wall-clock seconds from first turn start to last turn end.
  
- `agents::Vector{String}`: Unique agent names that handled turns (in order of first appearance).
  

**Example**

```julia
session = Session(app_name="MyApp", user_id="alice")
run!(agent, "What is 2 + 2?"; session=session)

trace = Trace(session)
println("Cost: $", round(trace.total_cost; digits=4))
print_trace(trace)
save_trace(trace, "trace.json")
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tracer.jl#L20-L51" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.TurnEvent' href='#NimbleAgents.TurnEvent'><span class="jlbinding">NimbleAgents.TurnEvent</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
TurnEvent
```


A record of one complete `run!` invocation — one &quot;turn&quot; in the conversation.

**Fields**
- `agent::String`: Name of the agent that handled this turn.
  
- `model::String`: LLM model identifier used for this turn.
  
- `input::String`: The user message for this turn.
  
- `output::Any`: The final response returned by `run!`.
  
- `tool_calls::Vector{ToolEvent}`: All tool calls made during this turn, in order.
  
- `llm_calls::Int`: Number of LLM requests made.
  
- `input_tokens::Int`: Total input tokens used across all LLM calls this turn.
  
- `output_tokens::Int`: Total output tokens used across all LLM calls this turn.
  
- `cost::Float64`: Estimated USD cost for this turn (based on model pricing).
  
- `elapsed::Float64`: Wall-clock time in seconds for the whole turn.
  
- `timestamp::Float64`: `time()` when `run!` was called.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L40-L57" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Base.delete!-Tuple{JSONSessionStore, String}' href='#Base.delete!-Tuple{JSONSessionStore, String}'><span class="jlbinding">Base.delete!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
delete!(store::JSONSessionStore, session_id::String)
```


Remove the session JSON file and its artifacts directory.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L373-L377" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents._acquire_rate_limit!-Tuple{String}' href='#NimbleAgents._acquire_rate_limit!-Tuple{String}'><span class="jlbinding">NimbleAgents._acquire_rate_limit!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
_acquire_rate_limit!(model::String)
```


Internal: called by the agent loop before each LLM call. If a rate limit is set for this model (or a default limit exists), blocks until a token is available. If no limit is set, returns immediately.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/rate_limit.jl#L127-L133" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents._edit_distance-Tuple{AbstractString, AbstractString}' href='#NimbleAgents._edit_distance-Tuple{AbstractString, AbstractString}'><span class="jlbinding">NimbleAgents._edit_distance</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Levenshtein edit distance (single-row DP, no dependencies).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L143" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents._keyword_score-Tuple{String, String}' href='#NimbleAgents._keyword_score-Tuple{String, String}'><span class="jlbinding">NimbleAgents._keyword_score</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
_keyword_score(query, content) -> Float64
```


Score how well `content` matches `query` using keyword overlap + substring boost. Returns a value in [0, 1].


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/memory.jl#L75-L80" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents._memory_prompt-Tuple{Union{Nothing, AbstractMemoryService}, String, Union{Nothing, Session}}' href='#NimbleAgents._memory_prompt-Tuple{Union{Nothing, AbstractMemoryService}, String, Union{Nothing, Session}}'><span class="jlbinding">NimbleAgents._memory_prompt</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
_memory_prompt(memory, input, session) -> String
```


Build a system prompt fragment with relevant memories for the current input. Returns `""` if memory is nothing, session is nothing, or no results are found.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/memory.jl#L177-L182" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents._metric_name-Tuple{Function}' href='#NimbleAgents._metric_name-Tuple{Function}'><span class="jlbinding">NimbleAgents._metric_name</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Extract a display name from a metric function or NamedMetric.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L139" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents._resolve_instructions-Tuple{String, Any, Any}' href='#NimbleAgents._resolve_instructions-Tuple{String, Any, Any}'><span class="jlbinding">NimbleAgents._resolve_instructions</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Resolve agent instructions — static string or dynamic callable.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L303" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.acquire!-Tuple{RateLimiter}' href='#NimbleAgents.acquire!-Tuple{RateLimiter}'><span class="jlbinding">NimbleAgents.acquire!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
acquire!(limiter::RateLimiter)
```


Block until a token is available, then consume one. Returns immediately if tokens are available.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/rate_limit.jl#L40-L45" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.agent_as_tool-Tuple{Agent}' href='#NimbleAgents.agent_as_tool-Tuple{Agent}'><span class="jlbinding">NimbleAgents.agent_as_tool</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
agent_as_tool(agent; name, description, session) -> Tool
```


Wrap `agent` as a `Tool` that a parent (orchestrator) agent can call.  The subagent runs a full `run!` loop for each call and its result is returned as a string back to the orchestrator.

The shared `session` is threaded through so the subagent&#39;s turns appear in the same event log.

**Example**

```julia
math_agent = Agent(name="Math", instructions="Do arithmetic.", tools=[add_tool])

orchestrator = Agent(
    name         = "Orchestrator",
    instructions = "Route requests to specialist agents.",
    tools        = [agent_as_tool(math_agent)],
)

run!(orchestrator, "What is 3 + 4?")
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L155-L177" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.build_tool_map-Tuple{Vector{<:AbstractTool}}' href='#NimbleAgents.build_tool_map-Tuple{Vector{<:AbstractTool}}'><span class="jlbinding">NimbleAgents.build_tool_map</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
build_tool_map(tools) -> Dict{String, Tool}
```


Convert a vector of `Tool` objects into a name-keyed dict for fast dispatch.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tools.jl#L185-L189" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.chat!-Tuple{Agent}' href='#NimbleAgents.chat!-Tuple{Agent}'><span class="jlbinding">NimbleAgents.chat!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
chat!(agent::Agent; session, model, verbose)
```


Start an interactive multi-turn conversation with `agent` in the Julia REPL.

Tokens stream to stdout as they arrive. Conversation history accumulates in the session across turns, so the agent maintains context throughout the conversation.

**Slash Commands**
- `/exit` or `/quit` — end the conversation
  
- `/reset` — clear conversation history and start fresh
  
- `/trace` — show token usage, cost, and tool call summary
  
- `/help` — show available commands
  

**Arguments**
- `agent::Agent`: The agent to chat with.
  
- `session::Session`: Session for conversation history (default: auto-created).
  
- `verbose::Bool`: Show tool call details (default: `false`).
  

**Example**

```julia
agent = Agent(name="Bot", instructions="You are helpful.", tools=[search_tool])
chat!(agent)
```


```julia
chat!(; model)
```


Start a conversation with the built-in NimbleAgents documentation bot. It has access to the framework&#39;s source code, docs, and examples via filesystem tools.

Requires an LLM API key — set `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GOOGLE_API_KEY` in your environment or `.env` file.

**Arguments**
- `model::String`: LLM model to use (default: `"gpt-4.1-nano"`).
  

**Example**

```julia
using NimbleAgents
chat!()
# You> How do I add guardrails to an agent?
# NimbleAgents> ...
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/repl.jl#L20-L63" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.claude_code_tool-Tuple{}' href='#NimbleAgents.claude_code_tool-Tuple{}'><span class="jlbinding">NimbleAgents.claude_code_tool</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
claude_code_tool(; name, description, model, working_dir, timeout,
                   max_budget, permission_mode, allowed_tools, on_output,
                   system_prompt, session_id, resume, extra_flags)
```


Create an `ExternalAgentTool` that delegates tasks to Claude Code via `claude -p`.

Uses `--output-format stream-json --verbose` for structured streaming output. The `on_output` callback receives each line of stream-json as it arrives, enabling real-time progress monitoring.

::: tip Authentication

Claude Code must be authenticated before use. Either:
1. Run `claude login` once in your terminal (stores credentials in `~/.claude/`), or
  
2. Set `ANTHROPIC_API_KEY` in your `.env` or environment (inherited by subprocess).
  

Login cannot be done programmatically — it requires an interactive browser OAuth flow.

:::

**Arguments**
- `name::String`: Tool name (default: `"claude_code"`).
  
- `description::String`: Description shown to the LLM.
  
- `model::String`: Claude model to use (default: `"sonnet"`).
  
- `working_dir::Union{String,Nothing}`: Working directory for Claude Code.
  
- `timeout::Float64`: Seconds before kill (default: `300.0`).
  
- `max_budget::Union{Float64,Nothing}`: Max USD budget per invocation.
  
- `permission_mode::String`: Permission mode (default: `"bypassPermissions"`).
  
- `allowed_tools::Union{Vector{String},Nothing}`: Restrict available tools.
  
- `on_output::Union{Function,Nothing}`: Called per stream-json line.
  
- `system_prompt::Union{String,Nothing}`: Custom system prompt for Claude Code.
  
- `session_id::Union{String,Nothing}`: Session ID to continue a previous conversation. When set, Claude Code resumes the specified session, retaining full conversation context.
  
- `resume::Bool`: If `true`, resume the most recent session (default: `false`). Mutually exclusive with `session_id` — if both are set, `session_id` takes precedence.
  
- `extra_flags::Vector{String}`: Additional CLI flags.
  

**Example**

```julia
coder = claude_code_tool(
    working_dir = "/path/to/repo",
    model       = "sonnet",
    max_budget  = 2.00,
    on_output   = line -> begin
        try
            event = JSON3.read(line)
            if event.type == "assistant"
                println("[claude] ", get(event.message.content[1], :text, ""))
            end
        catch; end
    end,
)

agent = Agent(
    name = "PM",
    instructions = "Delegate implementation tasks to claude_code.",
    tools = [coder],
)

# Resume a previous Claude Code session by ID
coder_resume = claude_code_tool(session_id = "abc-123", working_dir = "/path/to/repo")

# Resume the most recent session
coder_latest = claude_code_tool(resume = true, working_dir = "/path/to/repo")
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/external_agent.jl#L210-L272" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.close!-Tuple{MCPClient}' href='#NimbleAgents.close!-Tuple{MCPClient}'><span class="jlbinding">NimbleAgents.close!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
close!(client::MCPClient)
```


Terminate the MCP server subprocess and clean up I/O handles.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L535-L539" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.close!-Tuple{MCPHTTPClient}' href='#NimbleAgents.close!-Tuple{MCPHTTPClient}'><span class="jlbinding">NimbleAgents.close!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
close!(client::MCPHTTPClient)
```


No-op for HTTP clients — there is no persistent connection to close. Clears the tool cache.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L388-L393" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.close!-Tuple{SQLiteSessionStore}' href='#NimbleAgents.close!-Tuple{SQLiteSessionStore}'><span class="jlbinding">NimbleAgents.close!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
close!(store::SQLiteSessionStore)
```


Close the underlying database connection. The store should not be used after this.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/sqlite_store.jl#L178-L182" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.codex_tool-Tuple{}' href='#NimbleAgents.codex_tool-Tuple{}'><span class="jlbinding">NimbleAgents.codex_tool</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
codex_tool(; name, description, model, working_dir, timeout, on_output, extra_flags)
```


Create an `ExternalAgentTool` that delegates tasks to OpenAI Codex CLI via `codex -q`.

**Example**

```julia
coder = codex_tool(working_dir="/path/to/repo")
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/external_agent.jl#L318-L327" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.compact!-Tuple{Session, Any}' href='#NimbleAgents.compact!-Tuple{Session, Any}'><span class="jlbinding">NimbleAgents.compact!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
compact!(session, agent) -> Bool
```


Check whether `session.history` is approaching the model&#39;s context limit and, if so, compress older messages into a summary while keeping the most recent `agent.context.keep_last` messages verbatim.

Returns `true` if compaction was performed, `false` otherwise.

The hybrid strategy:
- Recent messages (`keep_last`) are always preserved — they carry the immediate context the model needs.
  
- Older messages are replaced by a single LLM-generated summary injected as a `UserMessage` tagged `[Conversation Summary]`.
  

Compaction is triggered when estimated token usage exceeds `context_window × compact_threshold` (default: 80% of 400k = 320k tokens).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L333-L350" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.connect!-Tuple{MCPClient}' href='#NimbleAgents.connect!-Tuple{MCPClient}'><span class="jlbinding">NimbleAgents.connect!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
connect!(client::MCPClient) -> MCPClient
```


Spawn the MCP server subprocess and perform the JSON-RPC initialize handshake. Returns the client (mutated in place) for chaining.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L401-L406" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.connect!-Tuple{MCPHTTPClient}' href='#NimbleAgents.connect!-Tuple{MCPHTTPClient}'><span class="jlbinding">NimbleAgents.connect!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
connect!(client::MCPHTTPClient) -> MCPHTTPClient
```


Perform the JSON-RPC initialize handshake with the remote HTTP MCP server. Returns the client for chaining.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L280-L285" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.cost_budget-Tuple{Real}' href='#NimbleAgents.cost_budget-Tuple{Real}'><span class="jlbinding">NimbleAgents.cost_budget</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
cost_budget(max_cost) -> NamedMetric
```


Factory: returns a metric that scores 1.0 if `trace.total_cost <= max_cost`, else 0.0.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L235-L239" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.discover_skills-Tuple{Vector{String}}' href='#NimbleAgents.discover_skills-Tuple{Vector{String}}'><span class="jlbinding">NimbleAgents.discover_skills</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
discover_skills(dirs::Vector{String}) -> Vector{Skill}
```


Scan each directory in `dirs` for skill subdirectories. A valid skill directory must contain a `SKILL.md` file with `name` and `description` frontmatter.

Returns all discovered skills. Silently skips directories with missing or malformed `SKILL.md` files.

**Example**

```julia
skills = discover_skills([".nimble/skills", joinpath(homedir(), ".nimble", "skills")])
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/skills.jl#L105-L118" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.dispatch_tool-Tuple{Dict{String, <:AbstractTool}, String, Dict{Symbol}}' href='#NimbleAgents.dispatch_tool-Tuple{Dict{String, <:AbstractTool}, String, Dict{Symbol}}'><span class="jlbinding">NimbleAgents.dispatch_tool</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
dispatch_tool(tool_map, name, args) -> Any
```


Look up `name` in `tool_map` and call the corresponding tool with `args` (a `Dict{Symbol, Any}`).  Returns the tool&#39;s return value, or rethrows on error.

Argument ordering uses the `required` list from the tool&#39;s JSON schema (which reflects the original parameter order), so this is robust to Julia mangling method argument names in test environments.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tools.jl#L223-L232" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.dispatch_tool-Tuple{Dict{String, <:AbstractTool}, ToolMessage}' href='#NimbleAgents.dispatch_tool-Tuple{Dict{String, <:AbstractTool}, ToolMessage}'><span class="jlbinding">NimbleAgents.dispatch_tool</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
dispatch_tool(tool_map, msg::ToolMessage) -> Any
```


Convenience overload that accepts a `ToolMessage` directly (as returned by `PromptingTools` when parsing an LLM response with tool calls).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tools.jl#L245-L250" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.exact_match-Tuple{EvalCase, Any, Any}' href='#NimbleAgents.exact_match-Tuple{EvalCase, Any, Any}'><span class="jlbinding">NimbleAgents.exact_match</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
exact_match(case, output, trace) -> Float64
```


Returns 1.0 if `string(output)` equals `case.expected` exactly, else 0.0. Returns 1.0 if `case.expected` is `nothing` (no expectation).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L169-L174" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.fan_out-Tuple{Agent, Vector{String}}' href='#NimbleAgents.fan_out-Tuple{Agent, Vector{String}}'><span class="jlbinding">NimbleAgents.fan_out</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
fan_out(agent, inputs; reducer, parallel, session, verbose) -> Any
```


Run `agent` against each element of `inputs`, then combine the results.
- `parallel = false` (default): runs each input serially in order.
  
- `parallel = true`: spawns each run on the Julia thread pool (`Threads.@spawn`); result order matches `inputs` order regardless.
  
- `reducer`: an optional two-argument function `(accumulator, result) -> accumulator` applied via `reduce`. Defaults to `nothing`, which returns `Vector{Any}`.
  
- Each run shares the same `session` if provided; concurrent writes are protected by `session.lock`.
  

**Example — serial, default reducer**

```julia
summaries = fan_out(summarizer, ["chunk 1", "chunk 2", "chunk 3"])
# => Vector{Any} of three responses
```


**Example — parallel with a string-join reducer**

```julia
report = fan_out(research_agent, topics;
                 parallel = true,
                 reducer  = (acc, x) -> acc * "\n\n" * x)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L344-L369" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.fuzzy_match-Tuple{EvalCase, Any, Any}' href='#NimbleAgents.fuzzy_match-Tuple{EvalCase, Any, Any}'><span class="jlbinding">NimbleAgents.fuzzy_match</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
fuzzy_match(case, output, trace) -> Float64
```


Returns 1.0 if `case.expected` is a case-insensitive substring of `output`. Otherwise returns a normalised similarity score based on Levenshtein distance. Returns 1.0 if `case.expected` is `nothing`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L180-L186" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.get_model_pricing-Tuple{String}' href='#NimbleAgents.get_model_pricing-Tuple{String}'><span class="jlbinding">NimbleAgents.get_model_pricing</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
get_model_pricing(model) -> Union{NamedTuple{(:input,:output)}, Nothing}
```


Look up pricing for a model. Returns `nothing` if no pricing is registered.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L195-L199" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.handoff_tool-Tuple{Agent}' href='#NimbleAgents.handoff_tool-Tuple{Agent}'><span class="jlbinding">NimbleAgents.handoff_tool</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
handoff_tool(target; name, description, history_filter) -> Tool
```


Create a `Tool` that, when called by an agent, signals a handoff to `target`. The LLM passes a `message` argument containing what to forward to the next agent.

**Arguments**
- `target::Agent`: The agent to hand off to.
  
- `name::String`: Tool name (default: `"handoff_to_$(target.name)"`).
  
- `description::String`: Tool description.
  
- `history_filter::HandoffFilter`: How to transform conversation history before the receiving agent sees it. Default: `HandoffFilter()` (pass full history).
  

**Example**

```julia
billing_agent = Agent(name="Billing", instructions="Handle billing questions.")
support_agent = Agent(
    name         = "Support",
    instructions = "Triage customer requests.",
    tools        = [
        handoff_tool(billing_agent; history_filter=HandoffFilter(:strip_tools)),
    ],
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L101-L125" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.latency_budget-Tuple{Real}' href='#NimbleAgents.latency_budget-Tuple{Real}'><span class="jlbinding">NimbleAgents.latency_budget</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
latency_budget(max_seconds) -> NamedMetric
```


Factory: returns a metric that scores 1.0 if `trace.duration <= max_seconds`, else 0.0.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L247-L251" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.list-Tuple{JSONSessionStore}' href='#NimbleAgents.list-Tuple{JSONSessionStore}'><span class="jlbinding">NimbleAgents.list</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
list(store::JSONSessionStore; app_name, user_id) -> Vector{String}
```


Return all persisted session IDs, optionally filtered by `app_name` and/or `user_id`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L386-L390" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.list_tools-Tuple{MCPClient}' href='#NimbleAgents.list_tools-Tuple{MCPClient}'><span class="jlbinding">NimbleAgents.list_tools</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
list_tools(client::MCPClient) -> Vector{NimbleTool}
```


Fetch the tool list from the MCP server and return them as `NimbleTool` objects ready to be passed to an `Agent`. Results are cached if `server.cache_tools`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/mcp.jl#L455-L460" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.load-Tuple{JSONSessionStore, String}' href='#NimbleAgents.load-Tuple{JSONSessionStore, String}'><span class="jlbinding">NimbleAgents.load</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
load(store::JSONSessionStore, session_id::String) -> Session
```


Restore a session from disk. Returns `nothing` if not found.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L343-L347" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.load_eval-Tuple{String}' href='#NimbleAgents.load_eval-Tuple{String}'><span class="jlbinding">NimbleAgents.load_eval</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
load_eval(path) -> Dict{String, Any}
```


Load a previously saved eval report from a JSON file.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L427-L431" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.load_trace-Tuple{String}' href='#NimbleAgents.load_trace-Tuple{String}'><span class="jlbinding">NimbleAgents.load_trace</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
load_trace(path) -> Dict{String, Any}
```


Load a previously saved trace from a JSON file. Returns the raw parsed Dict — useful for offline analysis or evaluation scripts.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tracer.jl#L212-L217" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.loop_pipeline!-Tuple{Vector{Agent}, String}' href='#NimbleAgents.loop_pipeline!-Tuple{Vector{Agent}, String}'><span class="jlbinding">NimbleAgents.loop_pipeline!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
loop_pipeline!(agents, input; stop_when, max_rounds, session, verbose) -> Any
```


Run `agents` in round-robin order, feeding each agent&#39;s output as the next agent&#39;s input, until `stop_when` returns `true` or `max_rounds` is reached.

Each &quot;round&quot; consists of one pass through all agents in order. After every individual agent run, `stop_when(agent, result)` is checked — if it returns `true`, the loop ends immediately and that result is returned.

**Arguments**
- `agents::Vector{Agent}`: Agents to cycle through in order.
  
- `input::String`: The initial user message.
  
- `stop_when`: A function `(agent, result) -> Bool` that signals termination. Default: always `false` (loop runs until `max_rounds`).
  
- `max_rounds::Int`: Safety cap on the number of full rounds (default `5`).
  
- `session`: Optional shared `Session` across all agents.
  
- `verbose::Bool`: Print round/agent transitions (default `true`).
  

**Example**

```julia
coder    = Agent(name="Coder",    instructions="Write code based on the task.")
reviewer = Agent(name="Reviewer", instructions="Review code. Say APPROVED if good.")

result = loop_pipeline!(
    [coder, reviewer],
    "Write a fibonacci function";
    max_rounds = 5,
    stop_when  = (agent, result) -> occursin("APPROVED", string(result)),
    session    = Session(),
)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L273-L305" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.print_eval-Tuple{EvalReport}' href='#NimbleAgents.print_eval-Tuple{EvalReport}'><span class="jlbinding">NimbleAgents.print_eval</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
print_eval(report; io=stdout)
```


Print a human-readable summary of an `EvalReport`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L323-L327" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.print_trace-Tuple{Trace}' href='#NimbleAgents.print_trace-Tuple{Trace}'><span class="jlbinding">NimbleAgents.print_trace</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
print_trace(trace; io=stdout)
```


Print a human-readable summary of a `Trace` to `io`.

```julia
━━━ Trace ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Turns      : 2
  Agents     : MathBot
  Duration   : 3.42s
  LLM calls  : 3
  Tool calls : 2
  Tokens     : 312 in / 88 out / 400 total

  Turn 1 — MathBot  [1.8s | 2 llm | 1 tool | 210 tok]
    input  : What is 2 + 2?
    output : The answer is 4.
    tools  : add(x=2, y=2) → 4

  Turn 2 — MathBot  [1.6s | 1 llm | 1 tool | 190 tok]
    input  : Now multiply by 3.
    output : The result is 12.
    tools  : multiply(x=4, y=3) → 12
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tracer.jl#L90-L115" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.register_artifact!-Tuple{Session, String}' href='#NimbleAgents.register_artifact!-Tuple{Session, String}'><span class="jlbinding">NimbleAgents.register_artifact!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
register_artifact!(session, path; name, store) -> Artifact
```


Register a file as an artifact in the session. If `store` is provided, the file is copied into the artifact store directory; otherwise the original path is recorded as-is.

Called automatically by `run!` for `return_artifact=true` tools, by `eval_julia_tool` for saved plots, and by `save_artifact_tool`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L152-L161" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.remove_model_pricing!-Tuple{String}' href='#NimbleAgents.remove_model_pricing!-Tuple{String}'><span class="jlbinding">NimbleAgents.remove_model_pricing!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
remove_model_pricing!(model)
```


Remove a previously registered pricing entry.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L206-L210" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.remove_rate_limit!-Tuple{String}' href='#NimbleAgents.remove_rate_limit!-Tuple{String}'><span class="jlbinding">NimbleAgents.remove_rate_limit!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
remove_rate_limit!(model::String)
remove_rate_limit!(::Symbol)
```


Remove a previously set rate limit.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/rate_limit.jl#L109-L114" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.reset!-Tuple{Session}' href='#NimbleAgents.reset!-Tuple{Session}'><span class="jlbinding">NimbleAgents.reset!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
reset!(session)
```


Clear history, state, and events from the session. Preserves id/app_name/user_id.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L137-L141" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.resume!-Tuple{Session, String}' href='#NimbleAgents.resume!-Tuple{Session, String}'><span class="jlbinding">NimbleAgents.resume!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
resume!(session, human_response)
```


Inject a human approval/rejection into `session.history` so the agent can continue after a `HumanInterrupt`. Call `run!` again after this.

```julia
try
    run!(agent, input; session=session)
catch e
    e isa HumanInterrupt || rethrow(e)
    println("Pending: ", e.message)
    response = readline()
    resume!(session, response)
    run!(agent, input; session=session)
end
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L69-L86" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.run!-Tuple{Agent, String}' href='#NimbleAgents.run!-Tuple{Agent, String}'><span class="jlbinding">NimbleAgents.run!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
run!(agent, input; session, verbose, on_token, approval_channel, approval_timeout) -> Union{String, Any}
```


Run the agent loop on `input`.
- If `agent.output_type` is `nothing` → returns a `String`.
  
- If `agent.output_type` is set → returns an instance of that type.
  

**Arguments**
- `session::Union{Session, Nothing}`: Pass a `Session` to retain conversation history, key-value state, and an event log across calls.
  
- `verbose::Bool`: Print iteration info (default `true`).
  
- `on_token::Union{Function, Nothing}`: When set, the **final** LLM response is streamed token-by-token. `on_token(token::String)` is called for each chunk as it arrives. Tool-call rounds are always blocking (streaming + tool calls are not supported by the underlying API). Pass `on_token = token -> print(token)` to stream directly to the terminal.
  
- `approval_channel::Union{Channel{String}, Nothing}`: When set alongside `should_interrupt`, the agent **pauses** mid-loop waiting for a response on this channel instead of throwing `HumanInterrupt`. Use this for non-blocking approval flows (web servers, notebooks, GUIs) where the human&#39;s response arrives asynchronously from another thread or HTTP handler. Put `"approve"` to proceed, any other string to redirect, or close the channel to abort. The agent holds all its state while waiting — no re-run needed.
  
- `approval_timeout::Float64`: Seconds to wait for a response on `approval_channel` before throwing an `ApprovalTimeout` error (default: `300.0`).
  

**Example — CLI (blocking, throw-based)**

```julia
run!(agent, "Write a short poem"; on_token = token -> print(token))
```


**Example — async approval (non-blocking, channel-based)**

```julia
ch   = Channel{String}(1)
task = Threads.@spawn run!(agent, input; session=session, approval_channel=ch)
# agent is paused waiting for approval — this thread is free
put!(ch, "approve")   # unblocks the agent from anywhere
result = fetch(task)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/agent.jl#L389-L429" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.run_eval-Tuple{Agent, Vector{EvalCase}}' href='#NimbleAgents.run_eval-Tuple{Agent, Vector{EvalCase}}'><span class="jlbinding">NimbleAgents.run_eval</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
run_eval(agent, cases; metrics, verbose, pass_threshold) -> EvalReport
```


Run an agent against a vector of `EvalCase`s, score each with the given metrics, and return an `EvalReport`.

**Arguments**
- `agent::Agent`: The agent to evaluate.
  
- `cases::Vector{EvalCase}`: Test cases.
  
- `metrics`: Vector of metric functions `(EvalCase, output, Trace) -> Float64`. Default: `[exact_match, tool_trajectory]`.
  
- `verbose::Bool`: Whether to pass `verbose=true` to `run!`. Default: `false`.
  
- `pass_threshold::Float64`: Minimum score for each metric to count as passed. Default: `1.0`.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L261-L275" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.run_pipeline!-Tuple{Agent, String}' href='#NimbleAgents.run_pipeline!-Tuple{Agent, String}'><span class="jlbinding">NimbleAgents.run_pipeline!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
run_pipeline!(agent, input; session, verbose, max_handoffs) -> Any
```


Like `run!` but with automatic handoff support.  When a tool returns a `Handoff`, the pipeline transparently re-runs with the target agent and the forwarded message.  The loop stops when the active agent returns a plain result (not a `Handoff`) or `max_handoffs` is reached.

**Arguments**
- `agent::Agent`: The starting agent.
  
- `input::String`: The initial user message.
  
- `session`: Optional shared `Session` across all agents in the pipeline.
  
- `verbose::Bool`: Print handoff transitions (default `true`).
  
- `max_handoffs::Int`: Safety cap on the number of handoffs (default `10`).
  

**Example**

```julia
result = run_pipeline!(triage_agent, "I need help with my bill";
                       session=session)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L211-L231" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.save!-Tuple{JSONSessionStore, Session}' href='#NimbleAgents.save!-Tuple{JSONSessionStore, Session}'><span class="jlbinding">NimbleAgents.save!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
save!(store::JSONSessionStore, session::Session)
```


Serialise session history, state, events, and artifacts to a JSON file. Non-serialisable state values (REPL sandbox, open handles) are silently dropped.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/artifacts.jl#L322-L327" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.save_eval-Tuple{EvalReport, String}' href='#NimbleAgents.save_eval-Tuple{EvalReport, String}'><span class="jlbinding">NimbleAgents.save_eval</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
save_eval(report, path)
```


Serialise an `EvalReport` to a JSON file.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L382-L386" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.save_trace-Tuple{Trace, String}' href='#NimbleAgents.save_trace-Tuple{Trace, String}'><span class="jlbinding">NimbleAgents.save_trace</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
save_trace(trace, path)
```


Serialise a `Trace` to a JSON file at `path`.

The JSON structure mirrors the `Trace` fields — suitable for offline analysis, feeding into an evaluation script, or archiving agent runs.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tracer.jl#L160-L167" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.serve-Tuple{Vector{<:Agent}}' href='#NimbleAgents.serve-Tuple{Vector{<:Agent}}'><span class="jlbinding">NimbleAgents.serve</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
serve(agents; port=8080, host="127.0.0.1", store=InMemorySessionStore())
```


Start the NimbleAgents web UI server.

Registers `agents` by name and serves a local browser UI at `http://$host:$port`. Press Ctrl+C to stop.

Pass a `store` to persist sessions across server restarts:

```julia
serve([agent]; store=JSONSessionStore(".nimble/sessions"))
```


::: tip Multiple threads required

The server spawns agent runs in background threads. Start Julia with at least 2 threads:

```
julia --project=. -t 4 examples/web/web_ui.jl
```


:::

**Example**

```julia
using NimbleAgents

agent = Agent(
    name         = "MyBot",
    instructions = "You are a helpful assistant.",
    model        = "gpt-5.4-mini",
)

serve([agent]; port=8080)
# With persistence:
serve([agent]; port=8080, store=JSONSessionStore(".nimble/sessions"))
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/web/server.jl#L411-L446" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.set_model_pricing!-Tuple{String, Real, Real}' href='#NimbleAgents.set_model_pricing!-Tuple{String, Real, Real}'><span class="jlbinding">NimbleAgents.set_model_pricing!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
set_model_pricing!(model, input_per_million, output_per_million)
```


Register USD pricing for a model.

`input_per_million` and `output_per_million` are the cost per 1 million tokens.

**Example**

```julia
set_model_pricing!("gpt-5.4-mini", 0.40, 1.60)
set_model_pricing!("claude-sonnet-4-6", 3.00, 15.00)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/session.jl#L175-L187" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.set_rate_limit!-Tuple{String, Real}' href='#NimbleAgents.set_rate_limit!-Tuple{String, Real}'><span class="jlbinding">NimbleAgents.set_rate_limit!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
set_rate_limit!(model::String, requests_per_second::Real)
set_rate_limit!(::Symbol, requests_per_second::Real)
```


Set a rate limit for a specific model (e.g. `"gpt-5.4-mini"`) or for all models (`:default`). The limiter allows up to `requests_per_second` LLM calls per second with short bursts up to that same number.

**Example**

```julia
# Limit gpt-5.4-mini to 10 requests/second
set_rate_limit!("gpt-5.4-mini", 10)

# Limit all models to 20 requests/second (unless overridden per-model)
set_rate_limit!(:default, 20)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/rate_limit.jl#L79-L95" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.spawn_subagents-Tuple{Vector{<:Tuple{Agent, String}}}' href='#NimbleAgents.spawn_subagents-Tuple{Vector{<:Tuple{Agent, String}}}'><span class="jlbinding">NimbleAgents.spawn_subagents</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
spawn_subagents(pairs; parallel, session, verbose) -> Vector{Any}
```


Run a list of `(agent, input)` pairs and return their results in the same order.
- `parallel = false` (default): executes each pair serially.
  
- `parallel = true`: spawns each pair concurrently on the Julia thread pool; result order is preserved.
  
- Each run shares the same `session` if provided; concurrent writes are protected by `session.lock`.
  

**Example — serial**

```julia
results = spawn_subagents([
    (researcher_agent, "Find facts about X"),
    (analyst_agent,    "Analyse the market for X"),
    (writer_agent,     "Draft an intro for X"),
])
draft = run!(editor_agent, join(results, "\n\n"))
```


**Example — parallel**

```julia
results = spawn_subagents([
    (researcher_agent, "Topic A"),
    (researcher_agent, "Topic B"),
]; parallel = true, session = session)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/handoff.jl#L395-L423" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.tool_coverage-Tuple{EvalCase, Any, Any}' href='#NimbleAgents.tool_coverage-Tuple{EvalCase, Any, Any}'><span class="jlbinding">NimbleAgents.tool_coverage</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
tool_coverage(case, output, trace) -> Float64
```


Returns the fraction of `case.expected_tools` that were actually called (order-insensitive). Returns 1.0 if `case.expected_tools` is `nothing`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L215-L220" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.tool_trajectory-Tuple{EvalCase, Any, Any}' href='#NimbleAgents.tool_trajectory-Tuple{EvalCase, Any, Any}'><span class="jlbinding">NimbleAgents.tool_trajectory</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
tool_trajectory(case, output, trace) -> Float64
```


Returns 1.0 if the tool names called (in order) match `case.expected_tools` exactly. Returns 1.0 if `case.expected_tools` is `nothing`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/eval.jl#L197-L202" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.tools_schema-Tuple{Vector{<:AbstractTool}}' href='#NimbleAgents.tools_schema-Tuple{Vector{<:AbstractTool}}'><span class="jlbinding">NimbleAgents.tools_schema</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
tools_schema(tools) -> Vector{Dict}
```


Render a vector of `Tool`s into the JSON-serialisable list that OpenAI-compatible APIs expect under the `tools` key.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tools.jl#L194-L199" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NimbleAgents.@tool-Tuple' href='#NimbleAgents.@tool-Tuple'><span class="jlbinding">NimbleAgents.@tool</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@tool [return_direct=true] function f(args...) ... end
```


Define a Julia function and automatically register it as a `NimbleTool` (with name, description, and JSON parameter schema inferred from the function signature and its docstring).

A variable `<funcname>_tool` is created in the calling scope holding the resulting `NimbleTool` object.

When `return_direct=true`, the agent loop short-circuits immediately after this tool executes — its return value becomes the agent&#39;s final output without any further LLM call. Useful for lookup tools, cache hits, or any tool whose result is already the definitive answer.

**Example — standard tool**

```julia
@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end
```


**Example — return_direct tool**

```julia
@tool return_direct=true function lookup_faq(question::String)
    "Look up a frequently asked question. Returns a definitive answer."
    faq_db[question]
end
# When the agent calls lookup_faq, its result is returned immediately —
# no follow-up LLM call is made.
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/whanyu1212/NimbleAgents.jl/blob/290c7b1eb4e7cccf2d2660e02c6ed2359d4ace53/src/tools.jl#L69-L101" target="_blank" rel="noreferrer">source</a></Badge>

</details>

