###############################################################################
# builtins/repl/tool.jl — eval_julia_tool definition
###############################################################################

"""
    eval_julia_tool

Built-in tool that evaluates Julia code in a persistent sandbox.

The sandbox persists for the lifetime of the session — variables, imports,
and function definitions all carry over between calls. The project environment
is active, so any package in `Project.toml` can be loaded with `using`.

Pair with a `Session` to get persistent state across turns:

```julia
session = Session(app_name="DataSession", user_id="alice")
agent   = Agent(
    name  = "DataBot",
    tools = [eval_julia_tool],
)
run!(agent, "Load DataFrames and create a DataFrame with columns a and b"; session=session)
run!(agent, "Now compute the mean of column a"; session=session)
```
"""
const eval_julia_tool = NimbleTool(;
    name="eval_julia",
    description="""Evaluate Julia code in a persistent sandbox and return the result.

The sandbox retains state across calls within the same session — variables,
imports, and function definitions all persist. The full project environment
is available: use `using PackageName` to load any package in Project.toml.

Use this tool to:
- Perform calculations and data analysis
- Load and manipulate data (DataFrames, arrays, etc.)
- Generate plots and visualisations
- Run any Julia code that requires computation

Stdout output and the return value of the last expression are both captured
and returned. Errors are caught and returned as strings.""",
    parameters=Dict{String,Any}(
        "type" => "object",
        "properties" => Dict{String,Any}(
            "code" => Dict{String,Any}(
                "type" => "string", "description" => "Julia code to evaluate."
            ),
            "timeout" => Dict{String,Any}(
                "type" => "number",
                "description" => "Timeout in seconds (default: 60).",
            ),
        ),
        "required" => ["code"],
    ),
    callable=(args::Dict{Symbol,<:Any}) -> begin
        code = get(args, :code, "")
        timeout = get(args, :timeout, 60)

        # Retrieve sandbox from session state if available.
        # session_state is injected via the _REPL_SESSION_STATE task-local
        # set by run! when eval_julia_tool is in the tool list.
        session_state = get(task_local_storage(), :_repl_session_state, nothing)
        sandbox = _get_sandbox(session_state)

        _eval_in_sandbox(sandbox, code, timeout)
    end,
)
