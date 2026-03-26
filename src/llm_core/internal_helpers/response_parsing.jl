###############################################################################
# llm_core/internal_helpers/response_parsing.jl — provider response extraction
###############################################################################

function _parse_usage(obj)::TokenUsage
    input = _maybe_int(get(obj, :prompt_tokens, get(obj, :input_tokens, nothing)))
    output = _maybe_int(get(obj, :completion_tokens, get(obj, :output_tokens, nothing)))
    prompt_details = get(obj, :prompt_tokens_details, nothing)
    cache_read = if !isnothing(prompt_details)
        _maybe_int(get(prompt_details, :cached_tokens, nothing))
    else
        nothing
    end
    TokenUsage(; input_tokens=input, output_tokens=output, cache_read_tokens=cache_read)
end

_usage_tokens(::Nothing) = (0, 0)
function _usage_tokens(usage::TokenUsage)
    (something(usage.input_tokens, 0), something(usage.output_tokens, 0))
end

function _message_extras(message)
    extras = Dict{Symbol,Any}()
    for key in (:refusal, :reasoning, :reasoning_content)
        haskey(message, key) && (extras[key] = _to_plain(get(message, key, nothing)))
    end
    extras
end

function _extract_message_content(message)
    if haskey(message, :content)
        return _flatten_content(message[:content])
    elseif haskey(message, :refusal)
        return _flatten_content(message[:refusal])
    else
        return ""
    end
end

_render_content(content) = isnothing(content) ? "" : content

function _flatten_content(content)
    content isa AbstractString && return String(content)
    content isa JSON3.Array && return _flatten_content(collect(content))
    content isa AbstractVector || return content

    parts = String[]
    for item in content
        if item isa AbstractString
            push!(parts, String(item))
        elseif item isa AbstractDict || item isa JSON3.Object
            plain = _to_plain(item)
            if haskey(plain, "text")
                push!(parts, string(plain["text"]))
            elseif haskey(plain, :text)
                push!(parts, string(plain[:text]))
            end
        end
    end
    join(parts)
end

function _extract_delta_text(delta)
    if haskey(delta, :content)
        return _flatten_content(delta[:content])
    end
    ""
end

function _parse_tool_args(raw_args)
    raw_args isa AbstractDict && return _symbol_dict(raw_args)
    raw_args isa JSON3.Object && return _symbol_dict(_to_plain(raw_args))
    raw_args isa AbstractString || return Dict{Symbol,Any}()
    isempty(strip(raw_args)) && return Dict{Symbol,Any}()
    parsed = JSON3.read(raw_args)
    _symbol_dict(_to_plain(parsed))
end

function _parse_chat_response(resp, elapsed::Real)
    usage = haskey(resp, :usage) ? _parse_usage(resp[:usage]) : nothing
    tokens = _usage_tokens(usage)
    choices = haskey(resp, :choices) ? resp[:choices] : nothing
    isnothing(choices) && throw(ErrorException("Malformed LLM response: missing choices"))
    isempty(choices) && throw(ErrorException("Malformed LLM response: empty choices"))
    message = choices[1][:message]
    extras = _message_extras(message)

    if haskey(message, :tool_calls) && !isempty(message[:tool_calls])
        tool_calls = ToolMessage[]
        for tc in message[:tool_calls]
            fn = tc[:function]
            args = _parse_tool_args(get(fn, :arguments, "{}"))
            push!(
                tool_calls,
                ToolMessage(;
                    content=nothing,
                    raw=get(fn, :arguments, ""),
                    tool_call_id=get(tc, :id, ""),
                    name=get(fn, :name, ""),
                    args=args,
                ),
            )
        end
        return AIToolRequest(;
            tool_calls,
            content=_extract_message_content(message),
            usage,
            tokens,
            elapsed,
            extras,
        )
    end

    AIMessage(; content=_extract_message_content(message), usage, tokens, elapsed, extras)
end
