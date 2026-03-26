###############################################################################
# web/server.jl — NimbleAgents local web UI
#
# Prototype: lives in NimbleAgents.jl for now, will migrate to
# NimbleAgentsWeb.jl once the package is published.
###############################################################################

using HTTP: HTTP
using JSON3: JSON3
import UUIDs: uuid4

include("server/state.jl")
include("server/sse.jl")
include("server/hooks.jl")
include("server/handlers.jl")
include("server/router.jl")
include("server/serve.jl")
