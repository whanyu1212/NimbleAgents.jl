# Changelog

All notable changes to this project will be documented in this file.

## 0.2.0 - 2026-03-26

### Changed
- Removed PromptingTools compatibility surface and completed migration to NimbleAgents-native types and provider wrappers.
- Decomposed large source files into focused modules for `agent`, `llm_core`, `external_agent`, `handoff`, `session`, `eval`, `mcp`, `repl`, `tracer`, and web server internals.
- Hardened test and docs quality gates around API surface and docstring style.

### Added
- Scheduled live integration workflow for provider-backed tests (OpenAI/Gemini), gated by repository secrets.

