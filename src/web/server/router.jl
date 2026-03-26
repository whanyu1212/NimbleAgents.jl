###############################################################################
# web/server/router.jl — request routing and CORS handling
###############################################################################

function _cors(req::HTTP.Request)
    HTTP.Response(
        200,
        [
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type",
        ],
    )
end

function _router(http::HTTP.Stream)
    req = http.message
    method = req.method
    target = req.target

    # Strip query string
    path = split(target, "?")[1]
    parts = filter(!isempty, split(path, "/"))

    # CORS preflight
    if method == "OPTIONS"
        HTTP.setstatus(http, 200)
        HTTP.setheader(http, "Access-Control-Allow-Origin" => "*")
        HTTP.setheader(http, "Access-Control-Allow-Methods" => "GET, POST, OPTIONS")
        HTTP.setheader(http, "Access-Control-Allow-Headers" => "Content-Type")
        HTTP.startwrite(http)
        return nothing
    end

    # SSE streaming — handled specially to write incrementally
    if method == "GET" && length(parts) == 3 && parts[1] == "runs" && parts[3] == "stream"
        _stream_sse(http, String(parts[2]))
        return nothing
    end

    # All other routes — read full request body then write response
    HTTP.startwrite(http)
    resp = if method == "GET" && isempty(parts)
        _handle_static(req)
    elseif method == "GET" && parts == ["agents"]
        _handle_agents(req)
    elseif method == "POST" && parts == ["chat"]
        req = HTTP.Request(method, target, req.headers, read(http))
        _handle_chat(req)
    elseif method == "POST" &&
        length(parts) == 3 &&
        parts[1] == "runs" &&
        parts[3] == "approve"
        req = HTTP.Request(method, target, req.headers, read(http))
        _handle_approve(req, String(parts[2]))
    elseif method == "GET" &&
        length(parts) == 3 &&
        parts[1] == "sessions" &&
        parts[3] == "trace"
        _handle_session_trace(req, String(parts[2]))
    elseif method == "GET" && length(parts) == 2 && parts[1] == "sessions"
        _handle_session(req, String(parts[2]))
    else
        HTTP.Response(404, "Not found: $(path)")
    end

    HTTP.setstatus(http, resp.status)
    for h in resp.headers
        HTTP.setheader(http, h.first => h.second)
    end
    body = resp.body
    isnothing(body) || write(http, body)
end
