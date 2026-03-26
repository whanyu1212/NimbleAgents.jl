###############################################################################
# external_agent/parser.jl — Claude Code stream-json result parsing
###############################################################################

# Parse Claude Code's stream-json output to extract the final result.
# Looks for the last `{"type":"result",...}` line and extracts the result field.
function _parse_claude_code_result(lines::Vector{String})
    # Walk backwards to find the result line
    for i in length(lines):-1:1
        line = strip(lines[i])
        isempty(line) && continue
        try
            event = JSON3.read(line)
            if get(event, :type, nothing) == "result"
                is_error = get(event, :is_error, false)
                result = get(event, :result, nothing)
                cost = get(event, :total_cost_usd, nothing)
                subtype = get(event, :subtype, "")
                session_id = get(event, :session_id, nothing)

                parts = String[]
                if is_error || subtype != "success"
                    push!(parts, "Error ($(subtype)):")
                end
                if !isnothing(result) && !isempty(string(result))
                    push!(parts, string(result))
                end
                if !isnothing(cost)
                    push!(parts, "\n[Cost: \$$(round(cost; digits=4))]")
                end
                if !isnothing(session_id)
                    push!(parts, "[Session: $(session_id)]")
                end
                return join(parts, " ")
            end
        catch
            continue
        end
    end

    # No result line found — return raw output
    join(lines, "\n")
end
