function CandidateFunction(fdecl::Expr, return_type::DataType)
    return CandidateFunction(fdecl, return_type, get_arg_types(fdecl))
end

function CandidateFunction(fdecl::Expr, return_type::DataType, arg_types::NamedTuple)
    check_expr_type(fdecl, :function)
    literal_wraps = Expr[]
    # TODO: implement recursive search with a visitor here
    return CandidateFunction(fdecl, return_type, arg_types, literal_wraps)
end


function MutationContext(_fdecl, return_type::DataType, gen_depth::Integer)
    argtypes = get_arg_types(_fdecl)
    MutationContext(generate_exprs(argtypes, return_type, gen_depth), CandidateFunction(_fdecl, return_type, argtypes))
end