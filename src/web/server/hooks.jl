###############################################################################
# web/server/hooks.jl — web-specific agent hook adapters
###############################################################################

function _web_hooks(run::RunState)
    AgentHooks(;
        on_tool_call=(agent, name, args) -> _push_event(
            run, "tool_call", Dict("name" => name, "args" => something(args, Dict()))
        ),
        on_tool_result=(agent, name, result) -> _push_event(
            run, "tool_result", Dict("name" => name, "result" => string(result))
        ),
    )
end
