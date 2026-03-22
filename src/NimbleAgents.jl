module NimbleAgents

include("tools.jl")
include("cli_tools.jl")
include("external_agent.jl")
include("session.jl")
include("storage/artifacts.jl")
include("storage/memory.jl")
include("skills.jl")
include("mcp.jl")
include("guardrails.jl")
include("rate_limit.jl")
include("agent.jl")
include("tracer.jl")
include("eval.jl")
include("handoff.jl")
include("storage/sqlite_store.jl")
include("storage/sqlite_memory.jl")
include("builtins/builtins.jl")
include("gemini.jl")
include("repl.jl")
include("web/server.jl")

export @tool, Tool, NimbleTool, AbstractTool, ToolMessage
export build_tool_map, tools_schema, dispatch_tool
export CLITool, CLIArg
export ExternalAgentTool, claude_code_tool, codex_tool
export Session, TurnEvent, ToolEvent, reset!
export Skill, discover_skills
export Guardrail, Pass, Block, Modify
export Agent, AgentHooks, RetryConfig, ContextConfig, run!
export RateLimiter, set_rate_limit!, remove_rate_limit!
export set_model_pricing!, get_model_pricing, remove_model_pricing!
export compact!
export Trace, print_trace, save_trace, load_trace
export EvalCase, EvalResult, EvalReport
export exact_match, fuzzy_match, tool_trajectory, tool_coverage
export cost_budget, latency_budget
export run_eval, print_eval, save_eval, load_eval
export HumanInterrupt, ApprovalTimeout, resume!
export Handoff, HandoffFilter, handoff_tool, agent_as_tool, run_pipeline!, loop_pipeline!
export fan_out, spawn_subagents
export serve
# MCP
export MCPServer, MCPClient, MCPHTTPClient, connect!, list_tools, close!
# Artifacts and persistence
export Artifact, register_artifact!
export AbstractSessionStore, InMemorySessionStore, JSONSessionStore, SQLiteSessionStore
export save!, load, list, store_artifacts_dir
# Memory
export AbstractMemoryService, InMemoryMemoryService, SQLiteMemoryService, MemoryEntry
export add_memory!, search_memory, delete_memory!, list_memories
# Built-in tools
export read_file_tool, write_file_tool, edit_file_tool
export list_dir_tool, glob_tool, delete_file_tool
export grep_tool, find_files_tool
export bash_tool
export http_get_tool, http_post_tool, fetch_webpage_tool, github_trending_tool
export eval_julia_tool
export save_artifact_tool
export save_memory_tool, recall_memory_tool
# Gemini
export GeminiOpenAISchema
# REPL
export chat!

function __init__()
    _register_gemini_models!()
end

end
