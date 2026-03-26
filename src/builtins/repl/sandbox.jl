###############################################################################
# builtins/repl/sandbox.jl — persistent sandbox module management
###############################################################################

# Create or retrieve the persistent sandbox module for a session.
# Key in session.state: "_julia_sandbox"
function _get_sandbox(session_state::Union{Dict{String,Any},Nothing})::Module
    if !isnothing(session_state)
        if !haskey(session_state, "_julia_sandbox")
            session_state["_julia_sandbox"] = _new_sandbox()
        end
        return session_state["_julia_sandbox"]
    end
    _new_sandbox()   # stateless fallback: fresh module each call
end

function _new_sandbox()::Module
    # Anonymous module inheriting from Main so stdlib is available
    m = Module(gensym("NimbleSandbox"))
    # Bring Core and Base into scope
    Core.eval(m, :(using Base))
    m
end
