###############################################################################
# llm_core/api_wrappers.jl — public LLM wrapper APIs and test override hooks
###############################################################################

function aitools(
    conversation;
    tools::Vector{<:AbstractTool}=AbstractTool[],
    model::AbstractString,
    return_all::Bool=false,
    verbose::Bool=false,
    streamcallback::Any=nothing,
    tool_choice=nothing,
    cache=nothing,
    kwargs...,
)
    messages = _as_conversation(conversation)
    response = _chat_completion(
        messages;
        tools=tools,
        model=String(model),
        streamcallback=streamcallback,
        tool_choice=tool_choice,
        cache=cache,
        kwargs...,
    )
    return_all ? vcat(copy(messages), [response]) : response
end

function _run_aitools(conversation; kwargs...)
    override = _AITOOLS_OVERRIDE[]
    if isnothing(override)
        return aitools(conversation; kwargs...)
    end
    override(conversation; kwargs...)
end

function aigenerate(
    conversation;
    model::AbstractString,
    return_all::Bool=false,
    verbose::Bool=false,
    streamcallback::Any=nothing,
    cache=nothing,
    kwargs...,
)
    messages = _as_conversation(conversation)
    response = _chat_completion(
        messages;
        tools=AbstractTool[],
        model=String(model),
        streamcallback=streamcallback,
        cache=cache,
        kwargs...,
    )
    return_all ? vcat(copy(messages), [response]) : response
end

function _run_aigenerate(conversation; kwargs...)
    override = _AIGENERATE_OVERRIDE[]
    if isnothing(override)
        return aigenerate(conversation; kwargs...)
    end
    override(conversation; kwargs...)
end

function aiextract(
    conversation;
    return_type::Type,
    model::AbstractString,
    verbose::Bool=false,
    cache=nothing,
    kwargs...,
)
    schema = _to_json_schema(return_type)
    tool = BasicTool(
        ;
        name="__structured_output__",
        parameters=schema,
        description="Return the final response in the required structured format.",
        callable=identity,
    )
    response = _run_aitools(
        conversation;
        tools=[tool],
        model=String(model),
        tool_choice=Dict{String,Any}(
            "type" => "function",
            "function" => Dict{String,Any}("name" => tool.name),
        ),
        cache=cache,
        kwargs...,
    )

    if response isa AIToolRequest && !isempty(response.tool_calls)
        parsed = _coerce_value(return_type, something(response.tool_calls[1].args, Dict{Symbol,Any}()))
        return AIMessage(
            ;
            content=parsed,
            usage=response.usage,
            tokens=response.tokens,
            elapsed=response.elapsed,
            extras=response.extras,
        )
    elseif response isa AIMessage
        parsed = _parse_structured_fallback(return_type, response.content)
        return AIMessage(
            ;
            content=parsed,
            usage=response.usage,
            tokens=response.tokens,
            elapsed=response.elapsed,
            extras=response.extras,
        )
    end

    AIMessage(; content=nothing)
end

function _run_aiextract(conversation; kwargs...)
    override = _AIEXTRACT_OVERRIDE[]
    if isnothing(override)
        return aiextract(conversation; kwargs...)
    end
    override(conversation; kwargs...)
end

# Internal helper tool used by `aiextract` structured-output enforcement.
struct BasicTool <: AbstractTool
    name::String
    parameters::Dict{String,Any}
    description::Union{String,Nothing}
    callable::Any
    strict::Union{Bool,Nothing}
end

function BasicTool(; name, parameters, description=nothing, callable, strict=nothing)
    BasicTool(String(name), Dict{String,Any}(parameters), description, callable, strict)
end
