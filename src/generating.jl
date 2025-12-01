function generate_exprs(arg_types::NamedTuple, return_type::DataType, iters=3)::Dict{DataType, ConstsAndExprs}
    all_exprs = Dict{DataType, ConstsAndExprs}( # ALL OF THESE LISTS MUST BE NON-EMPTY
        Bool => ConstsAndExprs(make_const_wrap.([true, false]), Any[]),
        Number => ConstsAndExprs(make_const_wrap.([0., 1.]), Any[])
    )
    for arg in eachindex(arg_types)
        gt = general_type(arg_types[arg])
        if !haskey(all_exprs, gt)
            all_exprs[gt] = ConstsAndExprs(Expr[], [])
        end
        push!(all_exprs[gt].exprs, arg)
    end
    rt = general_type(return_type) # should we generalise the return type or not?
    if !haskey(all_exprs, rt)
        all_exprs[rt] = ConstsAndExprs(Expr[], [])
        @warn "generate_return returned nothing, as no value of the return type has been found"
        # FIXME: this must not be empty!
    end
    if haskey(all_exprs, Any)
        @warn "Any detected. Please specify the parameter and return types in the function signature to avoid issues"
    end

    # TODO: this should be a parameter of some sort, so that the user can adjust it. also maybe simply the form in which it is requierd from the user and use this type of thing as the internal represenation only
    all_ops = Dict{DataType, Vector{AllowedOperationDescription}}(
        Bool => [
            AllowedOperationDescription(
                :(<), 
                NamedTuple[(type=Number, can_be_const=false), (type=Number, can_be_const=true)] # FIXME: only works for numbers but how do we also do the same thing for integers and all the possible type variations later on?
            ),
            AllowedOperationDescription(
                :(==), 
                NamedTuple[(type=Number, can_be_const=false), (type=Number, can_be_const=true)] # FIXME: again, we should somehow signal all the types that we can take as an arg
            ),
        ],
        Number => [
            AllowedOperationDescription(
                :(-), 
                NamedTuple[(type=Number, can_be_const=true)]
            ),
        ]
    )

    for i in 1:iters
        generate_op!(all_exprs, all_ops)
    end

    all_exprs
end

function generate_op!(all_exprs::Dict{DataType, ConstsAndExprs}, all_ops::Dict)
    for (rtype, ops) in all_ops # generate some expressions for each available type
        isempty(ops) && continue # skip empty
        
        op_descr = rand(ops)
        op = op_descr.callee
        params = op_descr.params

        are_all_args_const = true
        args = []
        for param_info in params
            if !param_info.can_be_const
                are_all_args_const = false
                push!(args, rand(all_exprs[general_type(param_info.type)].exprs))
            else
                (ex, is_const) = rand(all_exprs[general_type(param_info.type)])
                push!(args, ex)
                are_all_args_const = are_all_args_const && is_const
            end
        end

        ex = Expr(:call, op, args...)
        if are_all_args_const
            push!(all_exprs[general_type(rtype)].consts, ex)
        else
            push!(all_exprs[general_type(rtype)].exprs, ex)
        end
    end
end

function generate_stmt(all_exprs::Dict{DataType, ConstsAndExprs}, arg_types::NamedTuple, return_type::DataType)
    r = rand()

    if(r < 0.25)
        return generate_assignment(all_exprs, arg_types)
    elseif r < 0.5
        return generate_return(all_exprs, return_type)
    end
    return generate_if(all_exprs, arg_types, return_type)
end

function generate_assignment(all_exprs::Dict{DataType, ConstsAndExprs}, arg_types::NamedTuple)
    if isempty(arg_types)
        # TODO: create new variable here once we have support for that
        return :(nothing)
    end
    (var, type) = rand(arg_types)

    Expr(
        :(=),
        var,
        rand(all_exprs[general_type(type)])[1]
    )
end

function generate_return(all_exprs::Dict{DataType, ConstsAndExprs}, return_type::DataType)
    candidates = all_exprs[general_type(return_type)]
    if isempty(candidates)
        # FIXME: this situation needs to be avoided, these lists should never be empty in the first place. figure out how to ensure that the return type contains something as well
        @warn "generate_return returned nothing, as no value of the return type has been found"
        return :(nothing)
    end
    return Expr(:return, rand(candidates)[1])
end

function generate_block(all_exprs::Dict{DataType, ConstsAndExprs}, arg_types::NamedTuple, return_type::DataType)
    stmts = [generate_assignment(all_exprs, arg_types)]
    if rand() < 0.5
        push!(stmts, generate_return(all_exprs, return_type))
    end
    return Expr(:block, stmts...)
end

function generate_if(all_exprs::Dict{DataType, ConstsAndExprs}, arg_types::NamedTuple, return_type::DataType)
    candidates_cond = all_exprs[Bool].exprs
    cond = rand(candidates_cond)
    blocks = [generate_block(all_exprs, arg_types, return_type) for _ in 1:rand(1:2)]
    return Expr(:if, cond, blocks...)
end