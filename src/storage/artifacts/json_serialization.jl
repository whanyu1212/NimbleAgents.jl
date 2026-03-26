###############################################################################
# storage/artifacts/json_serialization.jl — session/artifact JSON transforms
###############################################################################

# Convert a AbstractMessage to a plain Dict for JSON serialisation.
function _msg_to_dict(msg::AbstractMessage)::Dict{String,Any}
    type_name = string(nameof(typeof(msg)))
    d = Dict{String,Any}("_type" => type_name)
    # All message types have content
    d["content"] = msg.content
    # AIToolRequest has tool_calls
    if msg isa AIToolRequest && !isnothing(msg.tool_calls)
        d["tool_calls"] = map(msg.tool_calls) do tc
            Dict{String,Any}(
                "id" => tc.id,
                "name" => tc.name,
                "args" => if isnothing(tc.args)
                    Dict{String,Any}()
                else
                    Dict{String,Any}(string(k) => v for (k, v) in tc.args)
                end,
            )
        end
    end
    # ToolMessage has name and tool_call_id
    if hasproperty(msg, :name)
        d["name"] = getproperty(msg, :name)
    end
    if hasproperty(msg, :tool_call_id)
        d["tool_call_id"] = getproperty(msg, :tool_call_id)
    end
    d
end

# Reconstruct a AbstractMessage from a plain Dict.
function _dict_to_msg(d::Dict)::AbstractMessage
    type_name = get(d, "_type", "UserMessage")
    content = get(d, "content", "")
    if type_name == "UserMessage"
        UserMessage(content)
    elseif type_name == "AIMessage"
        AIMessage(content)
    elseif type_name == "SystemMessage"
        SystemMessage(content)
    elseif type_name == "AIToolRequest"
        tool_calls = map(get(d, "tool_calls", [])) do tc
            args = Dict{Symbol,Any}(Symbol(k) => v for (k, v) in tc["args"])
            ToolCall(; id=get(tc, "id", ""), name=tc["name"], args=args)
        end
        AIToolRequest(; tool_calls, content)
    elseif type_name == "ToolMessage"
        ToolMessage(;
            content=content,
            raw=something(content, ""),
            name=get(d, "name", ""),
            tool_call_id=get(d, "tool_call_id", ""),
        )
    else
        UserMessage(something(content, ""))
    end
end

# Serialise only JSON-safe state values — silently drop live Julia objects
# (sandbox modules, open handles, etc.)
function _safe_state(state::Dict{String,Any})::Dict{String,Any}
    result = Dict{String,Any}()
    for (k, v) in state
        k == "_julia_sandbox" && continue   # REPL sandbox — not serialisable
        try
            JSON3.write(v)   # test round-trip
            result[k] = v
        catch
            # silently skip non-serialisable values
        end
    end
    result
end

function _artifact_to_dict(a::Artifact)::Dict{String,Any}
    Dict{String,Any}(
        "id" => a.id,
        "session_id" => a.session_id,
        "name" => a.name,
        "type" => string(a.type),
        "content_type" => a.content_type,
        "path" => a.path,
        "metadata" => a.metadata,
        "created_at" => a.created_at,
    )
end

function _dict_to_artifact(d::Dict)::Artifact
    Artifact(
        d["id"],
        d["session_id"],
        d["name"],
        Symbol(d["type"]),
        d["content_type"],
        d["path"],
        Dict{String,Any}(d["metadata"]),
        d["created_at"],
    )
end
