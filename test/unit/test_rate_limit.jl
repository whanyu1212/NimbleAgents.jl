###############################################################################
# test_rate_limit.jl — unit tests for rate limiting
###############################################################################

using NimbleAgents: RateLimiter, acquire!, _acquire_rate_limit!,
                    set_rate_limit!, remove_rate_limit!,
                    _rate_limiters, _rate_limiters_lock

@testset "RateLimiter — construction" begin
    rl = RateLimiter(10)
    @test rl.rate == 10.0
    @test rl.tokens == 10.0  # burst capacity equals rate
end

@testset "RateLimiter — acquire! consumes tokens" begin
    rl = RateLimiter(100)  # high rate so no blocking
    acquire!(rl)
    @test rl.tokens < 100.0   # at least one token consumed
end

@testset "RateLimiter — acquire! blocks when empty" begin
    rl = RateLimiter(100)
    # Drain all tokens
    for _ in 1:100
        acquire!(rl)
    end
    # Next acquire should take some time (tokens need to refill)
    t0 = time()
    acquire!(rl)
    elapsed = time() - t0
    @test elapsed > 0.001  # should have blocked briefly
end

@testset "set_rate_limit! / remove_rate_limit!" begin
    set_rate_limit!("test-model-xyz", 5)
    @test haskey(_rate_limiters, "test-model-xyz")
    remove_rate_limit!("test-model-xyz")
    @test !haskey(_rate_limiters, "test-model-xyz")
end

@testset "set_rate_limit! :default" begin
    set_rate_limit!(:default, 15)
    @test haskey(_rate_limiters, "__default__")
    remove_rate_limit!(:default)
    @test !haskey(_rate_limiters, "__default__")
end

@testset "set_rate_limit! rejects non-positive rate" begin
    @test_throws ErrorException set_rate_limit!("bad", 0)
    @test_throws ErrorException set_rate_limit!("bad", -1)
end

@testset "set_rate_limit! rejects non-:default symbol" begin
    @test_throws ErrorException set_rate_limit!(:foo, 10)
end

@testset "_acquire_rate_limit! — no-op without limits" begin
    # Clear any leftover state
    lock(_rate_limiters_lock) do
        empty!(_rate_limiters)
    end
    # Should return immediately without error
    _acquire_rate_limit!("nonexistent-model")
end

@testset "_acquire_rate_limit! — uses model-specific limit" begin
    set_rate_limit!("rate-test-model", 1000)
    # Should not error — just acquires a token
    _acquire_rate_limit!("rate-test-model")
    remove_rate_limit!("rate-test-model")
end

@testset "_acquire_rate_limit! — falls back to default" begin
    set_rate_limit!(:default, 1000)
    # No model-specific limit, should use default
    _acquire_rate_limit!("some-other-model")
    remove_rate_limit!(:default)
end

@testset "_acquire_rate_limit! — model-specific takes precedence over default" begin
    set_rate_limit!(:default, 1000)
    set_rate_limit!("specific-model", 500)

    # The specific model limiter should be used, not the default
    limiter = lock(_rate_limiters_lock) do
        get(_rate_limiters, "specific-model", nothing)
    end
    @test limiter.rate == 500.0

    remove_rate_limit!("specific-model")
    remove_rate_limit!(:default)
end
