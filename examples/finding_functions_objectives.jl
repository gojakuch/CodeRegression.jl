function objective_precompile(candidates::Vector{Pair{CandidateFunction, Float64}}, par_types::Tuple)
    pairs_and_functions = Dict{Int, Function}()

    for i in eachindex(candidates)
        cf, l = candidates[i]
        def = cf.fdecl
        if isnan(l)
            f = eval(def)
            precompile(f, par_types)
            pairs_and_functions[i] = f
        end
    end

    pairs_and_functions
end

function objective!(target_f::Function, candidates::Vector{Pair{CandidateFunction, Float64}}, pairs_and_functions::Dict{Int, Function}, N = 100)
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

function objective_multivar!(target_f_vec::Function, candidates::Vector{Pair{CandidateFunction, Float64}}, pairs_and_functions::Dict{Int, Function}, N = 100)
    points = [(rand(2) .* 4 .- 2) for _ in 1:N]

    for (i, f) in pairs_and_functions
        # try 
            f_vec = (q)->(f(q...))
            candidates[i] = Pair{CandidateFunction, Float64}(candidates[i][1], sum(abs.(target_f_vec.(points) .- f_vec.(points))) / (N+1)) # MAE
        # catch _
        #     candidates[i] = Pair{CandidateFunction, Float64}(candidates[i][1], Inf)
        # end
    end
end