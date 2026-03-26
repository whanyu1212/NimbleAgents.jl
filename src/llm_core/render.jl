###############################################################################
# llm_core/render.jl — OpenAI-style message and tool rendering
###############################################################################

function render(::AbstractOpenAISchema, messages::Vector{<:AbstractMessage})
    map(messages) do msg
        if msg isa SystemMessage
            Dict("role" => "system", "content" => _render_content(msg.content))
        elseif msg isa UserMessage
            Dict("role" => "user", "content" => _render_content(msg.content))
        elseif msg isa AIMessage
            Dict("role" => "assistant", "content" => _render_content(msg.content))
        elseif msg isa AIToolRequest
            payload = Dict{String,Any}("role" => "assistant")
            msg.content === nothing || (payload["content"] = _render_content(msg.content))
            payload["tool_calls"] = [
                Dict{String,Any}(
                    "id" => tc.tool_call_id,
                    "type" => "function",
                    "function" => Dict{String,Any}(
                        "name" => tc.name,
                        "arguments" => JSON3.write(_string_dict(something(tc.args, Dict{Symbol,Any}()))),
                    ),
                ) for tc in msg.tool_calls
            ]
            payload
        elseif msg isa ToolMessage
            Dict{String,Any}(
                "role" => "tool",
                "tool_call_id" => msg.tool_call_id,
                "content" => _render_content(something(msg.content, msg.raw)),
            )
        else
            error("Unsupported message type: $(typeof(msg))")
        end
    end
end

function render(::AbstractOpenAISchema, tools::Vector{<:AbstractTool})
    map(tools) do t
        fn = Dict{Symbol,Any}(:name => t.name, :parameters => t.parameters)
        if !isnothing(t.description) && !isempty(t.description)
            fn[:description] = t.description
        end
        Dict{Symbol,Any}(:type => "function", :function => fn)
    end
end
