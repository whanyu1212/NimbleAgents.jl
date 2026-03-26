###############################################################################
# test_source_layout.jl — source tree structure and file-size hygiene
###############################################################################

function _line_count(path::AbstractString)
    open(path, "r") do io
        count(_ -> true, eachline(io))
    end
end

@testset "Root source files stay as thin entrypoints" begin
    src_root = normpath(joinpath(@__DIR__, "..", "..", "src"))
    wrappers = filter(
        p -> endswith(p, ".jl") && basename(p) != "NimbleAgents.jl",
        readdir(src_root; join=true),
    )

    too_large = String[]
    for path in wrappers
        _line_count(path) <= 80 || push!(too_large, path)
    end
    @test isempty(too_large)
end

@testset "No source file becomes monolithic again" begin
    src_root = normpath(joinpath(@__DIR__, "..", "..", "src"))
    files = String[]
    for (root, _, names) in walkdir(src_root)
        for name in names
            endswith(name, ".jl") || continue
            push!(files, joinpath(root, name))
        end
    end

    # Soft cap intended to prevent runaway growth while allowing complex modules.
    too_large = String[]
    for path in files
        _line_count(path) <= 240 || push!(too_large, path)
    end
    @test isempty(too_large)
end
