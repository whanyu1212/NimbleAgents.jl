###############################################################################
# tracer/constructors.jl — Trace constructors and aggregate computations
###############################################################################

function Trace(turns::Vector{TurnEvent})
    isempty(turns) && return Trace(turns, 0, 0, 0, 0, 0, 0.0, 0, 0, 0.0, String[])

    total_in = sum(t.input_tokens for t in turns)
    total_out = sum(t.output_tokens for t in turns)
    total_cache_read = sum(t.cache_read_tokens for t in turns)
    total_cache_write = sum(t.cache_write_tokens for t in turns)
    total_cost = sum(t.cost for t in turns)
    total_llm = sum(t.llm_calls for t in turns)
    total_tool = sum(length(t.tool_calls) for t in turns)
    duration = sum(t.elapsed for t in turns)

    seen = Set{String}()
    agents = String[]
    for t in turns
        t.agent in seen && continue
        push!(seen, t.agent)
        push!(agents, t.agent)
    end

    Trace(
        turns,
        total_in,
        total_out,
        total_cache_read,
        total_cache_write,
        total_in + total_out,
        total_cost,
        total_llm,
        total_tool,
        duration,
        agents,
    )
end

Trace(session::Session) = Trace(copy(session.events))
