using Random
using CodeRegression

target_f = abs

function objective_precompile(candidates::Vector{Pair{CandidateFunction, Float64}}, par_types::Tuple)
    pairs_and_functions = Dict{Int, Function}()

    for i in eachindex(candidates)
        cf, l = candidates[i]
        def = cf.fdecl
        if isnan(l)
            f = eval(def)
            precompile(f, par_types)
            pairs_and_functions[i] = function (x)
                return f(x)
            end
        end
    end

    pairs_and_functions
end

function objective!(candidates::Vector{Pair{CandidateFunction, Float64}}, pairs_and_functions::Dict{Int, Function}, N = 100)
    points = rand(N) .* 2 .- 1
    push!(points, 0)

    for (i, f) in pairs_and_functions
        try 
            candidates[i] = Pair{CandidateFunction, Float64}(candidates[i][1], sum(abs.(target_f.(points) .- f.(points))) / (N+1)) # MAE
        catch _
            candidates[i] = Pair{CandidateFunction, Float64}(candidates[i][1], Inf)
        end
    end
end

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

Random.seed!(2)
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

    # compute objectives and sort
    pf = objective_precompile(candidates, par_types)
    objective!(candidates, pf)
    sort!(candidates; lt=(x, y)->(isless(x[2], y[2])))
    if length(candidates) > max_size
        candidates = candidates[1:trim_size]
    end
end

println(candidates[1])