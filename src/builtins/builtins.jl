###############################################################################
# builtins/builtins.jl — aggregates all built-in tools
#
# Each tool is a module-level const NimbleTool bound to a <name>_tool variable,
# mirroring the convention set by @tool.
#
# Import what you need:
#
#   using NimbleAgents
#
#   agent = Agent(
#       tools = [read_file_tool, write_file_tool, bash_tool, grep_tool],
#   )
###############################################################################

include("filesystem.jl")    # read_file_tool, write_file_tool, edit_file_tool,
                            # list_dir_tool, glob_tool, delete_file_tool
include("search.jl")        # grep_tool, find_files_tool
include("shell.jl")         # bash_tool
include("http.jl")          # http_get_tool, http_post_tool
include("repl.jl")          # eval_julia_tool
include("save_artifact.jl") # save_artifact_tool
include("memory_tools.jl") # save_memory_tool, recall_memory_tool
