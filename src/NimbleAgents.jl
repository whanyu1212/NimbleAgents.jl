module NimbleAgents

include("tools.jl")
include("cli_tools.jl")
include("session.jl")
include("artifacts.jl")
include("skills.jl")
include("mcp.jl")
include("agent.jl")
include("handoff.jl")
include("builtins/builtins.jl")
include("web/server.jl")

export @tool, Tool, NimbleTool, AbstractTool, ToolMessage
export build_tool_map, tools_schema, dispatch_tool
export CLITool, CLIArg
export Session, TurnEvent, ToolEvent, reset!
export Skill, discover_skills
export Agent, AgentHooks, RetryConfig, ContextConfig, run!
export compact!
export HumanInterrupt, ApprovalTimeout, resume!
export Handoff, handoff_tool, agent_as_tool, run_pipeline!
export fan_out, spawn_subagents
export serve
# MCP
export MCPServer, MCPClient, connect!, list_tools, close!
# Artifacts and persistence
export Artifact, register_artifact!
export AbstractSessionStore, InMemorySessionStore, JSONSessionStore
export save!, load, list, store_artifacts_dir
# Built-in tools
export read_file_tool, write_file_tool, edit_file_tool
export list_dir_tool, glob_tool, delete_file_tool
export grep_tool, find_files_tool
export bash_tool
export http_get_tool, http_post_tool
export eval_julia_tool
export save_artifact_tool

end
