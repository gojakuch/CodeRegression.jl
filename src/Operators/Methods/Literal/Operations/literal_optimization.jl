import CodeRegression.Operators.Utils: CandidateFunction, get_body

using RuntimeGeneratedFunctions

import RuntimeGeneratedFunctions: RuntimeGeneratedFunction
import CodeRegression.Operators.Utils: _cw_

RuntimeGeneratedFunctions.init(@__MODULE__)

"""
Represent a candidate function whose wrapped literals have been replaced by parameters for optimization.

# Fields
- `cf::CandidateFunction`: Original candidate whose declaration is updated after optimization.
- `param_fdecl::Expr`: Declaration with literal parameters appended to its signature.
- `param_f::RuntimeGeneratedFunction`: Callable generated from `param_fdecl`.
- `literals::Vector{Expr}`: Wrapped literal expressions in the parameterized declaration.
- `values::Vector`: Current values assigned to those literals.
- `new_params::Vector{Symbol}`: Parameter names corresponding to `literals` and `values`.
"""
mutable struct ParamLiteralCandidateFunction
    cf::CandidateFunction # original candidate function (copy) TODO: do we need this to be a copy or just assume that the optimisation is reliable and will always improve the function?
    param_fdecl::Expr # declaration of the function where all the literals are parameteres instead
    param_f::RuntimeGeneratedFunction # = kind of like eval(param_fdecl), actually @RuntimeGeneratedFunction(param_fdecl)
    literals::Vector{Expr} # literals from `param_fdecl`, not `cf.fdecl`
    values::Vector # initial values of these literals
    new_params::Vector{Symbol} # names for parameteres, corresponding to each literal in `literals`
end


"""
Replace literal values within a candidate function's AST with parameter variables and compile a parameterized function.

# Arguments
- `cf::CandidateFunction`: The candidate function structure containing the target function declaration AST (`fdecl`).

# Returns
- `ParamLiteralCandidateFunction`
"""
function swap_literals_with_params(cf::CandidateFunction)::ParamLiteralCandidateFunction
    param_decl = deepcopy(cf.fdecl)
    literals = find_literals(param_decl)
    values = Float64[] # FIXME: figure out the types and make this function work for other literals too or skip non-numerical ones
    new_params = Symbol[]

    for i in eachindex(literals)
        lit = literals[i]
        push!(values, lit.args[2])
        param_name = Symbol("_param_literal"*string(i))
        lit.args[2] = param_name
        push!(new_params, param_name)
        push!(param_decl.args[1].args, param_name)
    end

    ParamLiteralCandidateFunction(deepcopy(cf), param_decl, @RuntimeGeneratedFunction(param_decl), literals, values, new_params)
end


"""
Optimize the parameterized literal values using finite-difference gradient descent.

# Arguments
- `plcf::ParamLiteralCandidateFunction`: Parameterized candidate to optimize.
- `loss::Function`: Function that accepts a candidate callable and returns a non-negative loss.
- `iters::Int`: Number of optimization iterations.
- `alpha::Number`: Gradient-descent step size.

# Returns
- `Nothing`: The optimized candidate is stored in `plcf`.
"""
function optimize_literals!(plcf::ParamLiteralCandidateFunction, loss::Function, iters::Int, alpha::Number)
    dx = 0.01
    eps = 0.001

    function generate_f(vals)
        (x...) -> plcf.param_f(x..., vals...)
    end

    for _ in 1:iters
        grad = 0*plcf.values
        f_at_p = generate_f(plcf.values)
        loss_at_p = loss(f_at_p)

        # TODO: compute the gradient more efficiently maybe with a package, use autodiff and stuff. this is just a prototype
        for i in eachindex(plcf.values)
            vals_shifted = copy(plcf.values)
            vals_shifted[i] += dx
            f = generate_f(vals_shifted)
            df = (loss(f) - loss_at_p)/dx
            if abs(df) >= eps 
                grad[i] = df
            end
        end

        plcf.values .-= alpha*grad
    end

    for i in eachindex(plcf.values)
        # replace each literal with the optimal value
        plcf.literals[i].args[2] = plcf.values[i]
    end
    # replace the body of cf.fdecl
    plcf.cf.fdecl.args[2] = get_body(plcf.param_fdecl)
    plcf.cf.callable = nothing
    nothing
end

# TODO: add other constant optimisation methods