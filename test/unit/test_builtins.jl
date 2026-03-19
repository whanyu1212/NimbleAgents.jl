###############################################################################
# test_builtins.jl — unit tests for the built-in tool library
###############################################################################

# ── filesystem ────────────────────────────────────────────────────────────────

@testset "read_file_tool" begin
    tmp = tempname()
    write(tmp, "hello world\nline two\n")

    # positional callable
    result = read_file_tool.callable(tmp)
    @test occursin("hello world", result)
    @test occursin("line two", result)

    # Non-existent file → error message
    result2 = read_file_tool.callable("/nonexistent/file.txt")
    @test occursin("error", lowercase(result2))
end

@testset "write_file_tool" begin
    tmp = tempname()
    result = write_file_tool.callable(tmp, "written content")
    @test isfile(tmp)
    @test read(tmp, String) == "written content"
    @test occursin("written", lowercase(result)) || occursin(tmp, result)
end

@testset "edit_file_tool" begin
    tmp = tempname()
    write(tmp, "The quick brown fox jumps over the lazy dog.")

    result = edit_file_tool.callable(tmp, "lazy dog", "sleepy cat")
    @test read(tmp, String) == "The quick brown fox jumps over the sleepy cat."
    @test occursin("applied", lowercase(result))

    # Ambiguous replacement (pattern appears twice)
    write(tmp, "foo foo foo")
    result2 = edit_file_tool.callable(tmp, "foo", "bar")
    @test occursin("error", lowercase(result2))

    # String not found
    result3 = edit_file_tool.callable(tmp, "nonexistent string xyz", "replacement")
    @test occursin("not found", lowercase(result3)) ||
          occursin("error", lowercase(result3))
end

@testset "list_dir_tool" begin
    dir = mktempdir()
    write(joinpath(dir, "a.txt"), "")
    write(joinpath(dir, "b.jl"),  "")
    mkpath(joinpath(dir, "subdir"))

    result = list_dir_tool.callable(dir)
    @test occursin("a.txt",  result)
    @test occursin("b.jl",   result)
    @test occursin("subdir", result)

    # Non-existent path → error
    r2 = list_dir_tool.callable("/no/such/dir")
    @test occursin("error", lowercase(r2))
end

@testset "glob_tool — Dict dispatch via _call_tool" begin
    dir = mktempdir()
    write(joinpath(dir, "main.jl"),   "")
    write(joinpath(dir, "utils.jl"),  "")
    write(joinpath(dir, "README.md"), "")
    subdir = joinpath(dir, "src")
    mkpath(subdir)
    write(joinpath(subdir, "core.jl"), "")

    # Uses Dict-dispatch (glob_tool has optional base_dir)
    result = glob_tool.callable(Dict{Symbol,Any}(:pattern => "*.jl", :base_dir => dir))
    @test occursin("main.jl",  result)
    @test occursin("utils.jl", result)
    @test !occursin("README.md", result)

    # Recursive match
    result2 = glob_tool.callable(Dict{Symbol,Any}(:pattern => "**/*.jl", :base_dir => dir))
    @test occursin("core.jl", result2)

    # No matches
    result3 = glob_tool.callable(Dict{Symbol,Any}(:pattern => "*.xyz", :base_dir => dir))
    @test occursin("no files", lowercase(result3))
end

@testset "delete_file_tool" begin
    tmp = tempname()
    write(tmp, "to be deleted")
    @test isfile(tmp)

    result = delete_file_tool.callable(tmp)
    @test !isfile(tmp)
    @test occursin("deleted", lowercase(result))

    # Deleting non-existent file → error
    result2 = delete_file_tool.callable(tmp)
    @test occursin("error", lowercase(result2))
end

# ── search ────────────────────────────────────────────────────────────────────

@testset "grep_tool" begin
    dir = mktempdir()
    write(joinpath(dir, "a.txt"), "hello world\nfoo bar\nbaz\n")
    write(joinpath(dir, "b.txt"), "another hello here\n")

    result = grep_tool.callable(Dict{Symbol,Any}(:pattern => "hello", :path => dir))
    @test occursin("hello", result)

    # Case-insensitive flag
    result2 = grep_tool.callable(Dict{Symbol,Any}(
        :pattern        => "HELLO",
        :path           => dir,
        :case_sensitive => false,
    ))
    @test occursin("hello", lowercase(result2))

    # No matches
    result3 = grep_tool.callable(Dict{Symbol,Any}(:pattern => "zzznomatch", :path => dir))
    @test occursin("no matches", lowercase(result3))

    # Invalid regex
    result4 = grep_tool.callable(Dict{Symbol,Any}(:pattern => "[invalid", :path => dir))
    @test occursin("error", lowercase(result4))
end

@testset "find_files_tool" begin
    dir = mktempdir()
    write(joinpath(dir, "main.jl"),    "")
    write(joinpath(dir, "README.md"),  "")
    mkpath(joinpath(dir, "src"))
    write(joinpath(dir, "src", "util.jl"), "")

    result = find_files_tool.callable(Dict{Symbol,Any}(:pattern => "\\.jl", :base_dir => dir))
    @test occursin("main.jl", result)
    @test occursin("util.jl", result)
    @test !occursin("README.md", result)

    # No matches
    result2 = find_files_tool.callable(Dict{Symbol,Any}(:pattern => "\\.xyz", :base_dir => dir))
    @test occursin("no files", lowercase(result2))

    # Invalid regex falls back to literal match (no crash)
    result3 = find_files_tool.callable(Dict{Symbol,Any}(:pattern => "[invalid", :base_dir => dir))
    @test result3 isa String  # should not error
end

# ── shell ──────────────────────────────────────────────────────────────────────

@testset "bash_tool" begin
    # Basic execution
    result = bash_tool.callable(Dict{Symbol,Any}(:command => "echo hello"))
    @test occursin("hello", result)

    # Exit code non-zero surfaces error
    result2 = bash_tool.callable(Dict{Symbol,Any}(:command => "exit 1"))
    @test occursin("error", lowercase(result2)) || occursin("exit", lowercase(result2))

    # working_dir kwarg
    result3 = bash_tool.callable(Dict{Symbol,Any}(:command => "pwd", :working_dir => "/tmp"))
    @test occursin("tmp", result3)

    # Timeout
    result4 = bash_tool.callable(Dict{Symbol,Any}(:command => "sleep 60", :timeout => 0.3))
    @test occursin("timed out", lowercase(result4))
end

# ── Julia REPL ────────────────────────────────────────────────────────────────

@testset "eval_julia_tool — basic evaluation" begin
    task_local_storage(:_repl_session_state, Dict{String,Any}())
    task_local_storage(:_current_session, nothing)
    task_local_storage(:_current_store,   nothing)

    result = eval_julia_tool.callable(Dict{Symbol,Any}(:code => "1 + 1"))
    @test occursin("2", result)

    result2 = eval_julia_tool.callable(Dict{Symbol,Any}(:code => "\"hello\" * \" world\""))
    @test occursin("hello world", result2)
end

@testset "eval_julia_tool — stdout captured" begin
    task_local_storage(:_repl_session_state, Dict{String,Any}())
    task_local_storage(:_current_session, nothing)
    task_local_storage(:_current_store,   nothing)

    result = eval_julia_tool.callable(Dict{Symbol,Any}(:code => "println(\"printed output\")"))
    @test occursin("printed output", result)
end

@testset "eval_julia_tool — sandbox persists across calls" begin
    state = Dict{String,Any}()
    task_local_storage(:_repl_session_state, state)
    task_local_storage(:_current_session, nothing)
    task_local_storage(:_current_store,   nothing)

    eval_julia_tool.callable(Dict{Symbol,Any}(:code => "x_persistence_test = 42"))
    result = eval_julia_tool.callable(Dict{Symbol,Any}(:code => "x_persistence_test"))
    @test occursin("42", result)
end

@testset "eval_julia_tool — error reported" begin
    task_local_storage(:_repl_session_state, Dict{String,Any}())
    task_local_storage(:_current_session, nothing)
    task_local_storage(:_current_store,   nothing)

    result = eval_julia_tool.callable(Dict{Symbol,Any}(:code => "sqrt(-1)"))
    # DomainError or similar — just check it doesn't crash and returns something
    @test result isa String
    @test !isempty(result)
end

@testset "eval_julia_tool — timeout" begin
    task_local_storage(:_repl_session_state, Dict{String,Any}())
    task_local_storage(:_current_session, nothing)
    task_local_storage(:_current_store,   nothing)

    # Test _eval_in_sandbox timeout directly using a short-lived blocking op.
    # We can't use sleep(60) or `while true; end` because Threads.@spawn tasks
    # can't be interrupted — they block process exit.
    # Instead, test that the timeout machinery works by calling _eval_in_sandbox
    # with a Channel-based wait that we can unblock from here.
    sandbox = NimbleAgents._get_sandbox(nothing)
    ch = Channel{Nothing}(1)
    Core.eval(sandbox, :(test_ch = $ch))
    result_task = @async NimbleAgents._eval_in_sandbox(sandbox, "take!(test_ch)", 1)
    # Wait for the timeout to fire (~1s)
    wait(result_task)
    result = fetch(result_task)
    @test occursin("timed out", lowercase(result))
    # Unblock the spawned thread so it exits cleanly
    put!(ch, nothing)
end

# ── save_artifact_tool ────────────────────────────────────────────────────────

@testset "save_artifact_tool" begin
    store   = InMemorySessionStore()
    session = Session(app_name="SaveTest", user_id="u")
    save!(store, session)

    task_local_storage(:_current_session, session)
    task_local_storage(:_current_store,   store)

    tmpfile = tempname() * ".md"
    write(tmpfile, "# Report\nContent here.")

    result = save_artifact_tool.callable(tmpfile, "my-report")
    @test occursin("my-report", result)
    @test length(session.artifacts) == 1
    @test session.artifacts[1].name == "my-report"
    @test session.artifacts[1].type == :text

    # No session in TLS → graceful error message
    task_local_storage(:_current_session, nothing)
    result2 = save_artifact_tool.callable(tmpfile, "orphan")
    @test occursin("error", lowercase(result2)) ||
          occursin("no active session", lowercase(result2))
end
