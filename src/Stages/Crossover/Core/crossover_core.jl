# DEFINED IN UTILS
# """
#     all crossover algorithm implementations must inherit from this type.
# """
# abstract type CrossoverAlgorithmBackend end


"""
    this is the simplest overload of `crossover` that the user usually ought to use. it uses the preferred crossover method from the `AlgorithmParameters` object available from the first `CandidateFunction`
"""
function crossover(cf1::CandidateFunction{C,A}, cf2::CandidateFunction{C,A})::CandidateFunction{C,A} where {C,A}
    crossover(cf1, cf2, cf1.algparams_ref.crossover_backend)
end