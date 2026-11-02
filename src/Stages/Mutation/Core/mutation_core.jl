# DEFINED IN UTILS
# """
#     all mutation algorithm implementations must inherit from this type.
# """
# abstract type MutationAlgorithmBackend end


"""
    this is the simplest overload of `mutate` that the user usually ought to use. it uses the preferred mutation method from the `AlgorithmParameters` object available from the first `CandidateFunction`
"""
function mutate(cf::CandidateFunction{C,A})::CandidateFunction{C,A} where {C,A}
    mutate(cf, cf.algparams_ref.mutation_backend)
end


"""
Contains generated expressions and the candidate used by the mutation visitors.

# Fields
- `all_exprs::Dict{Type, ConstsAndExprs}`: Typed expressions available to mutation.
- `f::CandidateFunction`: Candidate being mutated.
"""
struct __MutationContext
    all_exprs::Dict{Type, ConstsAndExprs}
    f::CandidateFunction
end


"""
Create a mutation context and generate its typed expression pool.
"""
function __MutationContext(cf::CandidateFunction)
    __MutationContext(generate_exprs(cf.algparams_ref), cf)
end
