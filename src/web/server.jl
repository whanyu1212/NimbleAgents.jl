###############################################################################
# web/server.jl — NimbleAgents local web UI
#
# Prototype: lives in NimbleAgents.jl for now, will migrate to
# NimbleAgentsWeb.jl once the package is published.
#
# Usage:
#   using NimbleAgents
#   agent = Agent(name="MyBot", instructions="...", tools=[...])
#   serve([agent]; port=8080)
###############################################################################

using HTTP: HTTP
using JSON3: JSON3
import UUIDs: uuid4

# ── RunState ──────────────────────────────────────────────────────────────────

mutable struct RunState
    task::Union{Task,Nothing}
    approval_channel::Channel{String}
    event_channel::Channel{String}   # pre-serialised JSON SSE lines
    status::Symbol            # :running | :interrupted | :done | :error
    result::Union{String,Nothing}
    session_id::String
end

function RunState(session_id::String)
    RunState(
        nothing, Channel{String}(1), Channel{String}(256), :running, nothing, session_id
    )
end

# ── Server state ──────────────────────────────────────────────────────────────

const _runs = Dict{String,RunState}()
const _agents = Dict{String,Agent}()

# Active store — set by serve(), used by all handlers.
# Default: InMemorySessionStore (replaced on each serve() call).
const _store = Ref{AbstractSessionStore}(InMemorySessionStore())

# ── SSE helpers ───────────────────────────────────────────────────────────────

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

# ── AgentHooks that feed the event channel ────────────────────────────────────

function _web_hooks(run::RunState)
    AgentHooks(;
        on_tool_call=(agent, name, args) -> _push_event(
            run, "tool_call", Dict("name" => name, "args" => something(args, Dict()))
        ),
        on_tool_result=(agent, name, result) -> _push_event(
            run, "tool_result", Dict("name" => name, "result" => string(result))
        ),
    )
end

# ── Route handlers ────────────────────────────────────────────────────────────

function _handle_static(req::HTTP.Request)
    ui_path = joinpath(@__DIR__, "ui.html")
    isfile(ui_path) || return HTTP.Response(404, "ui.html not found")
    HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"]; body=read(ui_path))
end

function _handle_agents(req::HTTP.Request)
    list = [Dict("id" => name, "name" => name) for name in keys(_agents)]
    HTTP.Response(200, ["Content-Type" => "application/json"]; body=JSON3.write(list))
end

function _handle_chat(req::HTTP.Request)
    body = JSON3.read(String(req.body), Dict{String,Any})

    agent_id = something(get(body, "agent_id", nothing), "")
    session_id = something(get(body, "session_id", nothing), "")
    input = something(get(body, "input", nothing), "")

    haskey(_agents, agent_id) || return HTTP.Response(400, "Unknown agent: $(agent_id)")
    isempty(input) && return HTTP.Response(400, "input is required")

    # Resolve or create session
    store = _store[]
    session = if isempty(session_id)
        nothing
    else
        load(store, session_id)
    end
    if isnothing(session)
        session = Session(; app_name=agent_id, user_id="web")
        session_id = session.id
        save!(store, session)
    end

    run_id = string(uuid4())
    run = RunState(session_id)
    _runs[run_id] = run
    println(
        "[NimbleAgents] run=$(run_id) session=$(session_id) agent=$(agent_id) — starting"
    )

    base_agent = _agents[agent_id]
    web_hooks = _web_hooks(run)

    # Merge web hooks with any user-defined hooks on the agent
    merged_hooks = AgentHooks(;
        before_llm_call=base_agent.hooks.before_llm_call,
        after_llm_call=base_agent.hooks.after_llm_call,
        should_interrupt=base_agent.hooks.should_interrupt,
        on_tool_call=(ag, name, args) -> begin
            isnothing(base_agent.hooks.on_tool_call) ||
                base_agent.hooks.on_tool_call(ag, name, args)
            web_hooks.on_tool_call(ag, name, args)
        end,
        on_tool_result=(ag, name, result) -> begin
            isnothing(base_agent.hooks.on_tool_result) ||
                base_agent.hooks.on_tool_result(ag, name, result)
            web_hooks.on_tool_result(ag, name, result)
        end,
        on_complete=base_agent.hooks.on_complete,
    )

    agent = Agent(;
        name=base_agent.name,
        instructions=base_agent.instructions,
        tools=base_agent.tools,
        model=base_agent.model,
        max_iterations=base_agent.max_iterations,
        output_type=base_agent.output_type,
        sub_agents=base_agent.sub_agents,
        retry=base_agent.retry,
        context=base_agent.context,
        hooks=merged_hooks,
        skills=base_agent.skills,
        skill_dirs=base_agent.skill_dirs,
        mcp_servers=base_agent.mcp_servers,
    )

    # Collect tokens into buffer for streaming
    token_buf = IOBuffer()

    run.task = Threads.@spawn begin
        try
            result = run!(
                agent,
                input;
                session=session,
                store=store,
                verbose=false,
                approval_channel=run.approval_channel,
                on_token=tok -> begin
                    print(token_buf, tok)
                    _push_event(run, "token", tok)
                end,
            )
            run.result = string(result)
            run.status = :done
            println(
                "[NimbleAgents] run=$(run_id) — done, result length=$(length(run.result))"
            )
            _push_event(run, "done", Dict("result" => run.result))
        catch e
            if e isa ApprovalTimeout
                run.status = :error
                msg = "Approval timed out after $(e.timeout)s"
                println("[NimbleAgents] run=$(run_id) — approval timeout")
                _push_event(run, "error", Dict("message" => msg))
            else
                run.status = :error
                msg = sprint(showerror, e)
                println("[NimbleAgents] run=$(run_id) — error: $(msg)")
                println(stderr, sprint(Base.show_backtrace, catch_backtrace()))
                _push_event(run, "error", Dict("message" => msg))
            end
        finally
            close(run.event_channel)
        end
    end

    HTTP.Response(
        200,
        ["Content-Type" => "application/json"];
        body=JSON3.write(Dict("run_id" => run_id, "session_id" => session_id)),
    )
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

function _handle_approve(req::HTTP.Request, run_id::String)
    haskey(_runs, run_id) || return HTTP.Response(404, "Run not found: $(run_id)")

    run = _runs[run_id]
    run.status == :interrupted ||
        return HTTP.Response(400, "Run is not awaiting approval (status: $(run.status))")

    body = JSON3.read(String(req.body), Dict{String,Any})
    response = get(body, "response", "approve")

    put!(run.approval_channel, response)
    run.status = :running

    HTTP.Response(
        200, ["Content-Type" => "application/json"]; body=JSON3.write(Dict("ok" => true))
    )
end

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

# ── CORS preflight ────────────────────────────────────────────────────────────

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

# ── Router ────────────────────────────────────────────────────────────────────

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

# ── Public API ────────────────────────────────────────────────────────────────

"""
    serve(agents; port=8080, host="127.0.0.1", store=InMemorySessionStore())

Start the NimbleAgents web UI server.

Registers `agents` by name and serves a local browser UI at
`http://\$host:\$port`. Press Ctrl+C to stop.

Pass a `store` to persist sessions across server restarts:

```julia
serve([agent]; store=JSONSessionStore(".nimble/sessions"))
```

!!! note "Multiple threads required"
    The server spawns agent runs in background threads. Start Julia with
    at least 2 threads:
    ```
    julia --project=. -t 4 examples/web/web_ui.jl
    ```

# Example
```julia
using NimbleAgents

agent = Agent(
    name         = "MyBot",
    instructions = "You are a helpful assistant.",
    model        = "gpt-5.4-mini",
)

serve([agent]; port=8080)
# With persistence:
serve([agent]; port=8080, store=JSONSessionStore(".nimble/sessions"))
```
"""
function serve(
    agents::Vector{<:Agent};
    port::Int=8080,
    host::String="127.0.0.1",
    store::AbstractSessionStore=InMemorySessionStore(),
)
    empty!(_agents)
    empty!(_runs)
    _store[] = store

    for agent in agents
        _agents[agent.name] = agent
    end

    url = "http://$(host):$(port)"
    println("NimbleAgents UI starting")
    println("  Agents : ", join(keys(_agents), ", "))
    println("  Store  : ", nameof(typeof(store)))
    println("  URL    : ", url)
    println("  Press Ctrl+C to stop\n")

    HTTP.listen(host, port; stream=true) do http
        try
            _router(http)
        catch e
            println(
                stderr,
                "[NimbleAgents] Request error on ",
                http.message.method,
                " ",
                http.message.target,
                ": ",
                sprint(showerror, e),
            )
            println(stderr, sprint(Base.show_backtrace, catch_backtrace()))
            try
                HTTP.setstatus(http, 500)
                HTTP.startwrite(http)
                write(http, "Internal server error")
            catch
            end
        end
    end
end
