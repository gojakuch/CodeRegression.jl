using Random
using CodeRegression

include("finding_functions_objectives.jl");

target_f = (x)->2*sign(x)

init_f = CandidateFunction(:(function (x::Float64)
        return 1
    end), #=return_type=#Float64);
par_types = Tuple(init_f.arg_types);
return_type = init_f.return_type;
candidates = Pair{CandidateFunction, Float64}[Pair(init_f, NaN)];
max_size = 50;
trim_size = 10;
iters = 5;
reproducing_pairs = 8;
gen_depth = 3;

Random.seed!(20)
for it in 1:iters
    # mutate
    mutpair(p) = Pair{CandidateFunction, Float64}(mutate(p[1], gen_depth), NaN64)
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
    swap_literals_pair(p) = swap_literals_with_params(p[1])
    ps = swap_literals_pair.(candidates)
    xs = -2:0.001:2
    loss = function(f)
        sum((target_f.(xs) - f.(xs)).^2)/100
    end

    for p in ps
        optimize_literals!(p, loss, 50, 0.01)
        push!(candidates, Pair(p.cf, NaN64))
    end

    # compute objectives and sort
    pf = objective_precompile(candidates, par_types)
    objective!(target_f, candidates, pf)
    sort!(candidates; lt=(x, y)->(isless(x[2], y[2])))
    if length(candidates) > max_size
        candidates = candidates[1:trim_size]
    end
end

println(candidates[1])