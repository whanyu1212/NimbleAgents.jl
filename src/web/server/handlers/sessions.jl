###############################################################################
# web/server/handlers/sessions.jl — session and trace handlers
###############################################################################

function _handle_session(req::HTTP.Request, session_id::String)
    println("[NimbleAgents] GET /sessions/$(session_id) — loading session")
    session = load(_store[], session_id)
    if isnothing(session)
        println("[NimbleAgents] Session not found: $(session_id)")
        return HTTP.Response(404, "Session not found: $(session_id)")
    end
    println("[NimbleAgents] Session loaded — $(length(session.events)) turn(s)")

    events = map(session.events) do e
        Dict(
            "agent" => e.agent,
            "input" => e.input,
            "output" => something(e.output, ""),
            "llm_calls" => e.llm_calls,
            "input_tokens" => e.input_tokens,
            "output_tokens" => e.output_tokens,
            "elapsed" => round(e.elapsed; digits=2),
            "timestamp" => e.timestamp,
            "tool_calls" => map(
                t -> Dict(
                    "name" => t.name,
                    "args" => t.args,
                    "result" => string(something(t.result, "")),
                ),
                e.tool_calls,
            ),
        )
    end

    HTTP.Response(200, ["Content-Type" => "application/json"]; body=JSON3.write(events))
end

function _handle_session_trace(req::HTTP.Request, session_id::String)
    println("[NimbleAgents] GET /sessions/$(session_id)/trace — building trace")
    session = load(_store[], session_id)
    if isnothing(session)
        println("[NimbleAgents] Trace request — session not found: $(session_id)")
        return HTTP.Response(404, "Session not found: $(session_id)")
    end
    println("[NimbleAgents] Session loaded — $(length(session.events)) turn(s) for trace")

    trace = try
        Trace(session)
    catch e
        msg = sprint(showerror, e)
        println("[NimbleAgents] Trace construction failed: $(msg)")
        println(stderr, sprint(Base.show_backtrace, catch_backtrace()))
        return HTTP.Response(500, "Trace construction failed: $(msg)")
    end

    println(
        "[NimbleAgents] Trace built — turns=$(length(trace.turns)) " *
        "tokens=$(trace.total_tokens) duration=$(round(trace.duration; digits=2))s",
    )

    data = Dict{String,Any}(
        "total_input_tokens" => trace.total_input_tokens,
        "total_output_tokens" => trace.total_output_tokens,
        "total_tokens" => trace.total_tokens,
        "total_cost" => round(trace.total_cost; digits=4),
        "total_llm_calls" => trace.total_llm_calls,
        "total_tool_calls" => trace.total_tool_calls,
        "duration" => round(trace.duration; digits=2),
        "agents" => trace.agents,
        "turns" => map(trace.turns) do t
            Dict{String,Any}(
                "agent" => t.agent,
                "model" => t.model,
                "input" => t.input,
                "output" => isnothing(t.output) ? "" : string(t.output),
                "llm_calls" => t.llm_calls,
                "input_tokens" => t.input_tokens,
                "output_tokens" => t.output_tokens,
                "cost" => round(t.cost; digits=4),
                "elapsed" => round(t.elapsed; digits=2),
                "timestamp" => t.timestamp,
                "tool_calls" => map(t.tool_calls) do te
                    Dict{String,Any}(
                        "name" => te.name,
                        "args" => Dict(string(k) => v for (k, v) in te.args),
                        "result" => isnothing(te.result) ? "" : string(te.result),
                        "error" => te.error,
                    )
                end,
            )
        end,
    )

    HTTP.Response(
        200,
        ["Content-Type" => "application/json", "Access-Control-Allow-Origin" => "*"];
        body=JSON3.write(data),
    )
end
