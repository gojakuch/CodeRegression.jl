function CandidateFunction(fdecl::Expr, return_type::DataType)
    return CandidateFunction(fdecl, return_type, get_arg_types(fdecl))
end


function MutationContext(_fdecl, _return_type::DataType, gen_depth::Integer)
    _argtypes = get_arg_types(_fdecl)
    MutationContext(generate_exprs(_argtypes, _return_type, gen_depth), CandidateFunction(_fdecl, _return_type, _argtypes))
end