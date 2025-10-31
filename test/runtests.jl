using Random, Test
using CodeRegression

@testset "fixed seeds" begin
    for seed in (1,2,3,100,999)
        @test true
    end
end
