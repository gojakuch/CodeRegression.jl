using Random, Test
using CodeRegression

include("../examples/finding_functions_objectives.jl");

# check if we're running in quick mode
const QUICK_TEST = get(ENV, "QUICK_TEST", "false") == "true"

if QUICK_TEST
    println("\n\nrunning tests in quick mode! for extensive testing, use:\n`julia> ENV[\"QUICK_TEST\"]=\"false\"`\n")
else
    println("\n\nrunning all tests! for quick testing mode, use:\n`julia> ENV[\"QUICK_TEST\"]=\"true\"`\n")
end

@testset "tests" begin
    @testset "finding functions, fixed seeds" begin # code taken from examples/finding_functions.jl
        allowed_ops = Dict{DataType, Vector{AllowedOperationDescription}}(
            Bool => [
                AllowedOperationDescription(
                    :(<), 
                    NamedTuple[(type=Number, can_be_const=false), (type=Number, can_be_const=true)]
                ),
                AllowedOperationDescription(
                    :(==), 
                    NamedTuple[(type=Number, can_be_const=false), (type=Number, can_be_const=true)]
                ),
            ],
            Number => [
                AllowedOperationDescription(
                    :(-), 
                    NamedTuple[(type=Number, can_be_const=true)]
                ),
            ]
        )
        for test_param_set in [
                    (target_f = sign, iters = 15, seeds = (QUICK_TEST ? (20,) : (20, 200, 20000))),
                    (target_f = identity, iters = 15, seeds = (QUICK_TEST ? (2,) : (2, 20, 200))),
                    (target_f = abs, iters = 15, seeds = (QUICK_TEST ? (1,) : (1, 2,))),
                ]
            target_f = test_param_set.target_f
            iters = test_param_set.iters

            algparams, init_f = CodeRegression.init(
                #=initial_fdecl=# :(function (x::Float64)
                    return 1
                end), 
                #=return_type=#Float64,  
                #=all_ops=#allowed_ops, 
                #=expr_gen_depth=#3,
                #=apply_literal_optim=#false, 
                #=literal_optim_iters=#0)
            par_types = Tuple(algparams.f_arg_types)

            max_size = 50
            trim_size = 10
            reproducing_pairs = 8
            for seed in test_param_set.seeds
                candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];

                res = false
                Random.seed!(seed)
                for it in 1:iters
                    # mutate
                    mutpair(p) = Pair{CandidateFunction, Float64}(mutate(p[1]), NaN64)
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


    @testset "literal optimisation (abs)" begin
        begin
            _, cff = CodeRegression.init(
                :(function (x::Float64)
                    if x > _cw_(1)
                        return x
                    end
                    return -x
                end),
            Float64,  Dict{DataType, Vector{AllowedOperationDescription}}(), 0, false, 0)
            cff_backup = deepcopy(cff)
            
            p = swap_literals_with_params(cff)
            xs = -2:0.001:2
            loss = function(f)
                sum((abs.(xs) - f.(xs)).^2)/100
            end

            optimize_literals!(p, loss, 100, 0.01)

            f = eval(p.cf.fdecl)
            @test loss(f) < 9e-4 # check the optimisation

            cff_backup_f = eval(cff_backup.fdecl)
            cff_f = eval(cff.fdecl)

            @test cff_backup_f.(xs) == cff_f.(xs) # check that we preserve the original CandidateFunction object
        end

        begin
            _, cff = CodeRegression.init(
                :(function (x::Float64)
                    if x > _cw_(-1)
                        return x
                    end
                    return -x
                end), 
            Float64,  Dict{DataType, Vector{AllowedOperationDescription}}(), 0, false, 0)
            p = swap_literals_with_params(cff)
            xs = -2:0.001:2
            loss = function(f)
                sum((abs.(xs) - f.(xs)).^2)/100
            end

            optimize_literals!(p, loss, 100, 0.01)

            f = eval(p.cf.fdecl)
            @test loss(f) < 9e-4
        end
    end


    @testset "literal optimisation (sign)" begin
        _, cff = CodeRegression.init(
            :(function (x::Float64)
                if x > _cw_(0.1)
                    return _cw_(0.9)
                end
                return _cw_(-1.2)
            end),
        Float64,  Dict{DataType, Vector{AllowedOperationDescription}}(), 0, false, 0)
        p = swap_literals_with_params(cff)
        xs = -2:0.01:2
        loss = function(f)
            sum((sign.(xs) - f.(xs)).^2)/100
        end

        optimize_literals!(p, loss, 1000, 0.01)

        f = eval(p.cf.fdecl)
        @test loss(f) < 0.011
    end


    # TODO: add a copy validity test (so that we know that both merge and mutate don't accidentally change the original functions)


    # TODO: add tests that check if the generation is copying the subexpressions to avoid this situation in parametrisation and more (not only with constants)
end