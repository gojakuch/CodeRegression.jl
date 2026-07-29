using RuntimeGeneratedFunctions

import RuntimeGeneratedFunctions: RuntimeGeneratedFunction

RuntimeGeneratedFunctions.init(@__MODULE__)

struct ConstsAndExprs
    consts::Vector{Expr}
    exprs::Vector{Any}
end

Base.isempty(ce::ConstsAndExprs) = isempty(ce.consts) && isempty(ce.exprs)


"""
    TODO
"""
struct _AllowedOperationDescriptionParameter
    type::DataType # FIXME: should generalise the type automatically in its constructor
    can_be_const::Bool
end

"""
    TODO
"""
struct AllowedOperationDescription
    callee::Symbol
    params::Vector{_AllowedOperationDescriptionParameter}
end

function AllowedOperationDescription(callee::Symbol, params::Vector{NamedTuple})
    paramlist = _AllowedOperationDescriptionParameter[]
    for tup in params
        push!(paramlist, _AllowedOperationDescriptionParameter(tup.type, tup.can_be_const))
    end
    AllowedOperationDescription(callee, paramlist)
end


"""
    describes the search algorithm. an object of this type should be passed to all the mutation, merging, and generation operations.
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
    `CandidateFunction` wraps a function declaration expression. 
"""
mutable struct CandidateFunction
    fdecl::Expr
    algparams_ref::AlgorithmParameters
    callable::Union{RuntimeGeneratedFunction, Nothing} # WARNING: check if there's no mismatch between fdecl and callable occuring anywhere if fdecl is changed potentially
end

CandidateFunction(fdecl::Expr, algparams_ref::AlgorithmParameters) = CandidateFunction(fdecl, algparams_ref, nothing)


"""
    creates an `AlgorithmParameters` object and a `CandidateFunction` that wraps 
    the initial function declaration, links the objects properly. returns an 
    `AlgorithmParameters` object and a `CandidateFunction` object
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