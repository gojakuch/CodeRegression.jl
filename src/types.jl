"""
    struct ConstsAndExprs
        consts::Vector{Expr}
        exprs::Vector{Any}
    end
"""
struct ConstsAndExprs
    consts::Vector{Expr}
    exprs::Vector{Any}
end

Base.isempty(ce::ConstsAndExprs) = isempty(ce.consts) && isempty(ce.exprs)


"""
    TODO
"""
struct _AllowedOperationDescriptionParameter
    type::DataType
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
    ## literal optimisation
    apply_literal_optim::Bool
    literal_optim_iters::Int
end


"""
    `CandidateFunction` wraps a function declaration expression. 
"""
struct CandidateFunction
    fdecl::Expr
    algparams_ref::AlgorithmParameters
end


"""
    TODO
"""
struct MutationContext
    all_exprs::Dict{DataType, ConstsAndExprs} # list of expressions that have value (for every type). no statements like if, for, or assignments allowed.
    f::CandidateFunction
end