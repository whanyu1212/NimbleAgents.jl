###############################################################################
# test_reference_docs.jl — ensure reference page covers all exports explicitly
###############################################################################

function _docs_symbols_from_reference(path::String)::Set{String}
    listed = Set{String}()
    in_docs = false

    for raw in eachline(path)
        line = strip(raw)
        if line == "```@docs"
            in_docs = true
            continue
        end
        if in_docs && startswith(line, "```")
            in_docs = false
            continue
        end
        if in_docs && !isempty(line)
            push!(listed, line)
        end
    end

    listed
end

@testset "Reference docs explicitly cover all exports" begin
    ref_path = normpath(joinpath(@__DIR__, "..", "..", "docs", "src", "reference.md"))
    listed = _docs_symbols_from_reference(ref_path)
    exported = Set(string.(Base.names(NimbleAgents; all=false, imported=false)))

    missing = sort!(collect(setdiff(exported, listed)))
    @test isempty(missing)
end

