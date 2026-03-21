```@meta
CurrentModule = NimbleAgents
```

# Sessions & Artifacts

## Sessions

A [`Session`](@ref) manages conversation state across multiple interactions with an agent.

### Creating a Session

```julia
session = Session(app_name="MyApp", user_id="alice")
```

A session tracks:

- **History** — all messages in the conversation
- **State** — key-value store for arbitrary data (persists across turns)
- **Events** — log of all events (LLM calls, tool invocations)
- **Artifacts** — files produced by the agent

### Using Sessions

```julia
# First interaction
run!(agent, "My name is Alice"; session)

# Later interaction — agent remembers the full conversation
run!(agent, "What's my name?"; session)

# Reset to start fresh
reset!(session)
```

### Context Compaction

Long-running sessions can exceed the model's context window. Configure automatic compaction:

```julia
agent = Agent(
    name = "LongBot",
    instructions = "...",
    context = ContextConfig(
        context_window    = 400_000,
        compact_threshold = 0.80,
        keep_last         = 20,
    ),
)
```

When history exceeds 80% of the context window, older messages are summarized into a compact placeholder while keeping the most recent 20 messages intact.

## Session Storage

### InMemorySessionStore

Sessions live in-process memory. Fast, but lost on restart. This is the default for `serve()`.

```julia
store = InMemorySessionStore()
save!(store, session)
loaded = load(store, session.id)   # returns the same object
```

### JSONSessionStore

Persist sessions as JSON files on disk:

```julia
store = JSONSessionStore("./sessions")
save!(store, session)

# Later — restore from disk
loaded = load(store, session.id)
```

### Filtering

Both stores support filtering by `app_name` and/or `user_id`:

```julia
list(store)                                  # all session IDs
list(store; app_name="MyApp")                # filter by app
list(store; user_id="alice")                 # filter by user
list(store; app_name="MyApp", user_id="alice")  # both
```

### Deleting

```julia
delete!(store, session.id)
```

### SQLiteSessionStore

Persist sessions in a single SQLite database file:

```julia
store = SQLiteSessionStore("sessions.db")
save!(store, session)

# Later — restore from disk
loaded = load(store, session.id)

# Clean up
close!(store)
```

SQLiteSessionStore supports the same `list`, `delete!`, and filtering APIs as JSONSessionStore.

## Web UI (Experimental)

NimbleAgents includes a built-in web interface for interacting with agents in the browser. It supports real-time token streaming, tool call visualization, human-in-the-loop approval flows, and session trace inspection.

### Quick Start

```julia
using NimbleAgents

agent = Agent(
    name         = "MyBot",
    instructions = "You are a helpful assistant.",
    tools        = [search_web_tool, fetch_webpage_tool],
)

# Start the server (multiple threads required)
serve([agent]; port=8080)
```

Then open `http://localhost:8080` in your browser.

!!! warning "Requires multiple threads"
    The server spawns agent runs in background threads. Start Julia with at least 2 threads:
    ```
    julia --project -t 4 your_script.jl
    ```

### Multiple Agents

Pass multiple agents and switch between them in the UI:

```julia
serve([chat_agent, research_agent, code_agent]; port=8080)
```

Each agent is registered by name and appears as a selectable option in the web interface.

### Session Persistence

By default, sessions live in memory and are lost when the server stops. Pass a store for persistence:

```julia
# Persist across restarts
serve([agent]; port=8080, store=JSONSessionStore("./sessions"))

# Or use SQLite
serve([agent]; port=8080, store=SQLiteSessionStore("sessions.db"))
```

### Features

- **Token streaming** — responses appear token-by-token via Server-Sent Events
- **Tool call display** — see which tools the agent calls and their results in real-time
- **Human-in-the-loop** — when `should_interrupt` triggers, the UI shows an approval dialog
- **Session traces** — inspect token usage, cost, and timing for each turn
- **Markdown rendering** — agent responses are rendered as formatted markdown

### Architecture

The server exposes a REST + SSE API:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Serves the web UI |
| `/agents` | GET | Lists registered agents |
| `/chat` | POST | Starts an agent run, returns `run_id` + `session_id` |
| `/runs/:id/stream` | GET | SSE stream of tokens, tool calls, and events |
| `/runs/:id/approve` | POST | Approve/deny an interrupted tool call |
| `/sessions/:id` | GET | Fetch session event history |
| `/sessions/:id/trace` | GET | Fetch aggregated trace data |

See [`examples/web/web_ui.jl`](https://github.com/whanyu1212/NimbleAgents.jl/blob/develop/examples/web/web_ui.jl) for a full working example with multiple agents and real web search.

## Artifacts

An [`Artifact`](@ref) is a named, typed output produced by an agent — files, plots, data exports, reports.

### Registering Artifacts

```julia
art = register_artifact!(session, "/path/to/output.csv";
    name     = "sales-report",
    store    = store,       # copies file into store's artifact directory
    metadata = Dict{String,Any}("source" => "analysis_tool"),
)

art.name          # "sales-report"
art.type          # :data (inferred from .csv)
art.content_type  # "text/csv"
```

MIME type and artifact type (`:plot`, `:text`, `:data`, `:file`) are inferred from the file extension.

### Automatic Artifact Registration

Artifacts are registered automatically in two cases:

1. **`return_artifact=true` on a tool** — the tool's output path is registered as an artifact
2. **`save_artifact_tool`** — a built-in tool the agent can call to register artifacts explicitly
3. **`eval_julia_tool`** — plots saved during Julia code evaluation are auto-registered

### Accessing Artifacts

```julia
session.artifacts              # Vector{Artifact}
session.artifacts[1].path      # path to the file
session.artifacts[1].type      # :plot, :text, :data, or :file
```
