using Random
using CodeRegression

include("finding_functions_objectives.jl");

target_f = (x, y) -> (2x*x + 3y - 1) # (x,y)->(2*x) seed 20 # (x, y)->(x/y) seed 20
tf_vec = (q)->target_f(q...)

allowed_ops = Dict{Type, Vector{AllowedOperationDescription}}(
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
    ]
)
algparams, init_f = CodeRegression.init(
    #=initial_fdecl=# :(function (x::Float64, y::Float64)
        return 1
    end), 
    #=return_type=#Float64,  
    #=all_ops=#allowed_ops, 
    #=expr_gen_depth=#3,
    #=apply_mutate_to_pure_exprs=#true, # this example does require proper pure expression mutation.
    #=selection_backend=#Truncation(#=max_size=#50, #=new_size=#10),
    #=apply_literal_optim=#true, 
    #=literal_optim_iters=#50,
    #=_candidate_function_criterion_type=#Float64);
par_types = Tuple(algparams.f_arg_types);
candidates = [init_f];
iters = 5;
reproducing_pairs = 8;

Random.seed!(2);
for it in 1:iters
    # mutate
    mutants = mutate.(candidates)
    candidates = cat(candidates, mutants; dims=1)

    # literal optimisation
    if algparams.apply_literal_optim
        ps = swap_literals_with_params.(candidates)
        xs = [[x y] for x in -2:0.02:2, y in -2:0.02:2]
        loss = function(f)
            f_vec = (q)->f(q...)
            sum((tf_vec.(xs) - f_vec.(xs)).^2)/100
        end

        for p in ps
            optimize_literals!(p, loss, algparams.literal_optim_iters, 0.01)
            push!(candidates, p.cf)
        end
    end

    # selection stage
    objective_multivar!(tf_vec, candidates)
    candidates = select(candidates)

    # crossover    
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

    println("\nbest candidate so far (", it, "):\n", candidates[1].fdecl, "\nerror: ", candidates[1].criterion)
end

# sort again before choosing the best one
objective_multivar!(tf_vec, candidates);
sort!(candidates; lt=(x,y)->isless(x.criterion, y.criterion)); 

println("\nbest candidate:\n", candidates[1].fdecl, "\nerror: ", candidates[1].criterion)

for ci in eachindex(candidates)
    println("\ncandidate ", ci, ":\n", candidates[ci].fdecl, "\nerror: ", candidates[ci].criterion)
end