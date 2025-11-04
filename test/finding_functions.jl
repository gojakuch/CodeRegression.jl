function objective_precompile(candidates::Vector{Pair{Expr, Float64}}, par_types::Tuple)
    pairs_and_functions = Dict{Int, Function}()

    for i in eachindex(candidates)
        def, l = candidates[i]
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

function objective!(target_f::Function, candidates::Vector{Pair{Expr, Float64}}, pairs_and_functions::Dict{Int, Function}, N = 100)
    points = rand(N) .* 2 .- 1
    push!(points, 0)

    for (i, f) in pairs_and_functions
        try 
            candidates[i] = Pair{Expr, Float64}(candidates[i][1], sum(abs.(target_f.(points) .- f.(points))) / (N+1)) # MAE
        catch _
            candidates[i] = Pair{Expr, Float64}(candidates[i][1], Inf)
        end
    end
end