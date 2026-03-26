###############################################################################
# test_examples_syntax.jl — syntax smoke for all example scripts
###############################################################################

@testset "Examples parse successfully" begin
    examples_root = normpath(joinpath(@__DIR__, "..", "..", "examples"))
    files = String[]
    for (root, _, names) in walkdir(examples_root)
        for name in names
            endswith(name, ".jl") || continue
            push!(files, joinpath(root, name))
        end
    end

    sort!(files)
    @test !isempty(files)

    failed = String[]
    for path in files
        src = read(path, String)
        try
            Meta.parseall(src)
        catch
            push!(failed, path)
        end
    end

    @test isempty(failed)
end
