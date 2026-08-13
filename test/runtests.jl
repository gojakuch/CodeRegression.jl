using Random, Test, RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)
using CodeRegression

include("../examples/finding_functions_objectives.jl");

# check if we're running in quick mode
const QUICK_TEST = get(ENV, "QUICK_TEST", "false") == "true"

if QUICK_TEST
    println("\n\nRunning tests in quick mode! For extensive testing, set:\n`julia> ENV[\"QUICK_TEST\"]=\"false\"`\n")
else
    println("\n\nRunning all tests! For quick testing mode, set:\n`julia> ENV[\"QUICK_TEST\"]=\"true\"`\n")
end

# check if we're stopping once the required test fraction to pass is achieved
const REQUIRED_FRACTION_ONLY = get(ENV, "REQUIRED_FRACTION_ONLY", "true") == "true"

if REQUIRED_FRACTION_ONLY
    println("\n\nStopping the tests once the required test fraction to pass is achieved! To disable, set:\n`julia> ENV[\"REQUIRED_FRACTION_ONLY\"]=\"false\"`\n")
else
    println("\n\nContinuing the tests even if the required test fraction to pass has already been achieved! To enable stopping, set:\n`julia> ENV[\"REQUIRED_FRACTION_ONLY\"]=\"true\"`\n")
end

struct DummyDataType_test
end
struct DummyDataType2_test
end

@testset verbose=true "tests" begin
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
                    (target_f = sign, 
                        iters = 15, 
                        seeds = (QUICK_TEST ? (20,) : (20, 200, 20000)), 
                        fraction_to_pass=0.61),
                    (target_f = identity, 
                        iters = 15, 
                        seeds = (QUICK_TEST ? (2,) : (2, 20, 200)),
                        fraction_to_pass=0.61),
                    (target_f = abs, 
                        iters = 30, # TODO: reduce this again once the genetic algorithm gets better
                        seeds = (QUICK_TEST ? (3,) : (1, 2, 3, 5)),
                        fraction_to_pass=0.5),
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
                #=apply_mutate_to_pure_exprs=#false,
                #=apply_literal_optim=#false, 
                #=literal_optim_iters=#0)
            par_types = Tuple(algparams.f_arg_types)

            max_size = 50
            trim_size = 10
            reproducing_pairs = 8
            count_passed = 0
            fraction_passed = 0
            testvar = false
            for seed in test_param_set.seeds
                candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];

                res = false
                Random.seed!(seed)
                for it in 1:iters
                    # mutate
                    mutpair(p) = Pair{CandidateFunction, Float64}(mutate(p[1]), NaN64)
                    mutants = mutpair.(candidates)
                    candidates = cat(candidates, mutants; dims=1)

                    # crossover
                    children = Pair{CandidateFunction, Float64}[]
                    for rp in 1:reproducing_pairs
                        # shuffle!(candidates)
                        if rp+1 > length(candidates)
                            break
                        end
                        parent1 = candidates[rp]
                        parent2 = rand(candidates[(rp+1):end])
                        push!(children, (crossover(parent1[1], parent2[1]) => NaN64))
                    end
                    candidates = cat(candidates, children; dims=1)

                    # compute objectives and sort
                    generate_callables!(candidates)
                    objective!(target_f, candidates)
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
                    println("Warning: Individual test failed: ", test_param_set.target_f, " with seed ", seed, ".\nBest candidate:\n", candidates[1][1].fdecl, "\nwith loss: ", candidates[1][2])
                end

                count_passed += res
                fraction_passed = count_passed/length(test_param_set.seeds)
                testvar = fraction_passed >= test_param_set.fraction_to_pass
                if REQUIRED_FRACTION_ONLY && testvar
                    break
                end
            end

            if !testvar
                println("\nTest failed COMPLETELY: ", test_param_set.target_f, " (finding functions); only passed on ", count_passed, " seeds out of ", length(test_param_set.seeds), ". required fraction is ", test_param_set.fraction_to_pass)
            end
            @test testvar
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
        @test (Set(consts) == Set(CodeRegression.Stages.Literals.find_literals(f)))
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
            Float64,  Dict{DataType, Vector{AllowedOperationDescription}}(), 0, false, false, 0)
            cff_backup = deepcopy(cff)
            
            p = swap_literals_with_params(cff)
            xs = -2:0.001:2
            loss = function(f)
                sum((abs.(xs) - f.(xs)).^2)/100
            end

            optimize_literals!(p, loss, 100, 0.01)

            p.cf.callable = @RuntimeGeneratedFunction(CodeRegression, p.cf.fdecl)
            @test loss(p.cf.callable) < 9e-4 # check the optimisation

            cff_backup_f = @RuntimeGeneratedFunction(CodeRegression, cff_backup.fdecl)
            cff_f = @RuntimeGeneratedFunction(CodeRegression, cff.fdecl)

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
            Float64,  Dict{DataType, Vector{AllowedOperationDescription}}(), 0, false, false, 0)
            p = swap_literals_with_params(cff)
            xs = -2:0.001:2
            loss = function(f)
                sum((abs.(xs) - f.(xs)).^2)/100
            end

            optimize_literals!(p, loss, 100, 0.01)

            p.cf.callable = @RuntimeGeneratedFunction(CodeRegression, p.cf.fdecl)
            @test loss(p.cf.callable) < 9e-4
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
        Float64,  Dict{DataType, Vector{AllowedOperationDescription}}(), 0, false, false, 0)
        p = swap_literals_with_params(cff)
        xs = -2:0.01:2
        loss = function(f)
            sum((sign.(xs) - f.(xs)).^2)/100
        end

        optimize_literals!(p, loss, 1000, 0.01)

        p.cf.callable = @RuntimeGeneratedFunction(CodeRegression, p.cf.fdecl)
        @test loss(p.cf.callable) < 0.011
    end

    if !QUICK_TEST
        @testset "finding functions with literal optimisation, fixed seeds" begin # code taken from examples/finding_functions_with_literal_opt.jl
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
                        # TODO: lower the precisions values once our GP and LO get better (and maybe do a max pooling over a set of sets of seeds)
                        (fname="2*sign(x)", target_f = (x)->2*sign(x), iters = 5, seeds = 0:10:90, 
                        precisions=[0.03, 0.03, 0.03, 0.75, 0.75, 0.8, 0.81, 0.9, 0.95, 1.5],),
                        (fname="2.5*sign(x)+0.5", target_f = (x)->2.5*sign(x)+0.5, iters = 5, seeds = 0:10:90, 
                        precisions=[0.0303, 0.0303, 0.0304, 0.9, 1.1, 1.2, 1.3, 1.5, 1.65, 2],), # 1 iter gives the precision of ~2.5, so these tests still make sense
                        (fname="((x < 0.5 && x > -0.5) ? 1 : 0)", target_f = (x)->((x < 0.5 && x > -0.5) ? 1 : 0), iters = 5, seeds = 0:10:90, 
                        precisions=[0.07, 0.09, 0.3, 0.35, 0.4, 0.4, 0.401, 0.42, 0.47, 0.48],)
                    ]
                target_f = test_param_set.target_f
                iters = test_param_set.iters

                algparams, init_f = CodeRegression.init(
                    #=initial_fdecl=# :(function (x::Float64)
                        return _cw_(1.0)
                    end), 
                    #=return_type=#Float64,  
                    #=all_ops=#allowed_ops, 
                    #=expr_gen_depth=#3,
                    #=apply_mutate_to_pure_exprs=#false,
                    #=apply_literal_optim=#true, 
                    #=literal_optim_iters=#50)
                par_types = Tuple(algparams.f_arg_types)

                max_size = 50
                trim_size = 10
                reproducing_pairs = 8
                count_passed = 0
                fraction_passed = 0
                testvar = false
                precisions_and_seeds = Pair{Float64, Int}[]
                for seed_i in eachindex(test_param_set.seeds)
                    seed = test_param_set.seeds[seed_i]

                    candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];

                    Random.seed!(seed)
                    for it in 1:iters
                        # mutate
                        mutpair(p) = Pair{CandidateFunction, Float64}(mutate(p[1]), NaN64)
                        mutants = mutpair.(candidates)
                        candidates = cat(candidates, mutants; dims=1)

                        # crossover
                        children = Pair{CandidateFunction, Float64}[]
                        for rp in 1:reproducing_pairs
                            # shuffle!(candidates)
                            if rp+1 > length(candidates)
                                break
                            end
                            parent1 = candidates[rp]
                            parent2 = rand(candidates[(rp+1):end])
                            push!(children, (crossover(parent1[1], parent2[1]) => NaN64))
                        end
                        candidates = cat(candidates, children; dims=1)

                        # literal optimisation
                        if algparams.apply_literal_optim
                            swap_literals_pair(p) = swap_literals_with_params(p[1])
                            ps = swap_literals_pair.(candidates)
                            xs = -2:0.001:2
                            loss = function(f)
                                sum((target_f.(xs) - f.(xs)).^2)/100
                            end

                            for p in ps
                                optimize_literals!(p, loss, algparams.literal_optim_iters, 0.01)
                                push!(candidates, Pair(p.cf, NaN64))
                            end
                        end

                        # compute objectives and sort
                        generate_callables!(candidates)
                        objective!(target_f, candidates)
                        sort!(candidates; lt=(x, y)->(isless(x[2], y[2])))
                        if length(candidates) > max_size
                            candidates = candidates[1:trim_size]
                        end
                    end

                    push!(precisions_and_seeds, Pair(candidates[1][2], seed))
                end

                target_precisions = sort(test_param_set.precisions)
                res_precisions_and_seeds = sort(precisions_and_seeds)

                diff_array = [target_precisions[i]-res_precisions_and_seeds[i][1] for i in eachindex(res_precisions_and_seeds)]
                testvar = sum(diff_array .>= 0) == length(diff_array)

                if !testvar
                    println("\nTest failed COMPLETELY: ", test_param_set.fname, " (finding functions w/ literal optimisation); the diff_array looks like this: "),
                    show(diff_array)
                    println("\nwith res_precisions_and_seeds being: ")
                    show(res_precisions_and_seeds)
                    println("\nwith target_precisions being: ")
                    show(target_precisions)
                end
                @test testvar
            end
        end
    end


    # this tests `mutate_pure_expression` for corner-case handling, but also tests expression generation and __MutationContext creation along the way.
    @testset "`mutate_pure_expression` test" begin
        mpe_test_seeds = (QUICK_TEST) ? (1:10) : (1:100)

        # we need exactly this set of operations for extensive testing!! do not change this, add new tests if necessary
        mpe_test_allowed_ops = Dict{DataType, Vector{AllowedOperationDescription}}(
            Number => [
                AllowedOperationDescription(
                    :(-), 
                    NamedTuple[(type=Number, can_be_const=true)]
                ),
                AllowedOperationDescription(
                    :(+), 
                    NamedTuple[(type=Number, can_be_const=true), (type=Number, can_be_const=false)]
                ),
                AllowedOperationDescription(
                    :(-), 
                    NamedTuple[(type=Number, can_be_const=true), (type=Number, can_be_const=false)]
                ),
                AllowedOperationDescription(
                    :(*), 
                    NamedTuple[(type=Number, can_be_const=true), (type=Number, can_be_const=false)]
                ),
                AllowedOperationDescription(
                    :(/), 
                    NamedTuple[(type=Number, can_be_const=true), (type=Number, can_be_const=false)]
                ),
                AllowedOperationDescription(
                    :(f), 
                    NamedTuple[(type=Number, can_be_const=true), (type=Number, can_be_const=true), (type=Number, can_be_const=false)]
                ),
                AllowedOperationDescription(
                    :(f_int), 
                    NamedTuple[(type=Int, can_be_const=true), (type=Int, can_be_const=false), (type=Number, can_be_const=false)]
                ),
            ],
            String => [
                AllowedOperationDescription(
                    :(string), 
                    NamedTuple[(type=Int, can_be_const=true)]
                ),
            ],
            DummyDataType2_test => [
                AllowedOperationDescription(
                    :(f_dummy2), 
                    NamedTuple[(type=Number, can_be_const=true), (type=Number, can_be_const=true), (type=Number, can_be_const=false)]
                ),
            ],
        )
        _, init_f = CodeRegression.init(
            #=initial_fdecl=# :(function (x::Float64, y::Float64)
                return 1
            end), 
            #=return_type=#Float64,  
            #=all_ops=#mpe_test_allowed_ops, 
            #=expr_gen_depth=#3,
            #=apply_mutate_to_pure_exprs=#true,
            #=apply_literal_optim=#false, 
            #=literal_optim_iters=#0);
        
        @testset "`mutate_pure_expression` test (handling atomic stuff)" begin
            for seed in mpe_test_seeds
                Random.seed!(seed)

                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(:(_cw_(123123.123123)), Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test occursin("_cw_(123123.123123)", string(res))

                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(:(sampletext), Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test occursin("sampletext", string(res))
            end
        end

        @testset "`mutate_pure_expression` test (handling a type with no proper operations)" begin
            pure_ex = :(string(1))
            res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, String, CodeRegression.Stages.Mutation.__MutationContext(init_f))
            @test string(pure_ex) == string(res) # shouldn't mutate, as there's no option to mutate Integers

            res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(:("sampletext"), String, CodeRegression.Stages.Mutation.__MutationContext(init_f))
            @test occursin("sampletext", string(res)) # shouldn't mutate, as there's no option to mutate Strings

            res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(:([1, 2]), Array{Int, 2}, CodeRegression.Stages.Mutation.__MutationContext(init_f))
            @test occursin("[1, 2]", string(res)) # shouldn't mutate, as the type is not listed

            pure_ex = :(abcdefg(0,1,2))
            res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, DummyDataType_test, CodeRegression.Stages.Mutation.__MutationContext(init_f))
            @test string(pure_ex) == string(res) # shouldn't mutate, as the type is not listed
        end

        @testset "`mutate_pure_expression` test (handling function call expressions)" begin
            for seed in mpe_test_seeds
                Random.seed!(seed)

                pure_ex = :(_cw_(2.0) + _cw_(1.0))
                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test string(pure_ex) != string(res) # should change something

                pure_ex = :(x + (y * z))
                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test string(pure_ex) != string(res) # should change something

                pure_ex = :(-_cw_(1.0))
                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test string(pure_ex) != string(res) # should change something

                pure_ex = :(f(_cw_(1.0), x+x, y))
                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test string(pure_ex) != string(res) # should change something

                pure_ex = :(f_dummy2(_cw_(1.0), x+x, y))
                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, DummyDataType2_test, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test string(pure_ex) != string(res) # should change something
            end

            pure_ex = :(f_int(_cw_(1), _cw_(2), y))
            res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(pure_ex, Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
            # shouldn't throw errors
        end

        # now, we set apply_mutate_to_pure_exprs=false
        _, init_f = CodeRegression.init(
            #=initial_fdecl=# :(function (x::Float64, y::Float64)
                return 1
            end), 
            #=return_type=#Float64,  
            #=all_ops=#mpe_test_allowed_ops, 
            #=expr_gen_depth=#3,
            #=apply_mutate_to_pure_exprs=#false, 
            #=apply_literal_optim=#false, 
            #=literal_optim_iters=#0);

        @testset "`mutate_pure_expression` test (apply_mutate_to_pure_exprs=false)" begin
            for seed in mpe_test_seeds
                Random.seed!(seed)

                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(:(_cw_(123123.123123)), Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test !occursin("_cw_(123123.123123)", string(res)) # with !

                res = CodeRegression.Stages.Mutation.Naive.mutate_pure_expression(:(sampletext), Number, CodeRegression.Stages.Mutation.__MutationContext(init_f))
                @test !occursin("sampletext", string(res)) # with !
            end
        end
    end


    # TODO: add a copy validity test (so that we know that both merge and mutate don't accidentally change the original functions)


    # TODO: add tests that check if the generation is copying the subexpressions to avoid this situation in parametrisation and more (not only with constants)


    # TODO: add benchmarks and benchmark tests separately once all the main functionality is implemented
end