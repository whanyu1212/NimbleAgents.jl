###############################################################################
# test_docstrings.jl — exported API docs + Julia-style docstring signatures
###############################################################################

const _DOC_DEF_PREFIXES = (
    "function ",
    "macro ",
    "struct ",
    "mutable struct ",
    "abstract type ",
    "Base.@kwdef struct ",
    "@tool ",
)

function _is_definition_line(line::String)
    s = strip(line)
    any(startswith(s, p) for p in _DOC_DEF_PREFIXES)
end

function _collect_docstyle_violations(src_root::String)
    violations = NamedTuple{
        (:file, :line, :first, :definition),Tuple{String,Int,String,String}
    }[]
    for (root, _, files) in walkdir(src_root)
        for f in files
            endswith(f, ".jl") || continue
            path = joinpath(root, f)
            lines = readlines(path)
            i = 1
            while i <= length(lines)
                if strip(lines[i]) == "\"\"\""
                    start = i
                    doc_lines = String[]
                    i += 1
                    while i <= length(lines) && strip(lines[i]) != "\"\"\""
                        push!(doc_lines, lines[i])
                        i += 1
                    end
                    i > length(lines) && break

                    j = i + 1
                    while j <= length(lines)
                        s = strip(lines[j])
                        if isempty(s) || startswith(s, "#")
                            j += 1
                        else
                            break
                        end
                    end

                    if j <= length(lines) && _is_definition_line(lines[j])
                        idx = findfirst(l -> !isempty(strip(l)), doc_lines)
                        if !isnothing(idx)
                            first_raw = doc_lines[idx]
                            if !startswith(first_raw, "    ")
                                push!(
                                    violations,
                                    (
                                        file=path,
                                        line=start + idx,
                                        first=strip(first_raw),
                                        definition=strip(lines[j]),
                                    ),
                                )
                            end
                        end
                    end
                end
                i += 1
            end
        end
    end
    violations
end

function _has_doc(mod::Module, sym::Symbol)::Bool
    if isdefined(Base.Docs, :hasdoc)
        hasdoc = getfield(Base.Docs, :hasdoc)
        try
            return hasdoc(mod, sym)
        catch
            # Fall back to older doc lookup paths below.
        end
    end

    if isdefined(Base.Docs, :Binding)
        try
            binding = Base.Docs.Binding(mod, sym)
            return !isnothing(Base.Docs.doc(binding))
        catch
            # Fall back to value-based lookup below.
        end
    end

    if !startswith(String(sym), "@") && isdefined(mod, sym)
        try
            return !isnothing(Base.Docs.doc(getproperty(mod, sym)))
        catch
            return false
        end
    end
    return false
end

@testset "Exported API docstrings present" begin
    syms = Base.names(NimbleAgents; all=false, imported=false)
    missing = String[]
    for s in syms
        if !startswith(String(s), "@")
            value = getproperty(NimbleAgents, s)
            value isa NimbleAgents.AbstractTool && continue
        end
        if !_has_doc(NimbleAgents, s)
            push!(missing, String(s))
        end
    end
    @test isempty(missing)
end

@testset "Docstrings use Julia signature style" begin
    src_root = normpath(joinpath(@__DIR__, "..", "..", "src"))
    violations = _collect_docstyle_violations(src_root)
    @test isempty(violations)
end

@testset "Key API docstrings include usage sections" begin
    src_root = normpath(joinpath(@__DIR__, "..", ".."))
    required_sections = Dict(
        "src/agent/run_loop.jl" => ["# Arguments", "# Example"],
        "src/repl/chat_loop.jl" => ["# Slash Commands", "# Arguments", "# Example"],
        "src/web/server/serve.jl" => ["# Arguments", "# Returns", "# Example"],
        "src/storage/artifacts/store_interface.jl" => [
            "save!(store, session) -> Session",
            "load(store, session_id) -> Union{Session, Nothing}",
            "list(store; app_name=nothing, user_id=nothing) -> Vector{String}",
            "cleanup!(store; max_age, before) -> Int",
            "# Arguments",
            "# Returns",
        ],
        "src/tracer/printing.jl" => ["print_trace(trace; io=stdout)", "# Arguments"],
        "src/tracer/io.jl" => [
            "save_trace(trace, path)",
            "load_trace(path) -> Dict{String, Any}",
            "# Arguments",
            "# Returns",
        ],
    )

    for (relpath, sections) in required_sections
        path = joinpath(src_root, relpath)
        txt = read(path, String)
        for section in sections
            @test occursin(section, txt)
        end
    end
end
