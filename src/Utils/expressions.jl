using RuntimeGeneratedFunctions

import RuntimeGeneratedFunctions: RuntimeGeneratedFunction

RuntimeGeneratedFunctions.init(@__MODULE__)

"""
Store generated constant expressions separately from expressions that depend on values.

# Fields
- `consts::Vector{Expr}`: Expressions whose arguments are all constants
- `exprs::Vector{Any}`: Expressions that contain variables or non-constant subexpressions
"""
struct ConstsAndExprs
    consts::Vector{Expr}
    exprs::Vector{Any}
end

Base.isempty(ce::ConstsAndExprs) = isempty(ce.consts) && isempty(ce.exprs)


"""
Describe one parameter accepted by a generated operation.

# Arguments
- `type::DataType`: Required parameter type
- `can_be_const::Bool`: Whether a generated argument may be a constant expression
"""
struct _AllowedOperationDescriptionParameter
    type::DataType # FIXME: should generalise the type automatically in its constructor
    can_be_const::Bool
end


"""
Describe an operation that may be used during expression generation and mutation.

# Arguments
- `callee::Symbol`: Name of the operation to call.
- `params`: Parameter descriptions, supplied as named tuples containing `type` and `can_be_const`.

# Returns
- `AllowedOperationDescription`: The normalized operation description.
"""
struct AllowedOperationDescription
    callee::Symbol
    params::Vector{_AllowedOperationDescriptionParameter}
end


"""
Construct an operation description from named tuples with `type` and `can_be_const` fields.
"""
function AllowedOperationDescription(callee::Symbol, params::Vector{NamedTuple})
    paramlist = _AllowedOperationDescriptionParameter[]
    for tup in params
        push!(paramlist, _AllowedOperationDescriptionParameter(tup.type, tup.can_be_const))
    end
    AllowedOperationDescription(callee, paramlist)
end


"""
TODO
Describe the search algorithm and the function signature used by generation, mutation, merging, and literal optimization.

# Fields
- `f_arg_types::NamedTuple`: Argument names and their declared types.
- `f_return_type::DataType`: Declared return type.
- `all_ops::Dict{DataType, Vector{AllowedOperationDescription}}`: Operations grouped by result type.
- `expr_gen_depth::Int`: Number of expression-generation rounds.
- `apply_mutate_to_pure_exprs::Bool`: Whether pure expressions may be recursively changed.
- `apply_literal_optim::Bool`: Whether literal optimization is enabled by the pipeline.
- `literal_optim_iters::Int`: Number of literal-optimization iterations.
"""
struct AlgorithmParameters
    # problem setup details (function signature)
    f_arg_types::NamedTuple
    f_return_type::DataType
    # algorithm details
    all_ops::Dict{DataType, Vector{AllowedOperationDescription}}
    expr_gen_depth::Int
    apply_mutate_to_pure_exprs::Bool
    ## literal optimisation
    apply_literal_optim::Bool
    literal_optim_iters::Int

    # internal fields
    _type_preserving_ops::Dict{DataType, Vector{Pair{AllowedOperationDescription, Vector{Int}}}} # for pure expression mutation. only set if apply_mutate_to_pure_exprs==true. the value pair is an operation and a list with indeces of all its parameters of the same type as the one returned.

    # constructors
    function AlgorithmParameters(
        _f_arg_types::NamedTuple,
        _f_return_type::DataType,
        _all_ops::Dict{DataType, Vector{AllowedOperationDescription}},
        _expr_gen_depth::Int,
        _apply_mutate_to_pure_exprs::Bool,
        _apply_literal_optim::Bool,
        _literal_optim_iters::Int,
    )
        _type_preserving_ops = Dict{DataType, Vector{Pair{AllowedOperationDescription, Vector{Int}}}}()
        if _apply_mutate_to_pure_exprs
            for (rtype, ops) in _all_ops
                _type_preserving_ops[rtype] = AllowedOperationDescription[]
                for op in ops
                    op_added = false
                    idx_arr = Int[]
                    for p_i in eachindex(op.params)
                        if op.params[p_i].type == rtype # assumes that both types are already generalised
                            if !op_added
                                push!(_type_preserving_ops[rtype], (op => idx_arr))
                                op_added = true
                            end
                            push!(idx_arr, p_i)
                        end
                    end
                end
            end
        end
        new(
            _f_arg_types,
            _f_return_type,
            _all_ops,
            _expr_gen_depth,
            _apply_mutate_to_pure_exprs,
            _apply_literal_optim,
            _literal_optim_iters,
            _type_preserving_ops,
        )
    end
end


"""
Wrap a function declaration expression and the algorithm configuration used to transform it.

# Fields
- `fdecl::Expr`: Julia function declaration represented as an expression.
- `algparams_ref::AlgorithmParameters`: Configuration shared by candidates.
- `callable::Union{RuntimeGeneratedFunction, Nothing}`: Generated callable, or `nothing` until compilation.
"""
mutable struct CandidateFunction
    fdecl::Expr
    algparams_ref::AlgorithmParameters
    callable::Union{RuntimeGeneratedFunction, Nothing} # WARNING: check if there's no mismatch between fdecl and callable occuring anywhere if fdecl is changed potentially
end

CandidateFunction(fdecl::Expr, algparams_ref::AlgorithmParameters) = CandidateFunction(fdecl, algparams_ref, nothing)


"""
Create linked algorithm parameters and an initial candidate function.

# Returns
- `Tuple{AlgorithmParameters, CandidateFunction}`: The configuration and candidate sharing that configuration.
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