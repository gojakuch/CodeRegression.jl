struct Truncation <: SelectionAlgorithmBackend
    max_size::Int
    new_size::Int
end

function select(candidates::Vector{CandidateFunction{C,A}}, selection::Truncation)::Vector{CandidateFunction{C,A}} where {C,A}
    if length(candidates) > selection.max_size
        sort!(candidates; lt=__select_compare)
        return candidates[1:selection.new_size]
    end

    return candidates
end