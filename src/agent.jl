###############################################################################
# agent.jl — Agent struct and run! loop
###############################################################################

import PromptingTools as PT
using StreamCallbacks: StreamCallbacks
using Mocking

# ──────────────────────────────────────────────────────────────────────────────
# HumanInterrupt
# ──────────────────────────────────────────────────────────────────────────────

"""
    HumanInterrupt(tool_calls; message)

Thrown from `after_llm_call` to pause the agent loop before any tool executes.

The LLM has produced a plan (`tool_calls`) but no side-effects have occurred yet.
The caller catches this, presents the pending actions to a human, and either:
- **Approves** → calls `resume!(session, "Approved")` and re-runs `run!`
- **Rejects**  → calls `resume!(session, "Rejected — do X instead")` and re-runs `run!`
- **Aborts**   → discards the session entirely

# Fields
- `tool_calls`: The pending tool calls the LLM intended to execute.
- `message::String`: Optional context message (default: `"Human approval required"`).

# Example
```julia
hooks = AgentHooks(
    after_llm_call = (agent, iter, msg) -> begin
        dangerous = ["delete_file", "send_email", "write_db"]
        pending   = filter(t -> t.name in dangerous, something(msg.tool_calls, []))
        isempty(pending) && return
        throw(HumanInterrupt(pending;
            message = "About to: " * join([t.name for t in pending], ", ")))
    end
)
```
"""
struct HumanInterrupt <: Exception
    tool_calls::Any     # Vector of PT ToolMessage objects
    message::String
    function HumanInterrupt(tool_calls; message::String="Human approval required")
        new(tool_calls, message)
    end
end

function Base.showerror(io::IO, e::HumanInterrupt)
    print(
        io,
        "HumanInterrupt: ",
        e.message,
        "\n  Pending tool calls: ",
        join([t.name for t in e.tool_calls], ", "),
    )
end

"""
    ApprovalTimeout(tool_calls, timeout)

Thrown when an `approval_channel` is provided but no response arrives within
`approval_timeout` seconds.
"""
struct ApprovalTimeout <: Exception
    tool_calls::Any
    timeout::Float64
end

function Base.showerror(io::IO, e::ApprovalTimeout)
    print(
        io,
        "ApprovalTimeout: no response received within $(e.timeout)s\n",
        "  Pending tool calls: ",
        join([t.name for t in e.tool_calls], ", "),
    )
end

"""
    resume!(session, human_response)

Inject a human approval/rejection into `session.history` so the agent can
continue after a `HumanInterrupt`. Call `run!` again after this.

```julia
try
    run!(agent, input; session=session)
catch e
    e isa HumanInterrupt || rethrow(e)
    println("Pending: ", e.message)
    response = readline()
    resume!(session, response)
    run!(agent, input; session=session)
end
```
"""
function resume!(session::Session, human_response::String)
    lock(session.lock) do
        push!(session.history, PT.UserMessage(human_response))
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# RetryConfig
# ──────────────────────────────────────────────────────────────────────────────

"""
    RetryConfig(; max_retries, initial_delay, max_delay, multiplier, jitter,
                  retry_on_status, max_parse_retries)

Exponential-backoff retry policy for LLM API calls made inside `run!`.

# Fields
- `max_retries::Int`: Maximum number of retry attempts after the first failure (default: `3`).
- `initial_delay::Float64`: Seconds to wait before the first retry (default: `0.5`).
  Consensus across Anthropic SDK and LangGraph; fast enough for transient errors.
- `max_delay::Float64`: Maximum seconds to wait between retries (default: `60.0`).
  Chosen to match the standard 1-minute rate-limit reset window used by both
  OpenAI and Anthropic — capping here means later retries will wait long enough
  to clear a sustained 429 burst without hanging indefinitely.
- `multiplier::Float64`: Exponential growth factor (default: `2.0`). Universal
  across all reference SDKs (OpenAI, Anthropic, ADK, LangGraph).
- `jitter::Bool`: When `true`, multiplies each delay by a random factor in
  `[0.75, 1.0]` (Anthropic-style multiplicative jitter). Prevents thundering-herd
  when many parallel agents retry simultaneously (default: `true`).
- `retry_on_status::Vector{Int}`: HTTP status codes that warrant a retry.
  - `408` request timeout, `429` rate limit — always transient
  - `500/502/503/504` server-side errors — usually transient
  - `529` Anthropic-specific overload status
  4xx errors outside this list (401, 400, 403, 404) are permanent failures and
  are never retried regardless of this setting.
- `max_parse_retries::Int`: Maximum number of re-prompts when `output_type` parsing
  fails (default: `2`). On each failure the parse error is fed back to the LLM
  as a user message so it can correct its response. Set to `0` to disable.

# Example
```julia
agent = Agent(
    name   = "Bot",
    instructions = "...",
    retry  = RetryConfig(max_retries=5, max_delay=120.0),
)
```
"""
Base.@kwdef struct RetryConfig
    max_retries::Int = 3
    initial_delay::Float64 = 0.5
    # 60s matches the standard 1-minute rate-limit reset window for OpenAI and
    # Anthropic. Retries that reach this cap will wait long enough for the window
    # to clear before trying again, rather than giving up too early (32s) or
    # hanging excessively (ADK's 120s / LangGraph's 128s).
    max_delay::Float64 = 60.0
    multiplier::Float64 = 2.0
    jitter::Bool = true
    retry_on_status::Vector{Int} = [408, 429, 500, 502, 503, 504, 529]
    max_parse_retries::Int = 2
end

# Compute the wait time for attempt n (1-indexed), with optional jitter.
function _backoff_delay(cfg::RetryConfig, attempt::Int)::Float64
    delay = min(cfg.initial_delay * cfg.multiplier ^ (attempt - 1), cfg.max_delay)
    cfg.jitter ? delay * (0.75 + 0.25 * rand()) : delay
end

# Return true if the exception looks like a retryable HTTP error.
# Match "HTTP <code>" or "status <code>" patterns to avoid false positives
# from messages that happen to contain a status code number in other contexts.
function _retryable(cfg::RetryConfig, err)::Bool
    msg = sprint(showerror, err)
    any(
        occursin(Regex("(?:HTTP|status)\\s*" * string(code)), msg) for
        code in cfg.retry_on_status
    )
end

# Retry wrapper: calls f(), retrying on retryable errors up to cfg.max_retries times.
function _with_retry(f::Function, cfg::RetryConfig, agent_name::String)
    last_err = nothing
    for attempt in 1:(cfg.max_retries + 1)
        try
            return f()
        catch err
            last_err = err
            attempt > cfg.max_retries && break
            _retryable(cfg, err) || rethrow(err)
            delay = _backoff_delay(cfg, attempt)
            println(
                stderr,
                "[$(agent_name)] LLM call failed (attempt $(attempt)/$(cfg.max_retries + 1)), retrying in $(round(delay; digits=1))s: ",
                sprint(showerror, err),
            )
            sleep(delay)
        end
    end
    println(stderr, "[$(agent_name)] all $(cfg.max_retries) retries exhausted")
    rethrow(last_err)
end

# ──────────────────────────────────────────────────────────────────────────────
# ContextConfig
# ──────────────────────────────────────────────────────────────────────────────

"""
    ContextConfig(; context_window, compact_threshold, keep_last, summary_model)

Controls automatic context-window management for long-running sessions.

When `session.history` grows large enough to risk hitting the model's context
limit, NimbleAgents compacts it using a **hybrid strategy**:

1. The most recent `keep_last` messages are always kept verbatim — they carry
   the immediate context the model needs for the current turn.
2. Everything older is summarised into a single compressed message by the LLM,
   replacing the raw history.

This mirrors the approach used by Claude Code and Codex: compact at ~80% of the
context window, not at 100%, so there is always headroom for the current turn's
input and the model's output.

# Fields
- `context_window::Int`: Total token capacity of the model (default: `400_000`).
  Set to match Claude Opus 4.5/4.6 (400k context, 128k max output).
- `compact_threshold::Float64`: Fraction of `context_window` at which compaction
  is triggered (default: `0.80`).  At 80% × 400k = 320k tokens, there is still
  80k of headroom — enough for a large current-turn input plus a full output.
  Claude Code and Codex both use ~80% as their trigger.
- `keep_last::Int`: Number of recent messages to preserve verbatim after
  compaction (default: `20`). These are never summarised so the agent retains
  immediate conversational context.
- `summary_model::Union{String,Nothing}`: Model used for the summarisation call.
  Defaults to `nothing`, which means the agent's own model is used.

# Example
```julia
# Long-running session with aggressive compaction
session_agent = Agent(
    name    = "LongBot",
    instructions = "...",
    context = ContextConfig(keep_last=10),
)
```
"""
Base.@kwdef struct ContextConfig
    # Claude Opus 4.5/4.6: 400k context window, 128k max output.
    context_window::Int = 400_000
    # Trigger at 80% — same heuristic as Claude Code and Codex.
    # Leaves 80k headroom for current-turn input + model output.
    compact_threshold::Float64 = 0.80
    # Keep the 20 most recent messages verbatim so the agent has
    # immediate context; only older messages are summarised.
    keep_last::Int = 20
    summary_model::Union{String,Nothing} = nothing
end

# ──────────────────────────────────────────────────────────────────────────────
# AgentHooks
# ──────────────────────────────────────────────────────────────────────────────

"""
    AgentHooks(; before_llm_call, after_llm_call, should_interrupt, on_tool_call, on_tool_result, on_complete)

Optional lifecycle callbacks for an `Agent`. All fields default to `nothing`
(no-op). Provide a function to observe or log that event.

# Callbacks

| Field | Signature | Fired |
|---|---|---|
| `before_llm_call` | `(agent, iteration, messages) -> messages` | Before each LLM request — can modify the messages vector |
| `after_llm_call` | `(agent, iteration, response)` | After each LLM response — before any tool executes |
| `should_interrupt` | `(tool_name, args) -> Bool` | Before each tool executes — return `true` to pause and require human approval |
| `on_tool_call` | `(agent, tool_name, args)` | Before each tool is executed (after approval) |
| `on_tool_result` | `(agent, tool_name, result)` | After each tool returns |
| `on_complete` | `(agent, result)` | When `run!` is about to return |

`should_interrupt` is the recommended way to gate dangerous tools. When it returns `true`
for any pending tool call, the framework collects all flagged calls, throws a `HumanInterrupt`,
and no tools execute. Call `resume!(session, response)` then re-run `run!` to continue.

# Example — gate dangerous tools
```julia
hooks = AgentHooks(
    should_interrupt = (name, args) -> name in ["send_email", "delete_file"]
)
agent = Agent(name="Bot", instructions="...", hooks=hooks)

try
    run!(agent, "Send an email and delete the log"; session=session)
catch e
    e isa HumanInterrupt || rethrow(e)
    println(e.message)           # "About to call: send_email, delete_file"
    resume!(session, readline()) # inject human response
    run!(agent, "Send an email and delete the log"; session=session)
end
```

# Example — observability only
```julia
hooks = AgentHooks(
    on_tool_call   = (ag, name, args)   -> println("calling \$name with \$args"),
    on_tool_result = (ag, name, result) -> println("\$name returned \$result"),
    on_complete    = (ag, result)       -> println("done: \$result"),
)
```
"""
Base.@kwdef struct AgentHooks
    before_llm_call::Union{Function,Nothing} = nothing  # (agent, iteration, messages) -> messages
    after_llm_call::Union{Function,Nothing} = nothing  # (agent, iteration, response)
    should_interrupt::Union{Function,Nothing} = nothing  # (tool_name, args) -> Bool
    on_tool_call::Union{Function,Nothing} = nothing  # (agent, tool_name, args)
    on_tool_result::Union{Function,Nothing} = nothing  # (agent, tool_name, result)
    on_complete::Union{Function,Nothing} = nothing  # (agent, result)
end

# Helper — call a hook only if it is set
_fire(::Nothing, args...) = nothing
_fire(f::Function, args...) = f(args...)

"""Resolve agent instructions — static string or dynamic callable."""
_resolve_instructions(s::String, session, agent) = s
_resolve_instructions(f::Function, session, agent) = f(session, agent)::String

# ──────────────────────────────────────────────────────────────────────────────
# Tool output trimming
# ──────────────────────────────────────────────────────────────────────────────

"""
    _trim_tool_output(text, max_chars) -> String

Line-aware head+tail trimming. If `text` fits within `max_chars`, returns it
unchanged. Otherwise keeps ~80% from the head and ~20% from the tail (snapped
to line boundaries) with an informative gap marker.

Returns the original string when `max_chars <= 0` (unlimited).
"""
function _trim_tool_output(text::AbstractString, max_chars::Int)::String
    max_chars <= 0 && return String(text)
    n = length(text)
    n <= max_chars && return String(text)

    lines = split(text, '\n')
    length(lines) <= 2 && return text[1:max_chars] * "\n... (truncated, $(n) total chars)"

    head_budget = round(Int, max_chars * 0.80)
    tail_budget = max_chars - head_budget

    # Head: take lines until budget exhausted
    head_lines = String[]
    head_chars = 0
    for line in lines
        next = head_chars + length(line) + 1  # +1 for newline
        next > head_budget && break
        push!(head_lines, line)
        head_chars = next
    end

    # Tail: take lines from end until budget exhausted
    tail_lines = String[]
    tail_chars = 0
    for i in length(lines):-1:1
        line = lines[i]
        next = tail_chars + length(line) + 1
        next > tail_budget && break
        pushfirst!(tail_lines, line)
        tail_chars = next
    end

    omitted_lines = length(lines) - length(head_lines) - length(tail_lines)
    omitted_chars = n - head_chars - tail_chars
    approx_tokens = div(omitted_chars, 4)

    head_str = join(head_lines, '\n')
    tail_str = join(tail_lines, '\n')
    marker = "\n... (trimmed $(omitted_chars) chars / ~$(approx_tokens) tokens, $(omitted_lines) lines omitted) ...\n"

    head_str * marker * tail_str
end

"""
    _effective_max_output(tool_obj, agent) -> Int

Resolve the effective output limit: per-tool override wins, then agent default.
Returns 0 (unlimited) if neither is set.
"""
function _effective_max_output(tool_obj, agent)::Int
    per_tool = _max_output(tool_obj)
    per_tool > 0 && return per_tool
    return agent.max_tool_output
end

# ──────────────────────────────────────────────────────────────────────────────
# Agent struct
# ──────────────────────────────────────────────────────────────────────────────

"""
    Agent(; name, instructions, tools, model, max_iterations, output_type, hooks)

A configured AI agent with a system prompt, a set of tools, and a model.

# Fields
- `name::String`: Human-readable name for the agent.
- `instructions::Union{String, Function}`: The system prompt — what the agent does and
  how it behaves. Can be a static `String` or a callable `(session, agent) -> String`
  for dynamic prompts (e.g. per-user context, RAG injection, time-aware instructions).
- `tools::Vector{Tool}`: Tools the agent can call.
- `model::String`: Model identifier (default: `"gpt-5.4-mini"`).
- `max_iterations::Int`: Maximum number of LLM calls before the loop stops (default: `10`).
- `output_type::Union{Type, Nothing}`: When set, the final response is parsed into this
  Julia struct instead of returned as a plain `String`.
- `api_kwargs::NamedTuple`: Extra keyword arguments passed through to every PromptingTools
  LLM call (`aitools`, `aigenerate`, `aiextract`). Use this for model-specific features
  like OpenAI reasoning config or Anthropic thinking config (default: `NamedTuple()`).
- `hooks::AgentHooks`: Optional lifecycle callbacks (default: all no-ops).
- `sub_agents::Vector{Agent}`: Child agents the LLM can hand off to. A `handoff_tool` is
  generated automatically for each one — no manual wiring needed.
- `retry::RetryConfig`: Exponential-backoff retry policy for LLM API calls (default: 3
  retries, 0.5s–60s window). Set `retry=RetryConfig(max_retries=0)` to disable.
- `context::ContextConfig`: Context-window management policy. When `session.history`
  exceeds `context.compact_threshold × context.context_window` tokens, older messages
  are summarised and replaced, keeping the most recent `context.keep_last` messages
  verbatim.
- `skills::Vector{Skill}`: Explicitly attached skills. Metadata is injected into the
  system prompt; full instructions are loaded on demand via the built-in `read_skill` tool.
- `skill_dirs::Vector{String}`: Directories to scan for skill subdirectories at run time.
  Discovered skills are merged with any explicitly listed in `skills`.
- `max_tool_output::Int`: Global character limit for tool result strings inserted into
  the conversation (default: `0` = unlimited). When a tool result exceeds this limit, it
  is trimmed with head+tail preservation and an informative gap marker. Per-tool limits
  (`NimbleTool.max_output`) override this when set.

# Example — plain text output
```julia
@tool function add(x::Int, y::Int)
    "Add two integers."
    x + y
end

agent = Agent(
    name         = "MathBot",
    instructions = "You are a helpful assistant that can do arithmetic.",
    tools        = [add_tool],
)

result = run!(agent, "What is 3 + 4?")  # String
```

# Example — with session memory
```julia
session = Session(app_name="MyApp", user_id="alice")
run!(agent, "What is 8 + 14?"; session=session)
run!(agent, "Now multiply that by 3"; session=session)  # remembers 22
```
"""
Base.@kwdef struct Agent
    name::String
    instructions::Union{String,Function}
    tools::Vector{<:AbstractTool} = NimbleTool[]
    model::String = "gpt-5.4-mini"
    max_iterations::Int = 10
    output_type::Union{Type,Nothing} = nothing
    api_kwargs::NamedTuple = NamedTuple()
    hooks::AgentHooks = AgentHooks()
    sub_agents::Vector{Agent} = Agent[]
    retry::RetryConfig = RetryConfig()
    context::ContextConfig = ContextConfig()
    skills::Vector{Skill} = Skill[]
    skill_dirs::Vector{String} = String[]
    mcp_servers::Vector{MCPServer} = MCPServer[]
    guardrails::Vector{Guardrail} = Guardrail[]
    memory::Union{AbstractMemoryService,Nothing} = nothing
    max_tool_output::Int = 0  # 0 = unlimited
end

# ──────────────────────────────────────────────────────────────────────────────
# run!
# ──────────────────────────────────────────────────────────────────────────────

"""
    run!(agent, input; session, verbose, on_token, approval_channel, approval_timeout) -> Union{String, Any}

Run the agent loop on `input`.

- If `agent.output_type` is `nothing` → returns a `String`.
- If `agent.output_type` is set → returns an instance of that type.

# Arguments
- `session::Union{Session, Nothing}`: Pass a `Session` to retain conversation
  history, key-value state, and an event log across calls.
- `verbose::Bool`: Print iteration info (default `true`).
- `on_token::Union{Function, Nothing}`: When set, the **final** LLM response is
  streamed token-by-token. `on_token(token::String)` is called for each chunk as
  it arrives. Tool-call rounds are always blocking (streaming + tool calls are not
  supported by the underlying API). Pass `on_token = token -> print(token)` to
  stream directly to the terminal.
- `approval_channel::Union{Channel{String}, Nothing}`: When set alongside
  `should_interrupt`, the agent **pauses** mid-loop waiting for a response on
  this channel instead of throwing `HumanInterrupt`. Use this for non-blocking
  approval flows (web servers, notebooks, GUIs) where the human's response
  arrives asynchronously from another thread or HTTP handler.
  Put `"approve"` to proceed, any other string to redirect, or close the channel
  to abort. The agent holds all its state while waiting — no re-run needed.
- `approval_timeout::Float64`: Seconds to wait for a response on
  `approval_channel` before throwing an `ApprovalTimeout` error (default: `300.0`).

# Example — CLI (blocking, throw-based)
```julia
run!(agent, "Write a short poem"; on_token = token -> print(token))
```

# Example — async approval (non-blocking, channel-based)
```julia
ch   = Channel{String}(1)
task = Threads.@spawn run!(agent, input; session=session, approval_channel=ch)
# agent is paused waiting for approval — this thread is free
put!(ch, "approve")   # unblocks the agent from anywhere
result = fetch(task)
```
"""
function run!(
    agent::Agent,
    input::String;
    session::Union{Session,Nothing}=nothing,
    verbose::Bool=true,
    on_token::Union{Function,Nothing}=nothing,
    approval_channel::Union{Channel{String},Nothing}=nothing,
    approval_timeout::Float64=300.0,
    store::Union{AbstractSessionStore,Nothing}=nothing,
)
    # Merge explicit tools with auto-generated handoff tools from sub_agents
    sub_tools = Tool[handoff_tool(sa) for sa in agent.sub_agents]
    all_tools = isempty(sub_tools) ? agent.tools : vcat(agent.tools, sub_tools)

    # Discover and merge skills (explicit + scanned dirs), inject read_skill tool
    all_skills = vcat(agent.skills, discover_skills(agent.skill_dirs))
    if !isempty(all_skills)
        all_tools = vcat(all_tools, [_read_skill_tool(all_skills)])
    end

    # Connect MCP servers and append their tools
    mcp_clients = AnyMCPClient[]
    if !isempty(agent.mcp_servers)
        mcp_tools, mcp_clients = _connect_mcp_servers(agent.mcp_servers)
        all_tools = vcat(all_tools, mcp_tools)
    end

    tool_map = build_tool_map(all_tools)
    hooks = agent.hooks
    t_start = time()

    # Expose session and store to built-in tools via task-local storage so
    # they can access per-session state without explicit parameter threading.
    task_local_storage(:_repl_session_state, isnothing(session) ? nothing : session.state)
    task_local_storage(:_current_session, session)
    task_local_storage(:_current_store, store)
    task_local_storage(:_current_memory, agent.memory)

    # Build a TurnEvent to accumulate per-turn metadata
    turn = TurnEvent(agent.name, agent.model, input)

    try

        # Compact session history if it is approaching the context window limit
        !isnothing(session) && compact!(session, agent)

        # ── Input guardrails ────────────────────────────────────────────────────
        effective_input = try
            _run_guardrails(agent.guardrails, :input, input, agent.name, verbose)
        catch e
            e isa GuardrailBlocked || rethrow()
            resolved = _resolve_instructions(agent.instructions, session, agent)
            return _finish!(
                e.reason,
                turn,
                t_start,
                session,
                PT.AbstractMessage[PT.SystemMessage(resolved), PT.UserMessage(input)],
                2,
                hooks,
                agent,
                store,
            )
        end

        # Seed the conversation: system prompt (+ skill metadata + memory) + session history + user message
        system_prompt =
            _resolve_instructions(agent.instructions, session, agent) *
            _skills_prompt(all_skills) *
            _memory_prompt(agent.memory, effective_input, session)
        conversation = PT.AbstractMessage[
            PT.SystemMessage(system_prompt),
            (isnothing(session) ? PT.AbstractMessage[] : session.history)...,
            PT.UserMessage(effective_input),
        ]
        n_seeded = length(conversation)

        for iteration in 1:agent.max_iterations
            verbose && println("[$(agent.name)] iteration $iteration")

            # ── Structured output with no tools: skip tool loop entirely ───────
            if isnothing(agent.output_type) || !isempty(all_tools)
                if !isnothing(hooks.before_llm_call)
                    conversation = hooks.before_llm_call(agent, iteration, conversation)
                end
                _acquire_rate_limit!(agent.model)

                conversation = _with_retry(agent.retry, agent.name) do
                    @mock PT.aitools(
                        conversation;
                        tools=all_tools,
                        model=agent.model,
                        return_all=true,
                        verbose=false,
                        agent.api_kwargs...,
                    )
                end

                last_msg = conversation[end]
                turn.llm_calls += 1
                _accumulate_usage!(turn, last_msg)
                _fire(hooks.after_llm_call, agent, iteration, last_msg)

                # Tool call response → execute each tool, append results, loop
                if last_msg isa PT.AIToolRequest && !isempty(last_msg.tool_calls)
                    # should_interrupt: scan all pending tool calls before executing any.
                    # Collect every flagged call so the human sees the full batch at once.
                    if !isnothing(hooks.should_interrupt)
                        flagged = filter(last_msg.tool_calls) do t
                            hooks.should_interrupt(t.name, something(t.args, Dict()))
                        end
                        if !isempty(flagged)
                            names = join([t.name for t in flagged], ", ")
                            if !isnothing(approval_channel)
                                # Non-blocking path: pause mid-loop and wait for a
                                # response on the channel. The agent holds all state —
                                # no re-run needed. The caller puts "approve" to
                                # proceed, any other string to redirect, or closes
                                # the channel to abort.
                                verbose && println(
                                    "[$(agent.name)] waiting for approval: $(names)"
                                )
                                status = timedwait(approval_timeout) do
                                    isready(approval_channel) || !isopen(approval_channel)
                                end
                                if status == :timed_out
                                    throw(ApprovalTimeout(flagged, approval_timeout))
                                end
                                if !isopen(approval_channel)
                                    error(
                                        "[$(agent.name)] approval_channel closed — aborting"
                                    )
                                end
                                response = take!(approval_channel)
                                # Inject the human's response into the conversation
                                # so the agent has context when it continues
                                push!(conversation, PT.UserMessage(response))
                                if lowercase(strip(response)) != "approve"
                                    # Redirect: skip remaining tool calls this
                                    # iteration and let the LLM re-plan
                                    continue
                                end
                            else
                                # Blocking path: throw and let the caller handle it
                                throw(
                                    HumanInterrupt(
                                        flagged; message="About to call: $(names)"
                                    ),
                                )
                            end
                        end
                    end

                    # ── Execute tools (parallel when safe, sequential otherwise) ──
                    # return_direct and Handoff require immediate short-circuit, so
                    # any batch containing those tools falls back to sequential.
                    has_special = any(last_msg.tool_calls) do t
                        obj = get(tool_map, t.name, nothing)
                        !isnothing(obj) &&
                            (_is_return_direct(obj) || !isempty(agent.sub_agents))
                    end
                    use_parallel = !has_special && length(last_msg.tool_calls) > 1

                    if use_parallel
                        # ── Parallel path ─────────────────────────────────────────
                        verbose && println(
                            "[$(agent.name)] executing $(length(last_msg.tool_calls)) tools in parallel",
                        )
                        for t in last_msg.tool_calls
                            _fire(hooks.on_tool_call, agent, t.name, t.args)
                        end

                        tasks = map(last_msg.tool_calls) do t
                            Threads.@spawn begin
                                try
                                    (dispatch_tool(tool_map, t.name, t.args), nothing)
                                catch e
                                    err_str = sprint(showerror, e)
                                    ("Error: $(err_str)", err_str)
                                end
                            end
                        end

                        # Collect results in order
                        for (i, tool_msg) in enumerate(last_msg.tool_calls)
                            result, err = fetch(tasks[i])
                            verbose &&
                                println("[$(agent.name)] tool done: $(tool_msg.name)")

                            push!(
                                turn.tool_calls,
                                if isnothing(err)
                                    ToolEvent(
                                        tool_msg.name,
                                        something(tool_msg.args, Dict{Symbol,Any}()),
                                        result,
                                    )
                                else
                                    ToolEvent(
                                        tool_msg.name,
                                        something(tool_msg.args, Dict{Symbol,Any}());
                                        error=err,
                                    )
                                end,
                            )

                            _fire(hooks.on_tool_result, agent, tool_msg.name, result)

                            tool_obj = get(tool_map, tool_msg.name, nothing)
                            result_str = string(result)
                            limit = if isnothing(tool_obj)
                                agent.max_tool_output
                            else
                                _effective_max_output(tool_obj, agent)
                            end
                            tool_msg.content = _trim_tool_output(result_str, limit)
                            push!(conversation, tool_msg)

                            if !isnothing(tool_obj) &&
                                _is_return_artifact(tool_obj) &&
                                isnothing(err) &&
                                !isnothing(session) &&
                                result isa AbstractString &&
                                isfile(result)
                                register_artifact!(
                                    session,
                                    string(result);
                                    metadata=Dict{String,Any}("tool" => tool_msg.name),
                                    store=store,
                                )
                            end
                        end
                    else
                        # ── Sequential path ───────────────────────────────────────
                        for tool_msg in last_msg.tool_calls
                            verbose &&
                                println("[$(agent.name)] calling tool: $(tool_msg.name)")
                            _fire(hooks.on_tool_call, agent, tool_msg.name, tool_msg.args)

                            result = nothing
                            err = nothing
                            try
                                result = dispatch_tool(
                                    tool_map, tool_msg.name, tool_msg.args
                                )
                            catch e
                                err = sprint(showerror, e)
                                result = "Error: $(err)"
                            end

                            push!(
                                turn.tool_calls,
                                if isnothing(err)
                                    ToolEvent(
                                        tool_msg.name,
                                        something(tool_msg.args, Dict{Symbol,Any}()),
                                        result,
                                    )
                                else
                                    ToolEvent(
                                        tool_msg.name,
                                        something(tool_msg.args, Dict{Symbol,Any}());
                                        error=err,
                                    )
                                end,
                            )

                            _fire(hooks.on_tool_result, agent, tool_msg.name, result)

                            # Handoff: surface immediately so run_pipeline! can reroute
                            if result isa Handoff
                                _finish!(
                                    result,
                                    turn,
                                    t_start,
                                    session,
                                    conversation,
                                    n_seeded,
                                    hooks,
                                    agent,
                                    store,
                                )
                                return result
                            end

                            tool_obj = get(tool_map, tool_msg.name, nothing)
                            result_str = string(result)
                            limit = if isnothing(tool_obj)
                                agent.max_tool_output
                            else
                                _effective_max_output(tool_obj, agent)
                            end
                            tool_msg.content = _trim_tool_output(result_str, limit)
                            push!(conversation, tool_msg)

                            # return_artifact: register result as a session artifact
                            if !isnothing(tool_obj) &&
                                _is_return_artifact(tool_obj) &&
                                isnothing(err) &&
                                !isnothing(session) &&
                                result isa AbstractString &&
                                isfile(result)
                                register_artifact!(
                                    session,
                                    string(result);
                                    metadata=Dict{String,Any}("tool" => tool_msg.name),
                                    store=store,
                                )
                            end

                            # return_direct: skip the next LLM call and return immediately.
                            if !isnothing(tool_obj) &&
                                _is_return_direct(tool_obj) &&
                                isnothing(err)
                                verbose && println(
                                    "[$(agent.name)] return_direct — short-circuiting after $(tool_msg.name)",
                                )
                                return _finish!(
                                    result,
                                    turn,
                                    t_start,
                                    session,
                                    conversation,
                                    n_seeded,
                                    hooks,
                                    agent,
                                    store,
                                )
                            end
                        end
                    end
                    continue
                end
            end

            # ── Final response reached ─────────────────────────────────────────
            if !isnothing(agent.output_type)
                result = _extract_output(agent, conversation, verbose)
                return _finish!(
                    result,
                    turn,
                    t_start,
                    session,
                    conversation,
                    n_seeded,
                    hooks,
                    agent,
                    store,
                )
            end

            # If streaming is requested, re-run this final call with a StreamCallback
            # so tokens flow to on_token as they are generated. We drop the last message
            # (the blocking response we just got) and redo the call in streaming mode.
            if !isnothing(on_token)
                conversation = _stream_final!(
                    conversation[1:(end - 1)], agent, all_tools, on_token
                )
                turn.llm_calls += 1
                _accumulate_usage!(turn, conversation[end])
            end

            last_msg = conversation[end]
            result = if last_msg isa PT.AIMessage
                something(last_msg.content, "")
            elseif last_msg isa PT.AIToolRequest
                something(last_msg.content, "")
            else
                println(stderr, "[$(agent.name)] unexpected message type: $(typeof(last_msg))")
                break
            end

            result = _apply_output_guardrails(
                result,
                agent,
                turn,
                t_start,
                session,
                conversation,
                n_seeded,
                hooks,
                store,
                verbose,
            )
            return _finish!(
                result, turn, t_start, session, conversation, n_seeded, hooks, agent, store
            )
        end

        println(stderr, "[$(agent.name)] reached max_iterations ($(agent.max_iterations))")

        if !isnothing(agent.output_type)
            result = _extract_output(agent, conversation, verbose)
            return _finish!(
                result, turn, t_start, session, conversation, n_seeded, hooks, agent, store
            )
        end

        for msg in Iterators.reverse(conversation)
            if msg isa PT.AIMessage
                return _finish!(
                    something(msg.content, ""),
                    turn,
                    t_start,
                    session,
                    conversation,
                    n_seeded,
                    hooks,
                    agent,
                    store,
                )
            end
            if msg isa PT.AIToolRequest && !isnothing(msg.content)
                return _finish!(
                    string(msg.content),
                    turn,
                    t_start,
                    session,
                    conversation,
                    n_seeded,
                    hooks,
                    agent,
                    store,
                )
            end
        end
        return _finish!(
            "", turn, t_start, session, conversation, n_seeded, hooks, agent, store
        )

    finally
        _close_mcp_clients(mcp_clients)
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ──────────────────────────────────────────────────────────────────────────────

# Run output guardrails on a string result. Returns either the (possibly
# modified) string, or the block reason if a guardrail fires.
function _apply_output_guardrails(
    result,
    agent::Agent,
    turn,
    t_start,
    session,
    conversation,
    n_seeded,
    hooks,
    store,
    verbose,
)
    result isa String || return result   # only applies to string outputs
    isempty(agent.guardrails) && return result
    try
        _run_guardrails(agent.guardrails, :output, result, agent.name, verbose)
    catch e
        e isa GuardrailBlocked || rethrow()
        e.reason
    end
end

# Finalise a turn: stamp elapsed time, save to session, fire on_complete, return result.
function _finish!(
    result,
    turn::TurnEvent,
    t_start::Float64,
    session,
    conversation,
    n_seeded::Int,
    hooks::AgentHooks,
    agent::Agent,
    store::Union{AbstractSessionStore,Nothing}=nothing,
)
    turn.output = result
    turn.elapsed = time() - t_start

    if !isnothing(session)
        lock(session.lock) do
            _save_history!(session, conversation, n_seeded)
            push!(session.events, turn)
        end
        # Auto-persist if a store is configured
        !isnothing(store) && save!(store, session)
    end

    _fire(hooks.on_complete, agent, result)
    return result
end

# Stream the final LLM response token-by-token.
# Uses a Channel as the StreamCallback sink — PT writes each token chunk into it,
# a background task drains the channel and calls on_token for each chunk.
# Returns the completed conversation (same shape as the blocking PT.aitools call).
function _stream_final!(conversation, agent::Agent, all_tools, on_token::Function)
    ch = Channel{String}(256)
    # Drain the channel in a background task so PT can keep writing without blocking
    drain = Threads.@spawn begin
        for tok in ch
            ;
            on_token(tok);
        end
    end
    cb = PT.StreamCallback(; out=ch)

    # PT.aitools does not support streamcallback — use aigenerate for the final
    # streaming pass (tool calls have already been resolved by this point).
    _acquire_rate_limit!(agent.model)
    result = _with_retry(agent.retry, agent.name) do
        @mock PT.aigenerate(
            conversation;
            model=agent.model,
            return_all=true,
            verbose=false,
            streamcallback=cb,
            agent.api_kwargs...,
        )
    end

    close(ch)
    wait(drain)
    return result
end

# Pass the full conversation to aiextract so the model has all context
# (including any tool results) when generating the structured response.
# On parse failure, feed the error back to the LLM and retry up to
# retry.max_parse_retries times before giving up.
function _extract_output(agent::Agent, conversation, verbose::Bool)
    verbose &&
        println("[$(agent.name)] extracting structured output as $(agent.output_type)")

    ctx = copy(conversation)

    for attempt in 1:(agent.retry.max_parse_retries + 1)
        _acquire_rate_limit!(agent.model)
        msg = _with_retry(agent.retry, agent.name) do
            @mock PT.aiextract(
                ctx;
                return_type=agent.output_type,
                model=agent.model,
                verbose=false,
                agent.api_kwargs...,
            )
        end

        # Success: content is the expected type
        if msg.content isa agent.output_type
            return msg.content
        end

        # Parse failed — content is nothing or wrong type
        parse_err = if isnothing(msg.content)
            "aiextract returned nothing — the response could not be parsed into $(agent.output_type)."
        else
            "aiextract returned a $(typeof(msg.content)) instead of the expected $(agent.output_type)."
        end

        if attempt > agent.retry.max_parse_retries
            error(
                "[$(agent.name)] structured output parse failed after $(attempt) attempt(s): $(parse_err)",
            )
        end

        verbose && println(
            "[$(agent.name)] parse attempt $(attempt) failed — re-prompting. $(parse_err)",
        )

        # Feed the error back so the model can correct its response
        push!(
            ctx,
            PT.UserMessage(
                "Your previous response could not be parsed into the required format. " *
                "Error: $(parse_err)\n" *
                "Please respond again, strictly following the $(agent.output_type) schema.",
            ),
        )
    end
end
