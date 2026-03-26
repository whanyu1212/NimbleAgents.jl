###############################################################################
# mcp/http_client.jl — HTTP transport for MCP
###############################################################################

function _rpc(client::MCPHTTPClient, method::String, params=nothing)::Dict{String,Any}
    id = _next_id!(client)
    req = Dict{String,Any}("jsonrpc" => "2.0", "id" => id, "method" => method)
    isnothing(params) || (req["params"] = params)

    # Accept both plain JSON and SSE (Streamable HTTP transport, MCP 2025-03-26)
    base_headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream",
    ]
    auth_headers = [k => v for (k, v) in client.server.headers]
    all_headers = vcat(base_headers, auth_headers)

    resp = try
        HTTP.post(client.server.url, all_headers, JSON3.write(req))
    catch e
        error("MCP HTTP request failed: $(sprint(showerror, e))")
    end

    body = String(resp.body)
    content_type = lowercase(get(Dict(resp.headers), "Content-Type", ""))

    # SSE response — extract the JSON payload from "data: {...}" lines
    parsed = if occursin("text/event-stream", content_type)
        _parse_sse_rpc(body)
    else
        try
            Dict{String,Any}(JSON3.read(body, Dict{String,Any}))
        catch
            error("MCP HTTP: could not parse response JSON")
        end
    end

    if haskey(parsed, "error")
        err = parsed["error"]
        error("MCP error $(get(err, "code", "?")): $(get(err, "message", "unknown"))")
    end

    parsed
end

# Extract the last JSON-RPC response object from an SSE stream body.
# SSE lines look like:
#   event: message
#   data: {"jsonrpc":"2.0","id":1,"result":{...}}
function _parse_sse_rpc(body::String)::Dict{String,Any}
    last_data = nothing
    for line in split(body, r"\r?\n")
        line = strip(line)
        if startswith(line, "data:")
            payload = strip(line[6:end])
            isempty(payload) && continue
            parsed = try
                Dict{String,Any}(JSON3.read(payload, Dict{String,Any}))
            catch
                continue
            end
            # Only keep JSON-RPC response objects (have "id"), not notifications
            haskey(parsed, "id") && (last_data = parsed)
        end
    end
    isnothing(last_data) && error("MCP HTTP (SSE): no JSON-RPC response found in stream")
    last_data
end

"""
    connect!(client::MCPHTTPClient) -> MCPHTTPClient

Perform the JSON-RPC initialize handshake with the remote HTTP MCP server.
Returns the client for chaining.
"""
function connect!(client::MCPHTTPClient)::MCPHTTPClient
    _rpc(
        client,
        "initialize",
        Dict{String,Any}(
            "protocolVersion" => "2024-11-05",
            "capabilities" => Dict{String,Any}(),
            "clientInfo" =>
                Dict{String,Any}("name" => "NimbleAgents.jl", "version" => "0.1"),
        ),
    )

    # Send initialized notification (best-effort — some servers don't require it)
    notif = Dict{String,Any}(
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized",
        "params" => Dict{String,Any}(),
    )
    notif_headers = vcat(
        [
            "Content-Type" => "application/json",
            "Accept" => "application/json, text/event-stream",
        ],
        [k => v for (k, v) in client.server.headers],
    )
    try
        HTTP.post(client.server.url, notif_headers, JSON3.write(notif))
    catch
        # Notifications are fire-and-forget; ignore failures
    end

    client
end

function list_tools(client::MCPHTTPClient)::Vector{NimbleTool}
    _list_tools_cached!(client)
end

"""
    close!(client::MCPHTTPClient)

No-op for HTTP clients — there is no persistent connection to close.
Clears the tool cache.
"""
function close!(client::MCPHTTPClient)
    client._tools = nothing
    return nothing
end
