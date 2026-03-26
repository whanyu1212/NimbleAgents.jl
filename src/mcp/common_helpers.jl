###############################################################################
# mcp/common_helpers.jl — transport-agnostic MCP helpers
###############################################################################

function _next_id!(client::AnyMCPClient)::Int
    client._req_id += 1
end

function _list_tools_cached!(client::AnyMCPClient)::Vector{NimbleTool}
    if client.server.cache_tools && !isnothing(client._tools)
        return client._tools
    end

    lock(client._lock) do
        if client.server.cache_tools && !isnothing(client._tools)
            return client._tools
        end

        resp = _rpc(client, "tools/list", Dict{String,Any}())
        tools_raw = get(get(resp, "result", Dict()), "tools", [])
        tools = _build_mcp_tools(client, tools_raw)
        client._tools = tools
        tools
    end
end

function _build_mcp_tools(client::AnyMCPClient, tools_raw)::Vector{NimbleTool}
    tools = NimbleTool[]
    for t in tools_raw
        name = String(t["name"])
        description = get(t, "description", nothing)
        schema = Dict{String,Any}(
            get(t, "inputSchema", Dict("type" => "object", "properties" => Dict()))
        )

        tool_name = name
        tool_client = client
        callable =
            (args::Dict{Symbol,<:Any}) -> begin
                str_args = Dict{String,Any}(string(k) => v for (k, v) in args)
                _call_mcp_tool(tool_client, tool_name, str_args)
            end

        push!(
            tools,
            NimbleTool(; name=name, parameters=schema, description=description, callable=callable),
        )
    end
    tools
end

function _call_mcp_tool(
    client::AnyMCPClient, name::String, arguments::Dict{String,Any}
)::String
    lock(client._lock) do
        resp = _rpc(
            client, "tools/call", Dict{String,Any}("name" => name, "arguments" => arguments)
        )
        _render_mcp_tool_result(get(resp, "result", Dict()))
    end
end

function _render_mcp_tool_result(result::AbstractDict)::String
    content = get(result, "content", [])

    parts = String[]
    for block in content
        block_type = get(block, "type", "")
        if block_type == "text"
            push!(parts, string(get(block, "text", "")))
        elseif block_type == "image"
            push!(parts, "[image: $(get(block, "mimeType", "image"))]")
        else
            push!(parts, string(block))
        end
    end

    isempty(parts) ? "(no output)" : join(parts, "\n")
end
