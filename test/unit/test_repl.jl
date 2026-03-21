@testset "chat! — _chat_header" begin
    # Just verify it runs without error
    mktemp() do path, io
        redirect_stdout(io) do
            NimbleAgents._chat_header("TestBot")
        end
        flush(io)
        output = read(path, String)
        @test occursin("TestBot", output)
    end
end

@testset "chat! — _chat_help" begin
    mktemp() do path, io
        redirect_stdout(io) do
            NimbleAgents._chat_help()
        end
        flush(io)
        output = read(path, String)
        @test occursin("help", output)
        @test occursin("reset", output)
        @test occursin("exit", output)
    end
end

@testset "chat! — _chat_footer" begin
    session = Session(app_name="test", user_id="u")
    mktemp() do path, io
        redirect_stdout(io) do
            NimbleAgents._chat_footer(session)
        end
        flush(io)
        output = read(path, String)
        @test occursin("Session ended", output)
        @test occursin("0 turns", output)
    end
end

@testset "chat! — _chat_trace empty session" begin
    session = Session(app_name="test", user_id="u")
    mktemp() do path, io
        redirect_stdout(io) do
            NimbleAgents._chat_trace(session, "Bot")
        end
        flush(io)
        output = read(path, String)
        @test occursin("No turns recorded", output)
    end
end

@testset "chat! — docs bot agent construction" begin
    pkg_dir = pkgdir(NimbleAgents)
    @test pkg_dir !== nothing
    @test isdir(joinpath(pkg_dir, "src"))
    @test isdir(joinpath(pkg_dir, "docs"))
end
