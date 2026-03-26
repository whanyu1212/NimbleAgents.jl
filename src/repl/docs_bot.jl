###############################################################################
# repl/docs_bot.jl — no-arg chat! helper for NimbleAgents documentation bot
###############################################################################

"""
    chat!(; model)

Start a conversation with the built-in NimbleAgents documentation bot. It has
access to the framework's source code, docs, and examples via filesystem tools.

Requires an LLM API key — set `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or
`GOOGLE_API_KEY` in your environment or `.env` file.

# Arguments
- `model::String`: LLM model to use (default: `"gpt-4.1-nano"`).

# Example
```julia
using NimbleAgents
chat!()
# You> How do I add guardrails to an agent?
# NimbleAgents> ...
```
"""
function chat!(; model::String="gpt-4.1-nano")
    pkg_dir = pkgdir(@__MODULE__)
    if isnothing(pkg_dir)
        error(
            "Cannot locate NimbleAgents package directory. " *
            "Are you running from a development checkout?",
        )
    end

    agent = Agent(;
        name="NimbleAgents",
        model=model,
        instructions="""You are a documentation assistant for NimbleAgents.jl — a Julia framework for building AI agents.

You answer questions about the framework by reading its source code, documentation, and examples.
Always base your answers on the actual files — do not guess or hallucinate APIs.

The project root is: $(pkg_dir)

Key directories:
- $(pkg_dir)/docs/src/guide/ — user-facing documentation (Markdown)
- $(pkg_dir)/src/ — source code
- $(pkg_dir)/examples/ — runnable examples organized by topic
- $(pkg_dir)/CLAUDE.md — architecture overview and conventions
- $(pkg_dir)/README.md — project overview

When answering:
1. Search for relevant files first using grep or glob
2. Read the specific file(s) to get accurate information
3. Include code examples from the actual source when helpful
4. Reference file paths so the user can find more details""",
        tools=[read_file_tool, glob_tool, grep_tool, list_dir_tool],
    )

    chat!(agent)
end
