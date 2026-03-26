###############################################################################
# tools.jl — Tool definition and dispatch
#
# Builds on NimbleAgents' internal schema helpers so tools stay provider-agnostic.
###############################################################################

include("tools/types.jl")
include("tools/macro.jl")
include("tools/registry.jl")
include("tools/validation.jl")
