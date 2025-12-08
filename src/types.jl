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
    CandidateFunction wraps a function declaration expression. 
"""
struct CandidateFunction
    fdecl::Expr
    return_type::DataType # TODO: move this to the templates? or together with arg_types to a singleton class?
    arg_types::NamedTuple
end


"""
    TODO
"""
struct MutationContext
    all_exprs::Dict{DataType, ConstsAndExprs} # list of expressions that have value (for every type). no statements like if, for, or assignments allowed.
    f::CandidateFunction
end


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