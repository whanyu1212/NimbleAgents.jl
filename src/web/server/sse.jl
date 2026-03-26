###############################################################################
# web/server/sse.jl — server-sent events helpers
###############################################################################

# Format a single SSE message
function _sse(type::String, data)
    payload = JSON3.write(Dict("type" => type, "data" => data))
    "data: $(payload)\n\n"
end

# Push a typed event onto the run's event channel (non-blocking best-effort)
function _push_event(run::RunState, type::String, data)
    isopen(run.event_channel) || return nothing
    put!(run.event_channel, _sse(type, data))
end

# SSE streaming — called directly by the router to write incrementally
function _stream_sse(http::HTTP.Stream, run_id::String)
    haskey(_runs, run_id) || begin
        HTTP.setstatus(http, 404)
        HTTP.startwrite(http)
        write(http, "Run not found")
        return nothing
    end

    run = _runs[run_id]

    HTTP.setheader(http, "Content-Type" => "text/event-stream")
    HTTP.setheader(http, "Cache-Control" => "no-cache")
    HTTP.setheader(http, "Connection" => "keep-alive")
    HTTP.setheader(http, "Access-Control-Allow-Origin" => "*")
    HTTP.startwrite(http)

    # Drain events until the channel is closed (run completed)
    for event in run.event_channel
        write(http, event)
    end
end
