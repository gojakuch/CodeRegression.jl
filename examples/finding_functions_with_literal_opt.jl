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
    #=literal_optim_iters=#50,
    #=_candidate_function_criterion_type=#Float64);
par_types = Tuple(algparams.f_arg_types);
candidates = CandidateFunction{Float64}[init_f];
max_size = 50;
trim_size = 10;
iters = 3;
reproducing_pairs = 8;

Random.seed!(3);
for it in 1:iters
    # mutate
    mutants = mutate.(candidates)
    candidates = cat(candidates, mutants; dims=1)

    # crossover
    # TODO: PROPER SELECTION STAGE AND REPRODUCTION + SELECTION MATCHING
    children = CandidateFunction{Float64}[]
    for rp in 1:reproducing_pairs
        if rp+1 > length(candidates)
            break
        end
        parent1 = candidates[rp]
        parent2 = rand(candidates[(rp+1):end])
        push!(children, crossover(parent1, parent2))
    end
    candidates = cat(candidates, children; dims=1)

    # literal optimisation
    if algparams.apply_literal_optim
        ps = swap_literals_with_params.(candidates)
        xs = -2:0.001:2
        loss = function(f)
            sum((target_f.(xs) - f.(xs)).^2)/100
        end

        for p in ps
            optimize_literals!(p, loss, algparams.literal_optim_iters, 0.01)
            push!(candidates, p.cf)
        end
    end

    # compute objectives and sort
    generate_callable!.(candidates)
    objective!(target_f, candidates)
    sort!(candidates; lt=(x, y)->(isless(x.criterion, y.criterion)))
    if length(candidates) > max_size
        candidates = candidates[1:trim_size]
    end
end

println(candidates[1].fdecl)
println(candidates[1].criterion)