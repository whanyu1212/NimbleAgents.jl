###############################################################################
# llm_core/model_schema_types.jl — prompt schema and model metadata types
###############################################################################

abstract type AbstractPromptSchema end
abstract type AbstractOpenAISchema <: AbstractPromptSchema end

struct OpenAISchema <: AbstractOpenAISchema end
struct ModelSpec
    name::String
    schema::AbstractPromptSchema
    description::String
end

const MODEL_REGISTRY = Dict{String,ModelSpec}()

struct StreamCallback
    out::Any
end
