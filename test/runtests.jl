using Random, Test
using CodeRegression

include("finding_functions_objectives.jl");

@testset "tests" begin

    @testset "finding functions, fixed seeds" begin # code taken from examples/finding_functions.jl
        for test_param_set in [
                    (target_f = sign, iters = 15, seeds = (20, 200, 20000)),
                    (target_f = identity, iters = 15, seeds = (2, 20, 200)),
                    (target_f = abs, iters = 15, seeds = (1, 2,)),
                ]
            target_f = test_param_set.target_f
            iters = test_param_set.iters

            init_f = CandidateFunction(:(function (x::Float64)
                        return 1
                    end), #=return_type=#Float64)
            par_types = Tuple(init_f.arg_types)
            return_type = init_f.return_type

            max_size = 50
            trim_size = 10
            reproducing_pairs = 8
            gen_depth = 3
            for seed in test_param_set.seeds
                candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];

                res = false
                Random.seed!(seed)
                for it in 1:iters
                    # mutate
                    mutpair(p) = Pair{CandidateFunction, Float64}(mutate(p[1], gen_depth), NaN64)
                    mutants = mutpair.(candidates)
                    candidates = cat(candidates, mutants; dims=1)

                    # reproduce
                    children = Pair{CandidateFunction, Float64}[]
                    for rp in 1:reproducing_pairs
                        # shuffle!(candidates)
                        if rp+1 > length(candidates)
                            break
                        end
                        parent1 = candidates[rp]
                        parent2 = rand(candidates[(rp+1):end])
                        try # FIXME: remove and check for errors??
                        push!(children, (reproduce(parent1[1], parent2[1]) => NaN64))
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
                    println("Test failed: ", test_param_set.target_f, " with seed ", seed, ".\nBest candidate:\n", candidates[1][1].fdecl, "\nwith loss: ", candidates[1][2])
                end

                @test res
            end
        end
    end


    @testset "`find_literals` test" begin
        consts = CodeRegression.make_const_wrap.([1, 2, 3.0])
        f = Expr(:function, Expr(:call, :f, :x, :y), 
            Expr(:block, 
                Expr(:if, Expr(:call, >, :x, consts[1]),
                    Expr(:(=), :x, consts[2]),
                    Expr(:(=), :y, consts[3]),
                )
            )
        )
        @test (Set(consts) == Set(CodeRegression.find_literals(f)))
    end

end

# TODO: add a copy validity test (so that we know that both merge and mutate don't accidentally change the original functions)