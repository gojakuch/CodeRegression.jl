using Random
using CodeRegression

include("finding_functions_objectives.jl");

target_f = (x, y) -> (2x*x + 3y - 1) # (x,y)->(2*x) seed 20 # (x, y)->(x/y) seed 20
tf_vec = (q)->target_f(q...)

allowed_ops = Dict{DataType, Vector{AllowedOperationDescription}}(
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
    #=apply_literal_optim=#true, 
    #=literal_optim_iters=#50);
par_types = Tuple(algparams.f_arg_types);
candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];
max_size = 50;
trim_size = 10;
iters = 5;
reproducing_pairs = 8;

Random.seed!(2)
for it in 1:iters
    # mutate
    mutpair(p) = Pair{CandidateFunction, Float64}(mutate(p[1]), NaN64)
    mutants = mutpair.(candidates)
    candidates = cat(candidates, mutants; dims=1)

    # reproduce
    # TODO: maybe figure out a good distribution for how to pick the reproducing pairs, for the best to be ahead??
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

    # literal optimisation
    if algparams.apply_literal_optim
        swap_literals_pair(p) = swap_literals_with_params(p[1])
        ps = swap_literals_pair.(candidates)
        xs = [[x y] for x in -2:0.02:2, y in -2:0.02:2]
        loss = function(f)
            f_vec = (q)->f(q...)
            sum((tf_vec.(xs) - f_vec.(xs)).^2)/100
        end

        for p in ps
            optimize_literals!(p, loss, algparams.literal_optim_iters, 0.01)
            push!(candidates, Pair(p.cf, NaN64))
        end
    end

    # compute objectives and sort
    pf = objective_precompile(candidates, par_types)
    objective_multivar!(tf_vec, candidates, pf)
    sort!(candidates; lt=(x, y)->(isless(x[2], y[2])))
    if length(candidates) > max_size
        candidates = candidates[1:trim_size]
    end

    println("\nbest candidate so far (", it, "):\n", candidates[1][1].fdecl, "\nerror: ", candidates[1][2])
end

println("\nbest candidate:\n", candidates[1][1].fdecl, "\nerror: ", candidates[1][2])

for ci in eachindex(candidates)
    println("\ncandidate ", ci, ":\n", candidates[ci][1].fdecl, "\nerror: ", candidates[ci][2])
end