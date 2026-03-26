###############################################################################
# llm_core/internal_helpers/conversation.jl — input conversation normalization
###############################################################################

function _as_conversation(conversation)
    if conversation isa AbstractString
        return AbstractMessage[UserMessage(String(conversation))]
    elseif conversation isa Vector{<:AbstractMessage}
        return conversation
    else
        throw(
            ArgumentError(
                "Expected a string or Vector{<:AbstractMessage}, got $(typeof(conversation))",
            ),
        )
    end
end
