include("utils.jl")

function generate_exprs(arg_types::NamedTuple, return_type::DataType, iters=3)::Dict{DataType, Vector}
    check_expr_type(f, :function)

    all_exprs = Dict{DataType, Vector}( # ALL OF THESE LISTS MUST BE NON-EMPTY
        Bool => Any[:(true), :(false)], 
        # Integer => [:0, :1], # TODO: we might need a special unsigned type here for sizes and counters, right?
        Number => Any[:0, :1, :(-1)] # -1 is kinda cheating for now
    )
    for arg in eachindex(arg_types)
        gt = general_type(arg_types[arg])
        if !haskey(all_exprs, gt)
            all_exprs[gt] = []
        end
        push!(all_exprs[gt], arg)
    end
    rt = general_type(return_type) # should we generalise the return type or not?
    if !haskey(all_exprs, rt)
        all_exprs[rt] = []
    end
    if haskey(all_exprs, Any)
        @warn "Any detected. Please specify the parameter and return types in the function signature to avoid issues"
    end

    # TODO: this should be a parameter of some sort, so that the user can adjust it
    all_ops = Dict{Symbol, Tuple}(
        :(<) => ((Number, Number), Bool), # FIXME: only works for numbers but how do we also do the same thing for integers and all the possible type variations later on? 
        :(==) => ((Number, Number), Bool) # FIXME: again, we should somehow signal all the types that we can take as an arg
    )

    for i in 1:iters
        generate_op!(all_exprs, all_ops)
    end

    all_exprs
end

function generate_op!(all_exprs::Dict{DataType, Vector}, all_ops::Dict{Symbol, Tuple})
    (op, signature_tuple) = rand(all_ops) # should we sample the operation space or the select the type at random?

    args = [rand(all_exprs[general_type(type)]) for type in signature_tuple[1]] # maybe general_type is not needed here (surely is for now)

    ex = Expr(:call, op, args...)
    push!(all_exprs[general_type(signature_tuple[2])], ex)
end

function generate_stmt(all_exprs::Dict{DataType, Vector}, arg_types::NamedTuple, return_type::DataType)
    check_expr_type(f, :function)
    r = rand()

    if(r < 0.5)
        return generate_assignment(all_exprs, arg_types)
    elseif r < 0.75
        return generate_return(all_exprs, return_type)
    else
        return generate_if(all_exprs, arg_types, return_type)
    end
end

function generate_assignment(all_exprs::Dict{DataType, Vector}, arg_types::NamedTuple)
    if isempty(arg_types)
        # TODO: create new variable here once we have support for that
        return :(nothing)
    end
    (var, type) = rand(arg_types)

    Expr(
        :(=),
        var,
        rand(all_exprs[general_type(type)])
    )
end

function generate_return(all_exprs::Dict{DataType, Vector}, return_type::DataType)
    candidates = all_exprs[general_type(return_type)]
    if isempty(candidates)
        # FIXME: this situation needs to be avoided, these lists should never be empty in the first place. figure out how to ensure that the return type contains something as well
        @warn "generate_return returned nothing, as no value of the return type has been found"
        return :(nothing)
    end
    return Expr(:return, rand(candidates))
end

function generate_block(all_exprs::Dict{DataType, Vector}, arg_types::NamedTuple, return_type::DataType)
    stmts = [generate_assignment(all_exprs, arg_types)]
    if rand() < 0.5
        push!(stmts, generate_return(all_exprs, return_type))
    end
    return Expr(:block, stmts...)
end

function generate_if(all_exprs::Dict{DataType, Vector}, arg_types::NamedTuple, return_type::DataType)
    candidates_cond = all_exprs[Bool]
    cond = rand(candidates_cond)
    blocks = [generate_block(all_exprs, arg_types, return_type) for _ in 1:rand(1:2)]
    return Expr(:if, cond, blocks...)
end