###############################################################################
# llm_core/message_types.jl — core message and tool types
###############################################################################

abstract type AbstractMessage end

Base.@kwdef struct TokenUsage
    input_tokens::Union{Int,Nothing} = nothing
    output_tokens::Union{Int,Nothing} = nothing
    cache_read_tokens::Union{Int,Nothing} = nothing
    cache_write_tokens::Union{Int,Nothing} = nothing
    cost::Union{Float64,Nothing} = nothing
end

mutable struct SystemMessage <: AbstractMessage
    content::Any
end

mutable struct UserMessage <: AbstractMessage
    content::Any
end

mutable struct AIMessage <: AbstractMessage
    content::Any
    usage::Union{TokenUsage,Nothing}
    tokens::Tuple{Int,Int}
    elapsed::Float64
    extras::Dict{Symbol,Any}
end

function AIMessage(
    content::Any;
    usage::Union{TokenUsage,Nothing}=nothing,
    tokens::Tuple{Int,Int}=(0, 0),
    elapsed::Real=0.0,
    extras::AbstractDict{Symbol,<:Any}=Dict{Symbol,Any}(),
)
    AIMessage(content, usage, tokens, Float64(elapsed), Dict{Symbol,Any}(extras))
end

function AIMessage(;
    content::Any=nothing,
    usage::Union{TokenUsage,Nothing}=nothing,
    tokens::Tuple{Int,Int}=(0, 0),
    elapsed::Real=0.0,
    extras::AbstractDict{Symbol,<:Any}=Dict{Symbol,Any}(),
)
    AIMessage(content; usage=usage, tokens=tokens, elapsed=elapsed, extras=extras)
end

"""
    ToolMessage(; content=nothing, raw="", tool_call_id="", name="", args=nothing)

Represents a tool result message in conversation history.
"""
mutable struct ToolMessage <: AbstractMessage
    content::Any
    raw::Any
    tool_call_id::String
    name::String
    args::Union{Dict{Symbol,Any},Nothing}
end

function ToolMessage(;
    content::Any=nothing,
    raw::Any="",
    tool_call_id::AbstractString="",
    name::AbstractString="",
    args::Union{Nothing,AbstractDict{Symbol,<:Any}}=nothing,
)
    ToolMessage(
        content,
        raw,
        String(tool_call_id),
        String(name),
        isnothing(args) ? nothing : Dict{Symbol,Any}(args),
    )
end

mutable struct AIToolRequest <: AbstractMessage
    tool_calls::Vector{ToolMessage}
    content::Any
    usage::Union{TokenUsage,Nothing}
    tokens::Tuple{Int,Int}
    elapsed::Float64
    extras::Dict{Symbol,Any}
end

function AIToolRequest(;
    tool_calls::Vector{ToolMessage}=ToolMessage[],
    content::Any=nothing,
    usage::Union{TokenUsage,Nothing}=nothing,
    tokens::Tuple{Int,Int}=(0, 0),
    elapsed::Real=0.0,
    extras::AbstractDict{Symbol,<:Any}=Dict{Symbol,Any}(),
)
    AIToolRequest(
        tool_calls, content, usage, tokens, Float64(elapsed), Dict{Symbol,Any}(extras)
    )
end

ToolCall(; id::AbstractString="", name::AbstractString, args=Dict{Symbol,Any}()) = ToolMessage(
    ; content=nothing, raw="", tool_call_id=String(id), name=String(name), args=_symbol_dict(args)
)

"""
    AbstractTool

Abstract supertype for all tool definitions that can be exposed to the model.
"""
abstract type AbstractTool end

struct ToolNotFoundError <: Exception
    message::String
end
Base.showerror(io::IO, e::ToolNotFoundError) = print(io, e.message)
