using Random
using CodeRegression
# using RuntimeGeneratedFunctions

include("finding_functions_objectives.jl");

target_f = abs # abs, sign, identity; — all work here

allowed_ops = Dict{DataType, Vector{AllowedOperationDescription}}(
    Bool => [
        AllowedOperationDescription(
            :(<), 
            NamedTuple[(type=Number, can_be_const=false), (type=Number, can_be_const=true)] # FIXME: only works for numbers but how do we also do the same thing for integers and all the possible type variations later on?
        ),
        AllowedOperationDescription(
            :(==), 
            NamedTuple[(type=Number, can_be_const=false), (type=Number, can_be_const=true)] # FIXME: again, we should somehow signal all the types that we can take as an arg
        ),
    ],
    Number => [
        AllowedOperationDescription(
            :(-), 
            NamedTuple[(type=Number, can_be_const=true)]
        ),
    ]
)
algparams, init_f = CodeRegression.init(
    #=initial_fdecl=# :(function (x::Float64)
        return 1
    end), 
    #=return_type=#Float64,  
    #=all_ops=#allowed_ops, 
    #=expr_gen_depth=#3,
    #=apply_mutate_to_pure_exprs=#false,
    #=apply_literal_optim=#false, 
    #=literal_optim_iters=#0);
par_types = Tuple(algparams.f_arg_types);
candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];
max_size = 50;
trim_size = 10;
iters = 15;
reproducing_pairs = 8;

Random.seed!(1)
for it in 1:iters
    # mutate
    mutpair(p) = Pair{CandidateFunction, Float64}(mutate(p[1]), NaN64)
    mutants = mutpair.(candidates)
    candidates = cat(candidates, mutants; dims=1)

    # crossover
    # TODO: maybe figure out a good distribution for how to pick the reproducing pairs, for the best to be ahead??
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
end

println(candidates[1][1].fdecl)
println(candidates[1][2])