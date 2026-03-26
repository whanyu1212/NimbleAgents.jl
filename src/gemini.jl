###############################################################################
# gemini.jl — Gemini model registry helpers
###############################################################################

"""
    GeminiOpenAISchema <: AbstractOpenAISchema

Marker schema used for Gemini models routed through Google's OpenAI-compatible
chat completions endpoint.
"""
struct GeminiOpenAISchema <: AbstractOpenAISchema end

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
        # Gemini 2.0
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        # Gemini 1.5
        "gemini-1.5-pro",
        "gemini-1.5-pro-latest",
        "gemini-1.5-flash",
        "gemini-1.5-flash-latest",
    ]

    schema = GeminiOpenAISchema()
    for model in models
        MODEL_REGISTRY[model] = ModelSpec(model, schema, "Google")
    end
end
