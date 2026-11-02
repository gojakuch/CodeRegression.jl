using Random

struct Tournament <: SelectionAlgorithmBackend
    max_size::Int
    new_size::Int
    group_size::Int
end

function _best_criterion_idx(candidates)
    b::Float64 = Inf64
    idx::Int = 0
    for i in eachindex(candidates)
        cf = candidates[i]
        if cf.criterion < b
            idx = i
            b = cf.criterion
        end
    end
    return b, idx
end

# implementation taken from Evolutionary.jl for GA selections
function select(candidates::Vector{CandidateFunction{C,A}}, selection::Tournament)::Vector{CandidateFunction{C,A}} where {C,A}
    if length(candidates) > selection.max_size
        selection_res = fill(0, selection.new_size)
        nFitness = length(candidates)
        tour = randperm(nFitness)
        j = 1
        for i in 1:selection.new_size
            idxs = tour[j:j+selection.group_size-1]
            selected = view(candidates, idxs)
            _, winner = _best_criterion_idx(selected)
            selection_res[i] = idxs[winner]
            j+=selection.group_size
            if (j+selection.group_size) >= nFitness && i < selection.new_size
                tour = randperm(rng, nFitness)
                j = 1
            end
        end
        return candidates[selection_res]
    end

    return candidates
end