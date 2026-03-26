###############################################################################
# web/server/serve.jl — public server entrypoint
###############################################################################

"""
    serve(agents; port=8080, host="127.0.0.1", store=InMemorySessionStore())

Start the NimbleAgents web UI server.

Registers `agents` by name and serves a local browser UI at
`http://\$host:\$port`. Press Ctrl+C to stop.

# Arguments
- `agents::Vector{<:Agent}`: Agents to register in the web UI, keyed by `agent.name`.
- `port::Int`: TCP port to listen on (default: `8080`).
- `host::String`: Host/interface to bind (default: `"127.0.0.1"`).
- `store::AbstractSessionStore`: Session persistence backend used by the server.

# Returns
- `Nothing`: Runs the HTTP server loop until interrupted (`Ctrl+C`).

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
