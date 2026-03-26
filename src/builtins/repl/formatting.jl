###############################################################################
# builtins/repl/formatting.jl — eval result formatting helpers
###############################################################################

# Format an eval result for the LLM:
# - Primitives and collections: repr()
# - Functions / Modules / DataTypes: suppress (return "")
# - Anything that responds to savefig (Plots, Makie, etc.): save to a temp
#   file and return the path so the agent knows where to find it.
function _format_result(result)::String
    # Suppress implementation-detail types that are noise for the LLM
    result isa Function && return ""
    result isa Module && return ""
    result isa DataType && return ""

    # Plot-like: anything that has a savefig method defined for it.
    # We check without importing Plots/Makie — just look for the method.
    if _has_savefig(result)
        path = tempname() * ".png"
        try
            # Call savefig via the generic name — works for Plots, Makie, etc.
            savefig_fn = getfield(parentmodule(typeof(result)), :savefig)
            savefig_fn(result, path)
            # Register as session artifact if a session is active
            session = get(task_local_storage(), :_current_session, nothing)
            store = get(task_local_storage(), :_current_store, nothing)
            if !isnothing(session)
                register_artifact!(
                    session,
                    path;
                    name="plot_" * basename(path),
                    store=store,
                    metadata=Dict{String,Any}("source" => "eval_julia"),
                )
            end
            return "Plot saved to: $(path)"
        catch e
            return "Plot result (could not save: $(sprint(showerror, e)))"
        end
    end

    # Everything else: use repr, but guard against repr() itself throwing
    try
        repr(result)
    catch
        "(result of type $(typeof(result)))"
    end
end

# Check if a savefig method exists for this value's type without importing
# any plotting package — avoids hard dependencies.
function _has_savefig(result)::Bool
    T = typeof(result)
    m = parentmodule(T)
    isdefined(m, :savefig) || return false
    fn = getfield(m, :savefig)
    !isempty(methods(fn, (T, String))) || !isempty(methods(fn, (T, AbstractString)))
end
