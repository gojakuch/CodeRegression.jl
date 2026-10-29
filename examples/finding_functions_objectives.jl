function objective!(target_f::Function, candidates::Vector{CandidateFunction{Float64, T}}, N = 100) where T
    points = rand(N) .* 2 .- 1
    push!(points, 0)

    for cf in candidates # NEEDS TO BE A LOOP: unified points sample for everybody
        cf.criterion = sum(abs.(target_f.(points) .- cf.callable.(points))) / (N+1) # MAE
        cf.computed_criterion = true
    end
end

function objective_multivar!(target_f_vec::Function, candidates::Vector{CandidateFunction{Float64, T}}, N = 100) where T
    points = [(rand(2) .* 4 .- 2) for _ in 1:N]

    for cf in candidates
        f_vec = (q)->(cf.callable(q...))
        cf.criterion = sum(abs.(target_f_vec.(points) .- f_vec.(points))) / (N+1) # MAE
        cf.computed_criterion = true
    end
end