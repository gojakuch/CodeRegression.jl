using Random
using CodeRegression

include("finding_functions_objectives.jl");

target_f = (x)->2.5*sign(x)+0.5 # (x)->2*sign(x); (x)->2.5*sign(x)+0.5; (x)->((x < 0.5 && x > -0.5) ? 1 : 0); or similar functions can be approximated in this example

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
        return _cw_(1.0)
    end), 
    #=return_type=#Float64,  
    #=all_ops=#allowed_ops, 
    #=expr_gen_depth=#3,
    #=apply_mutate_to_pure_exprs=#false,
    #=apply_literal_optim=#true, 
    #=literal_optim_iters=#50);
par_types = Tuple(algparams.f_arg_types);
candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];
max_size = 50;
trim_size = 10;
iters = 10;
reproducing_pairs = 8;

Random.seed!(3)
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

println(candidates[1][1].fdecl)
println(candidates[1][2])