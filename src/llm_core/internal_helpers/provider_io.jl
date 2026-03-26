###############################################################################
# llm_core/internal_helpers/provider_io.jl — request building and provider I/O
###############################################################################

function _provider_config(model::String)
    if startswith(model, "gemini-")
        api_key = get(ENV, "GOOGLE_API_KEY", "")
        isempty(api_key) && error("GOOGLE_API_KEY is not set")
        return (base_url=_GEMINI_BASE_URL, api_key=api_key, provider=:gemini)
    elseif startswith(model, "claude")
        error("Anthropic models are not supported in this build: $(model)")
    else
        api_key = get(ENV, "OPENAI_API_KEY", "")
        isempty(api_key) && error("OPENAI_API_KEY is not set")
        return (base_url=_OPENAI_BASE_URL, api_key=api_key, provider=:openai)
    end
end

function _schema_for_model(model::String)
    startswith(model, "gemini-") ? GeminiOpenAISchema() : OpenAISchema()
end

function _merge_request_kwargs!(body::Dict{String,Any}, kwargs)
    for (key, value) in kwargs
        key in (:cache, :return_all, :verbose) && continue
        body[string(key)] = _json_safe(value)
    end
    nothing
end

function _post_json(url::String, api_key::String, body::Dict{String,Any})
    headers = ["Authorization" => "Bearer $(api_key)", "Content-Type" => "application/json"]
    payload = JSON3.write(body)
    t0 = time()
    resp = HTTP.request("POST", url, headers, payload; status_exception=false)
    elapsed = time() - t0
    if resp.status >= 300
        throw(ErrorException("HTTP $(resp.status): $(String(resp.body))"))
    end
    JSON3.read(resp.body), elapsed
end

function _emit_stream_token(extras, token::String)
    cb = get(extras, :streamcallback, nothing)
    isnothing(cb) && return nothing
    if cb isa StreamCallback
        out = cb.out
        if out isa Channel
            put!(out, token)
        elseif out isa Function
            out(token)
        elseif out isa IO
            write(out, token)
        end
    end
    nothing
end

function _process_sse_event!(data_lines, content::IOBuffer, usage, extras)
    isempty(data_lines) && return usage
    payload = join(data_lines, "\n")
    payload == "[DONE]" && return usage
    obj = JSON3.read(payload)

    if haskey(obj, :usage)
        usage = _parse_usage(obj[:usage])
    end

    if haskey(obj, :choices)
        for choice in obj[:choices]
            if haskey(choice, :delta)
                delta = choice[:delta]
                text = _extract_delta_text(delta)
                if !isempty(text)
                    write(content, text)
                    _emit_stream_token(extras, text)
                end
            end
        end
    end

    usage
end

function _chat_completion_stream(
    messages::Vector{<:AbstractMessage};
    tools::Vector{<:AbstractTool}=AbstractTool[],
    model::String,
    tool_choice=nothing,
    streamcallback::Any=nothing,
    kwargs...,
)
    cfg = _provider_config(model)
    body = Dict{String,Any}(
        "model" => model,
        "messages" => render(_schema_for_model(model), messages),
        "stream" => true,
    )
    isempty(tools) || (body["tools"] = tools_schema(tools))
    isnothing(tool_choice) || (body["tool_choice"] = tool_choice)
    body["stream_options"] = Dict{String,Any}("include_usage" => true)
    _merge_request_kwargs!(body, kwargs)

    content = IOBuffer()
    usage = nothing
    extras = Dict{Symbol,Any}()
    !isnothing(streamcallback) && (extras[:streamcallback] = streamcallback)
    t0 = time()
    headers = [
        "Authorization" => "Bearer $(cfg.api_key)",
        "Content-Type" => "application/json",
        "Accept" => "text/event-stream",
    ]

    HTTP.open("POST", cfg.base_url * "/chat/completions", headers) do http
        write(http, JSON3.write(body))
        HTTP.startread(http)
        data_lines = String[]
        while !eof(http)
            line = try
                readline(http)
            catch
                break
            end
            if isempty(line)
                usage = _process_sse_event!(data_lines, content, usage, extras)
                empty!(data_lines)
                continue
            end
            startswith(line, "data:") && push!(data_lines, strip(line[6:end]))
        end
        !isempty(data_lines) &&
            (usage = _process_sse_event!(data_lines, content, usage, extras))
    end

    tokens = _usage_tokens(usage)
    pop!(extras, :streamcallback, nothing)
    AIMessage(;
        content=String(take!(content)),
        usage=usage,
        tokens=tokens,
        elapsed=time() - t0,
        extras=extras,
    )
end

function _chat_completion(
    messages::Vector{<:AbstractMessage};
    tools::Vector{<:AbstractTool}=AbstractTool[],
    model::String,
    streamcallback::Any=nothing,
    tool_choice=nothing,
    cache=nothing,
    kwargs...,
)
    if !isnothing(streamcallback)
        return _chat_completion_stream(
            messages;
            tools=tools,
            model=model,
            tool_choice=tool_choice,
            streamcallback=streamcallback,
            kwargs...,
        )
    end

    cfg = _provider_config(model)
    body = Dict{String,Any}(
        "model" => model, "messages" => render(_schema_for_model(model), messages)
    )
    isempty(tools) || (body["tools"] = tools_schema(tools))
    isnothing(tool_choice) || (body["tool_choice"] = tool_choice)
    _merge_request_kwargs!(body, kwargs)

    resp, elapsed = _post_json(cfg.base_url * "/chat/completions", cfg.api_key, body)
    return _parse_chat_response(resp, elapsed)
end
