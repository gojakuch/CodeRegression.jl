using Random, Test
using CodeRegression

include("finding_functions_objectives.jl");

@testset "(finding functions, fixed seeds)" begin # code taken from examples/finding_functions.jl
    for seed in (2, 20, 200)
        Random.seed!(seed)
        for test_param_set in [
                Dict(:function => sign, :iters => 5),
                Dict(:function => identity, :iters => 5)
            ]

            init_f = :(function (x::Float64)
                    return 1
                end)
            target_f = test_param_set[:function]
            iters = test_param_set[:iters]
            par_types = (Float64,)
            return_type = Float64
            candidates = Pair{Expr, Float64}[Pair(init_f, NaN)]
            max_size = 50
            trim_size = 10
            
            reproducing_pairs = 7
            gen_depth = 4

            res = false
            for it in 1:iters
                # mutate
                mutpair(p) = Pair{Expr, Float64}(mutate(p[1], return_type, gen_depth), NaN64)
                mutants = mutpair.(candidates)
                candidates = cat(candidates, mutants; dims=1)

                children = Pair{Expr, Float64}[]
                for _ in 1:reproducing_pairs
                    shuffle!(candidates)
                    parents = candidates[1:2]
                    try # FIXME: remove and check for errors??
                    push!(children, (reproduce(parents[1][1], parents[2][1]) => NaN64)) # possible duplicates
                    catch
                    end
                end
                candidates = cat(candidates, children; dims=1)
                # compute objectives and sort
                pf = objective_precompile(candidates, par_types)
                objective!(target_f, candidates, pf)
                sort!(candidates; lt=(x, y)->(isless(x[2], y[2])))
                if length(candidates) > max_size
                    candidates = candidates[1:trim_size]
                end

                if candidates[1][2] < 0.01
                    res = true
                    break
                end
            end

            if !res
                println("Test failed: ", test_param_set[:function], " with seed ", seed, ".\nBest candidate:\n", candidates[1])
            end

            @test res
        end
    end
end