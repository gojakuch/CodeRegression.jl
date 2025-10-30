using Random
include("../core/merging.jl")
include("../core/mutating.jl")

target_f = sign

function objective_precompile(candidates::Vector{Pair{Expr, Float32}})
    pairs_and_functions = Dict{Int, Function}()

    for i in eachindex(candidates)
        def, l = candidates[i]
        if isnan(l)
            f = x -> Inf
            try # TODO: REMOVE THAT AFTER FIXING THE ISSUES
                f = eval(def)
            catch er
            end
            precompile(f, (Float32,))
            pairs_and_functions[i] = function (x)
                try # TODO: REMOVE THAT AFTER FIXING THE ISSUES
                    return f(x)
                catch er
                    return Inf
                end
            end
        end
    end

    pairs_and_functions
end

function objective!(candidates::Vector{Pair{Expr, Float32}}, pairs_and_functions::Dict{Int, Function}, N = 100)
    points = rand(N) .* 2 .- 1
    push!(points, 0)

    for (i, f) in pairs_and_functions
        candidates[i] = Pair{Expr, Float32}(candidates[i][1], sum(abs.(target_f.(points) .- f.(points))) / (N+1)) # MAE
    end
end

init_f = :(function (x)
        return 1
    end);
candidates = Pair{Expr, Float32}[Pair(init_f, NaN)];
max_size = 50;
trim_size = 10;
iters = 10;
reproducing_pairs = 4;

for it in 1:iters
    # mutate
    mutpair(p) = Pair{Expr, Float32}(mutate(p[1]), NaN)
    mutants = mutpair.(candidates)
    candidates = cat(candidates, mutants; dims=1)

    # reproduce
    # TODO: maybe figure out a good distribution for how to pick the reproducing pairs, for the best to be ahead??
    children = Pair{Expr, Float32}[]
    for _ in 1:reproducing_pairs
        shuffle!(candidates)
        parents = candidates[1:2]
        try # FIXME: remove and check for errors??
        push!(children, (reproduce(parents[1][1], parents[2][1]) => NaN32)) # possible duplicates
        catch
        end
    end
    candidates = cat(candidates, children; dims=1)

    # compute objectives and sort
    pf = objective_precompile(candidates)
    objective!(candidates, pf)
    sort!(candidates; lt=(x, y)->(isless(x[2], y[2])))
    if length(candidates) > max_size
        candidates = candidates[1:trim_size]
    end
end

println(candidates[1])