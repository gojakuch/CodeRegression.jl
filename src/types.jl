"""
    struct ConstsAndExprs{T}
        consts::Vector{T}
        exprs::Vector{Any}
    end
"""
struct ConstsAndExprs{T}
    consts::Vector{T}
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