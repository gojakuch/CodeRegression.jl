using Random
using CodeRegression
# using RuntimeGeneratedFunctions

include("finding_functions_objectives.jl");

target_f = abs # abs, sign, identity; — all work here

allowed_ops = Dict{Type, Vector{AllowedOperationDescription}}(
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
    #=selection_backend=#Truncation(#=max_size=#50, #=new_size=#10),
    #=apply_literal_optim=#false, 
    #=literal_optim_iters=#0,
    #=_candidate_function_criterion_type=#Float64);
par_types = Tuple(algparams.f_arg_types);
candidates = [init_f];
iters = 15;
reproducing_pairs = 8;

Random.seed!(1);
for it in 1:iters
    # mutation stage
    mutants = mutate.(candidates)
    candidates = cat(candidates, mutants; dims=1)

    # selection stage
    objective!(target_f, candidates)
    candidates = select(candidates)

    # crossover stage
    children = empty(candidates)
    for rp in 1:reproducing_pairs
        if rp+1 > length(candidates)
            break
        end
        parent1 = candidates[rp]
        parent2 = rand(candidates[(rp+1):end])
        push!(children, crossover(parent1, parent2))
    end
    candidates = cat(candidates, children; dims=1)
end

# sort again before choosing the best one
objective!(target_f, candidates);
sort!(candidates; lt=(x,y)->isless(x.criterion, y.criterion)); 

println(candidates[1].fdecl)
println(candidates[1].criterion)