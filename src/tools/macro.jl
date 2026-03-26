###############################################################################
# tools/macro.jl — @tool macro
###############################################################################

"""
    @tool [return_direct=true] function f(args...) ... end

Define a Julia function and automatically register it as a `NimbleTool` (with
name, description, and JSON parameter schema inferred from the function
signature and its docstring).

A variable `<funcname>_tool` is created in the calling scope holding the
resulting `NimbleTool` object.

When `return_direct=true`, the agent loop short-circuits immediately after this
tool executes — its return value becomes the agent's final output without any
further LLM call. Useful for lookup tools, cache hits, or any tool whose result
is already the definitive answer.

# Example — standard tool
```julia
@tool function add(x::Int, y::Int)
    "Add two integers together."
    x + y
end
```

# Example — return_direct tool
```julia
@tool return_direct=true function lookup_faq(question::String)
    "Look up a frequently asked question. Returns a definitive answer."
    faq_db[question]
end
# When the agent calls lookup_faq, its result is returned immediately —
# no follow-up LLM call is made.
```
"""
macro tool(args...)
    return_direct = false
    return_artifact = false
    max_output = 0
    funcdef = nothing

    for arg in args
        if arg isa Expr && arg.head == :(=) && arg.args[1] == :return_direct
            return_direct = arg.args[2]
        elseif arg isa Expr && arg.head == :(=) && arg.args[1] == :return_artifact
            return_artifact = arg.args[2]
        elseif arg isa Expr && arg.head == :(=) && arg.args[1] == :max_output
            max_output = arg.args[2]
        elseif arg isa Expr && arg.head in (:function, :(=))
            funcdef = arg
        else
            error("@tool: unexpected argument: $arg")
        end
    end

    isnothing(funcdef) && error("@tool expects a function definition")

    # Extract the function name from the signature
    sig = funcdef.args[1]
    fname = if sig isa Expr && sig.head == :call
        sig.args[1]
    elseif sig isa Symbol
        sig
    else
        error("@tool: could not parse function name from: $sig")
    end

    bare_name = fname isa Expr ? fname.args[end] : fname
    tool_var = Symbol(bare_name, :_tool)
    tool_name = string(bare_name)

    # Extract description from the first string literal in the body
    body = funcdef.args[end]
    docs = nothing
    if body isa Expr && body.head == :block
        for stmt in body.args
            stmt isa LineNumberNode && continue
            if stmt isa String
                docs = stmt
            end
            break
        end
    end

    docs_expr = isnothing(docs) ? :nothing : docs

    schema_build = quote
        local _method = first(methods($(esc(fname))))
        local _arg_names = get_arg_names(_method)
        local _arg_types = get_arg_types(_method)

        local _properties = Dict{String,Any}()
        local _required = String[]
        for (n, t) in zip(_arg_names, _arg_types)
            _properties[string(n)] = to_json_schema(remove_null_types(t))
            is_required_field(t) && push!(_required, string(n))
        end

        local _params = Dict{String,Any}("type" => "object", "properties" => _properties)
        isempty(_required) || (_params["required"] = _required)

        $(esc(tool_var)) = NimbleTool(;
            name=($(tool_name)),
            parameters=_params,
            description=($(docs_expr)),
            callable=($(esc(fname))),
            return_direct=($(return_direct)),
            return_artifact=($(return_artifact)),
            max_output=($(max_output)),
        )
    end

    return Expr(:block, esc(funcdef), schema_build)
end
