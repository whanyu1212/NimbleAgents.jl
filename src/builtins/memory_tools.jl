###############################################################################
# builtins/memory_tools.jl — save_memory and recall_memory built-in tools
###############################################################################

import JSON3

const save_memory_tool = NimbleTool(
    name        = "save_memory",
    description = """Store a fact or preference in long-term memory for the current user.
Use this when the user asks you to remember something, states a preference, or shares
a fact that would be useful in future conversations.

The memory is scoped to the current user and application — it persists across sessions.""",
    parameters  = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "content" => Dict{String,Any}(
                "type"        => "string",
                "description" => "The fact or preference to remember. Be concise and specific.",
            ),
            "metadata" => Dict{String,Any}(
                "type"        => "string",
                "description" => "Optional JSON object with metadata tags (e.g. {\"category\": \"preference\"}). Omit if not needed.",
            ),
        ),
        "required" => ["content"],
    ),
    callable = (args::Dict{Symbol,<:Any}) -> begin
        content = args[:content]::String

        memory  = get(task_local_storage(), :_current_memory,  nothing)
        session = get(task_local_storage(), :_current_session, nothing)

        isnothing(memory) &&
            return "Error: no memory service configured — set `memory` on the Agent to use this tool."

        user_id    = isnothing(session) ? "default" : session.user_id
        app_name   = isnothing(session) ? "NimbleAgents" : session.app_name
        session_id = isnothing(session) ? nothing : session.id

        meta = if haskey(args, :metadata) && !isnothing(args[:metadata])
            try
                Dict{String, Any}(JSON3.read(args[:metadata], Dict{String, Any}))
            catch
                Dict{String, Any}()
            end
        else
            Dict{String, Any}()
        end

        entry = add_memory!(memory, content;
            user_id    = user_id,
            app_name   = app_name,
            metadata   = meta,
            session_id = session_id,
        )
        "Memory saved (id: $(entry.id)): $(entry.content)"
    end,
)

const recall_memory_tool = NimbleTool(
    name        = "recall_memory",
    description = """Search long-term memory for facts relevant to a query.
Use this when you need to recall something the user previously told you, or when
answering a question that might depend on stored preferences or facts.""",
    parameters  = Dict{String,Any}(
        "type"       => "object",
        "properties" => Dict{String,Any}(
            "query" => Dict{String,Any}(
                "type"        => "string",
                "description" => "The search query — describe what you are looking for.",
            ),
            "top_k" => Dict{String,Any}(
                "type"        => "integer",
                "description" => "Maximum number of results to return (default: 5).",
            ),
        ),
        "required" => ["query"],
    ),
    callable = (args::Dict{Symbol,<:Any}) -> begin
        query = args[:query]::String
        top_k = get(args, :top_k, 5)
        top_k = top_k isa Integer ? Int(top_k) : 5

        memory  = get(task_local_storage(), :_current_memory,  nothing)
        session = get(task_local_storage(), :_current_session, nothing)

        isnothing(memory) &&
            return "Error: no memory service configured — set `memory` on the Agent to use this tool."

        user_id  = isnothing(session) ? "default" : session.user_id
        app_name = isnothing(session) ? "NimbleAgents" : session.app_name

        results = search_memory(memory, query;
            user_id  = user_id,
            app_name = app_name,
            top_k    = top_k,
        )

        isempty(results) && return "No memories found matching: $(query)"

        lines = ["Found $(length(results)) relevant memory(s):"]
        for (i, entry) in enumerate(results)
            push!(lines, "$(i). $(entry.content)")
        end
        join(lines, "\n")
    end,
)
