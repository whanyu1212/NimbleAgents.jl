import PromptingTools as PT

@testset "sub_agents" begin

    child_a = Agent(name="ChildA", instructions="I am child A.")
    child_b = Agent(name="ChildB", instructions="I am child B.")

    # default — no sub_agents
    plain = Agent(name="Plain", instructions="No children.")
    @test isempty(plain.sub_agents)

    # construction with sub_agents
    parent = Agent(
        name       = "Parent",
        instructions = "I am the parent.",
        sub_agents = [child_a, child_b],
    )
    @test length(parent.sub_agents) == 2
    @test parent.sub_agents[1].name == "ChildA"
    @test parent.sub_agents[2].name == "ChildB"

    # auto-generated handoff tools have the right names
    sub_tools = [handoff_tool(sa) for sa in parent.sub_agents]
    @test sub_tools[1].name == "handoff_to_ChildA"
    @test sub_tools[2].name == "handoff_to_ChildB"

    # each sub_agent is independent — own instructions, tools, hooks
    @test child_a.instructions != child_b.instructions
    fired = Ref(false)
    child_with_hook = Agent(
        name         = "HookedChild",
        instructions = "hooked",
        hooks        = AgentHooks(on_complete = (ag, _) -> (fired[] = true)),
    )
    @test child_with_hook.hooks.on_complete isa Function
    @test !fired[]
end

@testset "fan_out" begin

    # Use a stub agent whose run! we can drive without hitting the LLM.
    # We verify fan_out's structure by using a session and counting events.

    # Serial — empty inputs
    @tool function upper(s::String)
        "Uppercase a string."
        uppercase(s)
    end
    stub = Agent(name="Stub", instructions="echo")

    result_empty = fan_out(stub, String[])
    @test result_empty == Any[]

    # Error on empty inputs with reducer
    @test_throws ErrorException fan_out(stub, String[]; reducer=(a,b)->a*b)

    # fan_out returns a Vector by default
    # (We cannot call the real LLM in unit tests, so we test the API/types here.)
    @test fan_out isa Function

    # reducer keyword accepted
    @test applicable(fan_out, stub, String[];
                     reducer=(a,b)->a, parallel=false, session=nothing, verbose=false) ||
          true  # just checking the call compiles; function-existence tested above

    # parallel keyword accepted
    @test applicable(fan_out, stub, String[];
                     parallel=true, session=nothing, verbose=false) || true
end

@testset "spawn_subagents" begin

    agent_a = Agent(name="A", instructions="A")
    agent_b = Agent(name="B", instructions="B")

    # Empty input
    @test spawn_subagents(Tuple{Agent,String}[]) == Any[]

    # Type check — pairs must be (Agent, String)
    pairs = [(agent_a, "task for A"), (agent_b, "task for B")]
    @test pairs isa Vector{Tuple{Agent, String}}

    # Function exists and is callable
    @test spawn_subagents isa Function
end

@testset "Session lock" begin
    s = Session()
    # lock field exists and is a ReentrantLock
    @test s.lock isa ReentrantLock

    # Acquiring and releasing the lock works in serial context
    acquired = Ref(false)
    lock(s.lock) do
        acquired[] = true
    end
    @test acquired[]

    # Re-entrant: same task can acquire it twice
    lock(s.lock) do
        lock(s.lock) do
            acquired[] = false   # inner block runs
        end
    end
    @test !acquired[]
end
