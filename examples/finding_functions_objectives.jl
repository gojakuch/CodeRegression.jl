function objective!(target_f::Function, candidates::Vector{Pair{CandidateFunction, Float64}}, N = 100)
    points = rand(N) .* 2 .- 1
    push!(points, 0)

    for i in eachindex(candidates)
        cf = candidates[i][1]
        candidates[i] = Pair{CandidateFunction, Float64}(cf, sum(abs.(target_f.(points) .- cf.callable.(points))) / (N+1)) # MAE
    end
end

function objective_multivar!(target_f_vec::Function, candidates::Vector{Pair{CandidateFunction, Float64}}, N = 100)
    points = [(rand(2) .* 4 .- 2) for _ in 1:N]

    for i in eachindex(candidates)
        cf = candidates[i][1]
        if isnan(candidates[i][2])
            f_vec = (q)->(cf.callable(q...))
            candidates[i] = Pair{CandidateFunction, Float64}(candidates[i][1], sum(abs.(target_f_vec.(points) .- f_vec.(points))) / (N+1)) # MAE
        end
    end
end