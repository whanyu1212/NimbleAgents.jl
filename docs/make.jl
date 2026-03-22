using Documenter, DocumenterVitepress
using NimbleAgents

makedocs(;
    modules=[NimbleAgents],
    authors="NimbleAgents contributors",
    repo="https://github.com/whanyu1212/NimbleAgents.jl/blob/{commit}{path}#{line}",
    sitename="NimbleAgents.jl",
    format=DocumenterVitepress.MarkdownVitepress(;
        repo="https://github.com/whanyu1212/NimbleAgents.jl",
        devbranch="develop",
        devurl="dev",
    ),
    draft=false,
    source="src",
    build="build",
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Guide" => [
            "Agents" => "guide/agents.md",
            "Tools" => "guide/tools.md",
            "Sessions & Artifacts" => "guide/sessions.md",
            "Multi-Agent Patterns" => "guide/multi_agent.md",
            "Guardrails" => "guide/guardrails.md",
            "MCP" => "guide/mcp.md",
            "Skills" => "guide/skills.md",
            "Tracer" => "guide/tracer.md",
        ],
        "Examples" => "examples.md",
        "Reference" => "reference.md",
    ],
)

DocumenterVitepress.deploydocs(;
    repo="github.com/whanyu1212/NimbleAgents.jl", push_preview=true, devbranch="develop"
)
