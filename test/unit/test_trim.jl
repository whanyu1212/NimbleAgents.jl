
@testset "Tool output trimming" begin

    # ── _trim_tool_output ─────────────────────────────────────────────────────

    @testset "_trim_tool_output basics" begin
        # Short text — no trimming
        @test NimbleAgents._trim_tool_output("hello", 100) == "hello"

        # Unlimited (0) — no trimming
        big = "x" ^ 10_000
        @test NimbleAgents._trim_tool_output(big, 0) == big

        # Negative — treated as unlimited
        @test NimbleAgents._trim_tool_output(big, -1) == big

        # Exact fit — no trimming
        @test NimbleAgents._trim_tool_output("abc", 3) == "abc"
    end

    @testset "_trim_tool_output line-aware" begin
        # Build a 100-line string, ~10 chars per line
        lines = ["line $(lpad(i, 4, '0'))" for i in 1:100]
        text = join(lines, '\n')

        # Trim to ~200 chars — should get head + marker + tail
        trimmed = NimbleAgents._trim_tool_output(text, 200)
        @test length(trimmed) < length(text)
        @test occursin("trimmed", trimmed)
        @test occursin("lines omitted", trimmed)
        @test occursin("tokens", trimmed)

        # Head lines preserved (first line should be there)
        @test startswith(trimmed, "line 0001")
        # Tail lines preserved (last line should be there)
        @test endswith(trimmed, "line 0100")
    end

    @testset "_trim_tool_output single/two lines" begin
        # Single very long line — falls back to char-level truncation
        long_line = "x" ^ 1000
        trimmed = NimbleAgents._trim_tool_output(long_line, 100)
        @test length(trimmed) < length(long_line)
        @test occursin("truncated", trimmed)

        # Two lines — also char-level fallback
        two_lines = "a" ^ 500 * "\n" * "b" ^ 500
        trimmed = NimbleAgents._trim_tool_output(two_lines, 100)
        @test length(trimmed) < length(two_lines)
    end

    @testset "_trim_tool_output preserves structure" begin
        # JSON-like multiline — should cut at line boundaries
        json_lines = [
            "{",
            "  \"key1\": \"value1\",",
            "  \"key2\": \"value2\",",
            "  \"key3\": \"value3\",",
            "  \"key4\": \"value4\",",
            "  \"key5\": \"value5\"",
            "}",
        ]
        # Repeat to make it large
        big_json = join(repeat(json_lines, 50), '\n')
        trimmed = NimbleAgents._trim_tool_output(big_json, 200)
        # Should not cut mid-line
        for line in split(trimmed, '\n')
            # Each line should be a complete JSON-ish line or the marker
            @test !startswith(line, "alue")  # not mid-value
        end
    end

    # ── _effective_max_output ──────────────────────────────────────────────────

    @testset "_effective_max_output resolution" begin
        # Per-tool wins when set
        tool_with_limit = NimbleTool(;
            name="t", parameters=Dict{String,Any}(), callable=identity, max_output=5000
        )
        agent_with_limit = Agent(name="A", instructions="test", max_tool_output=50_000)
        @test NimbleAgents._effective_max_output(tool_with_limit, agent_with_limit) == 5000

        # Falls back to agent default when tool has 0
        tool_no_limit = NimbleTool(;
            name="t", parameters=Dict{String,Any}(), callable=identity
        )
        @test NimbleAgents._effective_max_output(tool_no_limit, agent_with_limit) == 50_000

        # Both 0 → unlimited
        agent_no_limit = Agent(name="A", instructions="test")
        @test NimbleAgents._effective_max_output(tool_no_limit, agent_no_limit) == 0
    end

    # ── @tool max_output flag ─────────────────────────────────────────────────

    @testset "@tool max_output flag" begin
        @test trim_test_tool.max_output == 10_000
        @test trim_default_tool.max_output == 0
    end

    # ── Integration: trimming in run! ─────────────────────────────────────────

    @testset "agent-level trimming in run!" begin
        big_result = join(["result_line_$(lpad(i, 5, '0'))" for i in 1:1000], '\n')

        big_tool = NimbleTool(;
            name="big_tool",
            parameters=Dict{String,Any}(
                "type" => "object",
                "properties" =>
                    Dict{String,Any}("x" => Dict{String,Any}("type" => "string")),
                "required" => ["x"],
            ),
            callable=(_) -> big_result,
        )

        agent = Agent(
            name="TrimAgent",
            instructions="You are a test agent.",
            tools=[big_tool],
            max_tool_output=500,
        )

        _trim_ai_msg(text) = NimbleAgents.AIMessage(;
            content=text, tokens=(10, 10), elapsed=0.1
        )
        function _trim_tool_req(tool_name, args)
            tm = NimbleAgents.ToolMessage(;
                content=nothing,
                raw="",
                tool_call_id="call_$(tool_name)",
                name=tool_name,
                args=Dict{Symbol,Any}(Symbol(k) => v for (k, v) in args),
            )
            NimbleAgents.AIToolRequest(;
                tool_calls=[tm], content="", tokens=(5, 5), elapsed=0.1
            )
        end

        call_count = Ref(0)
        patch = Mocking.@patch function NimbleAgents.aitools(conv; kwargs...)
            call_count[] += 1
            if call_count[] == 1
                push!(conv, _trim_tool_req("big_tool", Dict("x" => "go")))
            else
                push!(conv, _trim_ai_msg("Done"))
            end
            conv
        end

        Mocking.apply(patch) do
            session = Session()
            result = run!(agent, "test"; session=session, verbose=false)
            @test result == "Done"

            # ToolEvent stores the full (untrimmed) result
            tool_events = session.events[end].tool_calls
            @test length(tool_events) == 1
            @test length(string(tool_events[1].result)) == length(big_result)

            # The tool message in session.history should be trimmed
            tool_msgs = filter(m -> m isa NimbleAgents.ToolMessage, session.history)
            @test !isempty(tool_msgs)
            @test length(tool_msgs[end].content) < length(big_result)
            @test occursin("trimmed", tool_msgs[end].content)
        end
    end

    @testset "per-tool max_output overrides agent default" begin
        big_result = join(["per_tool_line_$(lpad(i, 4, '0'))" for i in 1:500], '\n')

        capped_tool = NimbleTool(;
            name="capped",
            parameters=Dict{String,Any}(
                "type" => "object",
                "properties" =>
                    Dict{String,Any}("x" => Dict{String,Any}("type" => "string")),
                "required" => ["x"],
            ),
            callable=(_) -> big_result,
            max_output=200,
        )

        agent = Agent(
            name="TrimAgent2",
            instructions="You are a test agent.",
            tools=[capped_tool],
            max_tool_output=50_000,  # generous agent limit — per-tool 200 should win
        )

        _trim_ai_msg2(text) = NimbleAgents.AIMessage(;
            content=text, tokens=(10, 10), elapsed=0.1
        )
        function _trim_tool_req2(tool_name, args)
            tm = NimbleAgents.ToolMessage(;
                content=nothing,
                raw="",
                tool_call_id="call_$(tool_name)",
                name=tool_name,
                args=Dict{Symbol,Any}(Symbol(k) => v for (k, v) in args),
            )
            NimbleAgents.AIToolRequest(;
                tool_calls=[tm], content="", tokens=(5, 5), elapsed=0.1
            )
        end

        call_count2 = Ref(0)
        patch = Mocking.@patch function NimbleAgents.aitools(conv; kwargs...)
            call_count2[] += 1
            if call_count2[] == 1
                push!(conv, _trim_tool_req2("capped", Dict("x" => "go")))
            else
                push!(conv, _trim_ai_msg2("Done"))
            end
            conv
        end

        Mocking.apply(patch) do
            session = Session()
            result = run!(agent, "test"; session=session, verbose=false)
            @test result == "Done"

            tool_msgs = filter(m -> m isa NimbleAgents.ToolMessage, session.history)
            @test !isempty(tool_msgs)
            # Per-tool limit is 200, so content should be much smaller than the full result
            @test length(tool_msgs[end].content) < 400  # 200 + marker overhead
            @test occursin("trimmed", tool_msgs[end].content)
        end
    end
end
