###############################################################################
# llm_core.jl — NimbleAgents-owned LLM/message/tool substrate
###############################################################################

using HTTP: HTTP
using JSON3: JSON3

const _OPENAI_BASE_URL = "https://api.openai.com/v1"
const _GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai"

include("llm_core/message_types.jl")
include("llm_core/model_schema_types.jl")
include("llm_core/overrides.jl")
include("llm_core/render.jl")
include("llm_core/schema_helpers.jl")
include("llm_core/api_wrappers.jl")
include("llm_core/internal_helpers.jl")
