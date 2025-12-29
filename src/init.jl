"""
    creates an `AlgorithmParameters` object and a `CandidateFunction` that wraps the initial function declaration, links the objects properly. returns an `AlgorithmParameters` object and a `CandidateFunction` object
"""
function init(_initial_fdecl::Expr, _f_return_type::DataType, _all_ops::Dict{DataType, Vector{AllowedOperationDescription}}, _expr_gen_depth::Int, _apply_mutate_to_pure_exprs::Bool, _apply_literal_optim::Bool, _literal_optim_iters::Int)
    algparams = AlgorithmParameters(
        get_arg_types(_initial_fdecl),
        _f_return_type,
        _all_ops,
        _expr_gen_depth,
        _apply_mutate_to_pure_exprs,
        _apply_literal_optim,
        _literal_optim_iters
    )
    return algparams, CandidateFunction(_initial_fdecl, algparams)
end