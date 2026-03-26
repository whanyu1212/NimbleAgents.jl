```@raw html
---
outline: deep
---
```

```@meta
CurrentModule = NimbleAgents
```

# Reference

This reference is organized by exported API surface. Every exported symbol is
listed explicitly below for predictable coverage and navigation.

```@index
```

## Module

```@docs
NimbleAgents
```

## Core Types and Runtime

```@docs
@tool
AbstractTool
Tool
NimbleTool
ToolMessage
build_tool_map
tools_schema
dispatch_tool
Agent
AgentHooks
RetryConfig
ContextConfig
run!
HumanInterrupt
ApprovalTimeout
resume!
```

## Guardrails and Rate Limits

```@docs
Guardrail
Pass
Block
Modify
RateLimiter
set_rate_limit!
remove_rate_limit!
```

## Pricing and Cost

```@docs
set_model_pricing!
get_model_pricing
remove_model_pricing!
compact!
```

## Sessions and Persistence

```@docs
Session
TurnEvent
ToolEvent
reset!
Artifact
register_artifact!
AbstractSessionStore
InMemorySessionStore
JSONSessionStore
SQLiteSessionStore
save!
load
list
store_artifacts_dir
cleanup!
```

## Memory

```@docs
AbstractMemoryService
InMemoryMemoryService
SQLiteMemoryService
MemoryEntry
add_memory!
search_memory
delete_memory!
list_memories
```

## Skills

```@docs
Skill
discover_skills
```

## Multi-Agent and Handoffs

```@docs
Handoff
HandoffFilter
handoff_tool
agent_as_tool
run_pipeline!
loop_pipeline!
fan_out
spawn_subagents
```

## Tracing and Evaluation

```@docs
Trace
print_trace
save_trace
load_trace
EvalCase
EvalResult
EvalReport
exact_match
fuzzy_match
tool_trajectory
tool_coverage
cost_budget
latency_budget
run_eval
print_eval
save_eval
load_eval
```

## MCP and Server

```@docs
MCPServer
MCPClient
MCPHTTPClient
connect!
list_tools
close!
serve
chat!
```

## External and CLI Tools

```@docs
CLITool
CLIArg
ExternalAgentTool
claude_code_tool
codex_tool
```

## Built-In Tools

```@docs
read_file_tool
write_file_tool
edit_file_tool
list_dir_tool
glob_tool
delete_file_tool
grep_tool
find_files_tool
bash_tool
http_get_tool
http_post_tool
fetch_webpage_tool
github_trending_tool
eval_julia_tool
save_artifact_tool
save_memory_tool
recall_memory_tool
```

## Provider Schema Marker

```@docs
GeminiOpenAISchema
```

