###############################################################################
# storage/memory/prompt.jl — memory-based system prompt augmentation
###############################################################################

"""
    _memory_prompt(memory, input, session) -> String

Build a system prompt fragment with relevant memories for the current input.
Returns `""` if memory is nothing, session is nothing, or no results are found.
"""
function _memory_prompt(
    memory::Union{AbstractMemoryService,Nothing},
    input::String,
    session::Union{Session,Nothing},
)
    isnothing(memory) && return ""
    isnothing(session) && return ""

    results = search_memory(
        memory, input; user_id=session.user_id, app_name=session.app_name
    )
    isempty(results) && return ""

    lines = String[
        "",
        "---",
        "## Relevant Memories",
        "",
        "The following facts were recalled from previous interactions with this user:",
        "",
    ]
    for (i, entry) in enumerate(results)
        push!(lines, "$(i). $(entry.content)")
    end
    push!(lines, "")
    join(lines, "\n")
end
