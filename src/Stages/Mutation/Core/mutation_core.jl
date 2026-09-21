import CodeRegression.Operators.Utils: CandidateFunction, ConstsAndExprs
import CodeRegression.Operators.Methods.Generation.GP.Operators: generate_exprs

"""
Hold generated expressions and the candidate used by the mutation visitors.

# Fields
- `all_exprs::Dict{DataType, ConstsAndExprs}`: Typed expressions available to mutation.
- `f::CandidateFunction`: Candidate being mutated.
"""
struct __MutationContext
    all_exprs::Dict{DataType, ConstsAndExprs}
    f::CandidateFunction
end


"""
Create a mutation context and generate its typed expression pool.
"""
function __MutationContext(cf::CandidateFunction)
    __MutationContext(generate_exprs(cf.algparams_ref), cf)
end
