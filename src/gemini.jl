###############################################################################
# gemini.jl — Gemini API support via OpenAI-compatible endpoint
#
# PromptingTools.jl (v0.91.0) has a GoogleOpenAISchema that inherits from
# AbstractOpenAISchema, which means aitools/aiextract/aigenerate should work.
# However, it has two bugs that prevent actual use:
#
#   1. Wrong base URL: PT uses `https://generativelanguage.googleapis.com/v1beta`
#      but the OpenAI-compatible endpoint lives at `.../v1beta/openai/`.
#      See: https://ai.google.dev/gemini-api/docs/openai
#
#   2. No streaming support: PT's GoogleOpenAISchema.create_chat does not accept
#      or forward the `streamcallback` parameter, so streaming always fails.
#
# This file defines `GeminiOpenAISchema` — a minimal subclass that fixes both
# issues by overriding `OpenAI.create_chat` with the correct URL and streaming
# support. Everything else (message rendering, response parsing, tool calling,
# structured output) is inherited from PT's AbstractOpenAISchema machinery.
#
# Usage:
#   agent = Agent(name="Bot", model="gemini-2.5-flash", instructions="...")
#   # GeminiOpenAISchema is selected automatically for "gemini-*" models
#
# Thinking/reasoning:
#   agent = Agent(model="gemini-2.5-flash", api_kwargs=(; reasoning_effort="high"), ...)
#
# TODO: Open a PromptingTools.jl issue to fix GoogleOpenAISchema upstream.
#       Once fixed, this file can be removed and users can use PT's schema directly.
###############################################################################

import PromptingTools as PT

const _GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai"

"""
    GeminiOpenAISchema <: PT.AbstractOpenAISchema

Schema for calling the Gemini API via Google's OpenAI-compatible endpoint.

Fixes two bugs in PromptingTools.jl's built-in `GoogleOpenAISchema`:
1. Uses the correct base URL (`/v1beta/openai/` instead of `/v1beta/`)
2. Supports streaming via `streamcallback`

Inherits all message rendering, tool calling, structured output, and response
parsing from PT's `AbstractOpenAISchema`.

# Supported features (via OpenAI compatibility)
- Chat completions (`aigenerate`)
- Tool/function calling (`aitools`)
- Structured output (`aiextract`)
- Streaming
- Thinking/reasoning (`reasoning_effort` parameter)
- Image input (base64 via `image_url`)

# Example
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
"""
struct GeminiOpenAISchema <: PT.AbstractOpenAISchema end

function PT.OpenAI.create_chat(
    ::GeminiOpenAISchema,
    api_key::AbstractString,
    model::AbstractString,
    conversation;
    http_kwargs::NamedTuple=NamedTuple(),
    streamcallback::Any=nothing,
    url::String=_GEMINI_BASE_URL,
    kwargs...,
)
    api_key = !isempty(api_key) ? api_key : PT.GOOGLE_API_KEY
    provider = PT.GoogleProvider(; api_key, base_url=url)
    if !isnothing(streamcallback)
        full_url = PT.OpenAI.build_url(provider, "chat/completions")
        headers = PT.OpenAI.auth_header(provider, api_key)
        streamcallback, new_kwargs = PT.configure_callback!(
            streamcallback, GeminiOpenAISchema(); kwargs...
        )
        input = PT.OpenAI.build_params((; messages=conversation, model, new_kwargs...))
        resp = PT.streamed_request!(
            streamcallback, full_url, headers, input; http_kwargs...
        )
        PT.OpenAI.OpenAIResponse(resp.status, JSON3.read(resp.body))
    else
        PT.OpenAI.openai_request(
            "chat/completions",
            provider;
            method="POST",
            messages=conversation,
            model=model,
            http_kwargs,
            kwargs...,
        )
    end
end

# ── Model registry ───────────────────────────────────────────────────────────

# Register Gemini models so PT routes them through GeminiOpenAISchema.
# This is called once at module load time.
function _register_gemini_models!()
    models = [
        # Gemini 3.x
        "gemini-3-pro-preview",
        "gemini-3-flash-preview",
        "gemini-3.1-pro-preview",
        "gemini-3.1-flash-lite-preview",
        # Gemini 2.5
        "gemini-2.5-pro",
        "gemini-2.5-pro-preview-05-06",
        "gemini-2.5-flash",
        "gemini-2.5-flash-preview-05-20",
        "gemini-2.5-flash-lite",
        # Gemini 2.0 (gemini-2.0-flash deprecated for new users as of March 2026)
        "gemini-2.0-flash-lite",
        # Gemini 1.5
        "gemini-1.5-pro",
        "gemini-1.5-pro-latest",
        "gemini-1.5-flash",
        "gemini-1.5-flash-latest",
    ]
    schema = GeminiOpenAISchema()
    for model in models
        PT.MODEL_REGISTRY[model] = PT.ModelSpec(;
            name=model, schema=schema, description="Google"
        )
    end
end
# Registration is called from NimbleAgents.__init__() so it runs after
# PT's own model registration and overwrites the broken GoogleOpenAISchema entries.
