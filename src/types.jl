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
struct FunctionContext # TODO: rename this struct
    all_exprs::Dict{DataType, ConstsAndExprs} # list of expressions that have value (for every type). no statements like if, for, or assignments allowed.
    arg_types::NamedTuple
    return_type::DataType
    fdecl::Expr
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