###############################################################################
# mcp/orchestration.jl — run-time MCP connection orchestration
###############################################################################

# Internal helper used by run!: connect all MCP servers, collect their tools,
# return (tools_vector, clients_vector) so run! can close them in a finally block.
function _connect_mcp_servers(
    servers::Vector{MCPServer}
)::Tuple{Vector{NimbleTool},Vector{AnyMCPClient}}
    all_tools = NimbleTool[]
    clients = AnyMCPClient[]

    for server in servers
        client = _make_client(server)
        label =
            _is_http(server) ? server.url : "$(server.command) $(join(server.args, " "))"
        try
            connect!(client)
            tools = list_tools(client)
            append!(all_tools, tools)
            push!(clients, client)
            println(
                "[MCP] connected to $(label) — $(length(tools)) tool(s): $(join([t.name for t in tools], ", "))",
            )
        catch e
            println(stderr, "[MCP] failed to connect to $(label): $(sprint(showerror, e))")
            close!(client)
        end
    end

    (all_tools, clients)
end

function _close_mcp_clients(clients::Vector{AnyMCPClient})
    for client in clients
        try
            close!(client)
        catch
        end
    end
end
