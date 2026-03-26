###############################################################################
# artifacts.jl — Artifact tracking and session persistence
#
# Artifacts are named, typed outputs an agent intentionally produces:
# files, plots, structured data, reports. Two registration mechanisms:
#
#   1. return_artifact=true on a tool (developer intent)
#   2. save_artifact_tool (agent/LLM intent)
#
# Sessions serialise to JSON via JSONSessionStore (pluggable).
###############################################################################

using JSON3: JSON3

include("artifacts/types.jl")
include("artifacts/store_interface.jl")
include("artifacts/in_memory_store.jl")
include("artifacts/register.jl")
include("artifacts/json_serialization.jl")
include("artifacts/json_store.jl")
