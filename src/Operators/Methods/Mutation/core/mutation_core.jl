import CodeRegression.Operators.Utils: CandidateFunction, ConstsAndExprs
import CodeRegression.Operators.Methods.Generation.GP.Operators: generate_exprs

struct __MutationContext
    all_exprs::Dict{DataType, ConstsAndExprs}
    f::CandidateFunction
end

function __MutationContext(cf::CandidateFunction)
    __MutationContext(generate_exprs(cf.algparams_ref), cf)
end
