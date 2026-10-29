# DEFINED IN UTILS
# """
#     all selection algorithm implementations must inherit from this type.
# """
# abstract type SelectionAlgorithmBackend end

select(::Vector{CandidateFunction}, ::SelectionAlgorithmBackend)::Vector{CandidateFunction} = throw("`select` got abstract type `SelectionAlgorithmBackend` and not an actual backend implementation type")

"""
    this is the simplest overload of `select` that the user usually ought to use. it uses the preferred selection method from the `AlgorithmParameters` object available from the first `CandidateFunction` in the given array
"""
function select(candidates::Vector{CandidateFunction{C,A}})::Vector{CandidateFunction{C,A}} where {C,A}
    select(candidates, first(candidates).algparams_ref.selection_backend)
end

function __select_compare(x::CandidateFunction, y::CandidateFunction)::Bool
    if !(x.computed_criterion & y.computed_criterion) 
        throw("`select` received a candidate function `cf` with `cf.computed_criterion==false`")
    end
    isless(x.criterion, y.criterion)
end