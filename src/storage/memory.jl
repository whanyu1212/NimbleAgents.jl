###############################################################################
# memory.jl — Semantic / long-term memory (cross-session fact storage)
#
# Agents can store and retrieve facts across sessions, scoped by user_id and
# app_name. Two backends: InMemoryMemoryService (keyword search, zero deps)
# and SQLiteMemoryService (persistent, in sqlite_memory.jl).
#
# Usage:
#   mem = InMemoryMemoryService()
#   agent = Agent(name="Bot", instructions="...", memory=mem)
#   session = Session(app_name="MyApp", user_id="alice")
#   run!(agent, "Remember that I prefer dark mode"; session=session)
###############################################################################

include("memory/types.jl")
include("memory/scoring.jl")
include("memory/in_memory.jl")
include("memory/prompt.jl")
