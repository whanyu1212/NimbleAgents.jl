# Examples

Examples are grouped by topic. Each file is self-contained and can be run from the repo root:

```bash
julia --project=examples examples/<category>/<file>.jl
```

LLM-calling examples support OpenAI and Gemini. By default they:
- use `OPENAI_API_KEY` when it is set
- otherwise use `GOOGLE_API_KEY`
- also accept `GEMINI_API_KEY` as an examples-level alias for `GOOGLE_API_KEY`

You can force a provider or model per run:

```bash
NIMBLEAGENTS_EXAMPLE_PROVIDER=gemini julia --project examples/agents/streaming.jl
NIMBLEAGENTS_EXAMPLE_MODEL=gemini-2.5-flash julia --project examples/agents/streaming.jl
```

---

## tools/
Examples focused on tool definition and dispatch.

| File | What it shows |
|---|---|
| `builtin_tools_demo.jl` | Using the built-in tool library (filesystem, shell, HTTP, REPL, artifacts) |
| `cli_tools_demo.jl` | Wrapping shell commands as agent tools with `CLITool` — no Julia wrapper needed |
| `repl_demo.jl` | `eval_julia_tool` — persistent Julia sandbox that retains state across turns |
| `return_direct.jl` | `return_direct=true` on a tool — agent loop short-circuits and returns the tool result directly |

---

## agents/
Single-agent features: streaming, lifecycle hooks, skills, memory, and evals.

| File | What it shows |
|---|---|
| `streaming.jl` | Real-time token streaming via the `on_token` callback |
| `hooks_walkthrough.jl` | Every `AgentHooks` callback (`before_llm_call`, `after_llm_call`, `on_tool_call`, `on_tool_result`, `on_complete`) with detailed inspection |
| `skills_demo.jl` | Filesystem-based skill packages — agents load instruction sets on demand via `read_skill` |
| `tracing_demo.jl` | Post-run trace inspection — `Trace(session)` to aggregate token usage, tool calls, and timing; `print_trace` and `save_trace` for export |
| `memory_demo.jl` | Cross-session memory with `InMemoryMemoryService` — store and recall facts across sessions |
| `eval_demo.jl` | Evaluation harness — `EvalCase`, metrics (`exact_match`, `tool_trajectory`), and `run_eval` |

Skill definitions live in `agents/skills/`:
- `julia-expert/` — Julia coding assistant persona
- `code-reviewer/` — code review checklist and style guidance

---

## multi_agent/
Coordination patterns across multiple agents.

| File | What it shows |
|---|---|
| `multi_agent.jl` | Two patterns: `agent_as_tool` (orchestrator calls specialists as tools) and `Handoff` (transfer control to another agent) |
| `research_pipeline.jl` | Full pipeline using all three primitives: `spawn_subagents`, `fan_out`, and `run_pipeline!` with handoffs |
| `claude_code_agent.jl` | `ExternalAgentTool` — delegate coding tasks to Claude Code (subprocess) with real-time progress streaming |

`claude_code_agent.jl` is an external CLI integration example. It does not use the built-in OpenAI/Gemini provider routing used by the other LLM examples.

---

## human_in_the_loop/
Three patterns for injecting human approval into the agent loop. They are listed in order of increasing complexity.

| File | What it shows |
|---|---|
| `hitl_should_interrupt.jl` | `should_interrupt` hook — synchronous gate; return `true` to pause before a tool call |
| `hitl_after_llm_call.jl` | `after_llm_call` hook — inspect the LLM message before tools are dispatched |
| `hitl_channel.jl` | `approval_channel` — non-blocking async approval; agent suspends until a value is sent on the channel |

---

## guardrails/
Input and output safety checks attached directly to an agent.

| File | What it shows |
|---|---|
| `input_guardrails.jl` | `Block` on SSN patterns, `Modify` to sanitise HTML, chaining multiple guardrails |
| `output_guardrails.jl` | `Block` on external links, `Modify` to truncate long responses, combining input + output guardrails |

---

## web/
Serving agents over HTTP.

| File | What it shows |
|---|---|
| `web_ui.jl` | Launch the built-in web UI with `serve(agent)` — exposes an OpenAI-compatible chat API and a browser interface |

> Requires multiple threads: `julia --project=examples -t 2 examples/web/web_ui.jl`

---

## mcp/
Connecting agents to external MCP servers.

| File | What it shows |
|---|---|
| `langchain_docs.jl` | stdio MCP server via `uvx mcpdoc` — agent queries the LangGraph documentation using MCP-discovered tools |

> Requires `uv` on your PATH (`brew install uv` or see https://github.com/astral-sh/uv).
