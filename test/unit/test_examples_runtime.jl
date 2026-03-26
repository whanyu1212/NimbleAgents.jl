###############################################################################
# test_examples_runtime.jl — runtime smoke for all example scripts
###############################################################################

function _example_files(examples_root::AbstractString)
    files = String[]
    for (root, _, names) in walkdir(examples_root)
        for name in names
            endswith(name, ".jl") || continue
            startswith(name, "._") && continue
            push!(files, joinpath(root, name))
        end
    end
    sort!(files)
    files
end

function _install_term_stubs!(m::Module)
    Core.eval(
        m, quote
            struct Panel
                content::Any
                opts::Dict{Symbol,Any}
            end
            Panel(content; kwargs...) = Panel(content, Dict{Symbol,Any}(kwargs))
            Base.show(io::IO, p::Panel) = print(io, p.content)

            tprintln(args...) = println(args...)

            struct ProgressBar end
            function addjob!(::ProgressBar; N::Integer=1, description::AbstractString="")
                (N=N, description=String(description), progress=Ref(0))
            end
            update!(job) = nothing
            with(::ProgressBar, f::Function) = f()
            with(f::Function, ::ProgressBar) = f()

            struct Table
                data::Any
            end
            Base.show(io::IO, t::Table) = print(io, t.data)

            const Dates = (
                today=() -> "1970-01-01",
                format=(x, ::AbstractString) -> string(x),
            )
        end
    )
    nothing
end

function _prepare_example_source(path::AbstractString, src::String)
    # Examples load DotEnv and Term explicitly; for runtime smoke under the root
    # test environment we strip those imports and provide tiny local stubs.
    src = replace(src, r"(?m)^using DotEnv\s*$\n?" => "")
    src = replace(src, r"(?m)^DotEnv\.load!\(\)\s*$\n?" => "")
    src = replace(src, r"(?m)^import Term: Panel, tprintln\s*$\n?" => "")
    src = replace(
        src, r"(?m)^import Term\.Progress: ProgressBar, addjob!, update!, with\s*$\n?" => ""
    )
    src = replace(src, r"(?m)^import Term\.Tables: Table\s*$\n?" => "")
    src = replace(src, r"(?m)^using Dates: Dates\s*$\n?" => "")
    src = replace(src, r"(?m)^using HTTP: HTTP\s*$\n?" => "")
    src = replace(src, r"(?m)^using HTTP, JSON3\s*$\n?" => "using JSON3\n")

    # Avoid blocking forever in the web example during smoke execution.
    if endswith(path, joinpath("web", "web_ui.jl"))
        needle = "serve([chat_agent, research_agent, fs_agent, support_agent]; port=8080)"
        occursin(needle, src) || error("web_ui.jl changed; update smoke patch target")
        src = replace(src, needle => "println(\"[smoke] serve() suppressed\")")
    end

    # Avoid external MCP process startup in smoke mode.
    if endswith(path, joinpath("mcp", "langchain_docs.jl"))
        needle = "    mcp_servers=[langchain_mcp],"
        occursin(needle, src) ||
            error("langchain_docs.jl changed; update smoke patch target")
        src = replace(src, needle => "    mcp_servers=MCPServer[],")
    end

    src
end

function _last_user_prompt(conversation)::String
    msgs = conversation isa AbstractVector ? conversation : Any[conversation]
    for msg in Iterators.reverse(msgs)
        if msg isa NimbleAgents.UserMessage
            return String(msg.content)
        end
    end
    ""
end

function _mock_text(conversation)::String
    prompt = strip(replace(_last_user_prompt(conversation), r"\s+" => " "))
    isempty(prompt) && return "mock response"
    n = min(length(prompt), 80)
    "mock response: " * first(prompt, n)
end

function _emit_stream!(streamcallback, content::String)
    isnothing(streamcallback) && return nothing
    hasproperty(streamcallback, :out) || return nothing
    out = getproperty(streamcallback, :out)

    if out isa Channel
        try
            for tok in split(content, ' ')
                put!(out, tok * " ")
            end
        catch
            # Ignore channel lifecycle errors in smoke mode.
        end
    elseif out isa IO
        print(out, content)
    end
    nothing
end

function _mock_ai_message(conversation)
    content = _mock_text(conversation)
    NimbleAgents.AIMessage(;
        content=content,
        usage=NimbleAgents.TokenUsage(;
            input_tokens=32, output_tokens=12, cache_read_tokens=0, cache_write_tokens=0
        ),
        tokens=(32, 12),
        elapsed=0.001,
    )
end

function _mock_aitools(
    conversation; return_all::Bool=false, streamcallback=nothing, kwargs...
)
    msg = _mock_ai_message(conversation)
    _emit_stream!(streamcallback, String(msg.content))
    if return_all
        seed = conversation isa AbstractVector ? copy(conversation) : Any[conversation]
        return vcat(seed, [msg])
    end
    msg
end

function _mock_aigenerate(
    conversation; return_all::Bool=false, streamcallback=nothing, kwargs...
)
    msg = _mock_ai_message(conversation)
    _emit_stream!(streamcallback, String(msg.content))
    if return_all
        seed = conversation isa AbstractVector ? copy(conversation) : Any[conversation]
        return vcat(seed, [msg])
    end
    msg
end

function _mock_extract_content(::Type{T}) where {T}
    T === String && return "mock structured output"
    T <: Number && return zero(T)
    T <: AbstractDict && return Dict{String,Any}()
    T <: AbstractVector && return T()
    try
        return T()
    catch
        return nothing
    end
end

function _mock_aiextract(conversation; return_type::Type=Any, kwargs...)
    NimbleAgents.AIMessage(; content=_mock_extract_content(return_type))
end

function _with_mocked_llm(f::Function)
    old_aitools = NimbleAgents._set_aitools_override!(_mock_aitools)
    old_aigenerate = NimbleAgents._set_aigenerate_override!(_mock_aigenerate)
    old_aiextract = NimbleAgents._set_aiextract_override!(_mock_aiextract)
    try
        return f()
    finally
        NimbleAgents._set_aitools_override!(old_aitools)
        NimbleAgents._set_aigenerate_override!(old_aigenerate)
        NimbleAgents._set_aiextract_override!(old_aiextract)
    end
end

function _run_example_smoke(path::AbstractString)
    src = _prepare_example_source(path, read(path, String))
    m = Module(gensym(:ExampleSmoke))
    _install_term_stubs!(m)

    mktempdir() do tmp
        cd(tmp) do
            redirect_stdout(devnull) do
                redirect_stderr(devnull) do
                    Base.include_string(m, src, String(path))
                end
            end
        end
    end
    nothing
end

@testset "Examples execute with mocked LLM runtime" begin
    examples_root = normpath(joinpath(@__DIR__, "..", "..", "examples"))
    files = _example_files(examples_root)
    @test !isempty(files)

    failures = Pair{String,String}[]

    _with_mocked_llm() do
        withenv(
            "NIMBLEAGENTS_EXAMPLE_MODEL" => nothing,
            "NIMBLEAGENTS_EXAMPLE_PROVIDER" => nothing,
            "OPENAI_API_KEY" => "smoke-openai-key",
            "GOOGLE_API_KEY" => nothing,
            "GEMINI_API_KEY" => nothing,
            "TAVILY_API_KEY" => "smoke-key",
        ) do
            for path in files
                try
                    _run_example_smoke(path)
                catch e
                    push!(failures, String(path) => sprint(showerror, e, catch_backtrace()))
                end
            end
        end
    end

    if !isempty(failures)
        for (path, err) in failures
            @info "example runtime smoke failure" path err
        end
    end
    @test isempty(failures)
end
