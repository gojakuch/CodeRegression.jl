function generate_exprs(algparams::AlgorithmParameters)::Dict{DataType, ConstsAndExprs}
    arg_types = algparams.f_arg_types
    return_type = algparams.f_return_type
    iters = algparams.expr_gen_depth
    all_ops = algparams.all_ops

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
    for rtype in keys(all_ops)
        gt = general_type(rtype)
        if !haskey(all_exprs, gt)
            all_exprs[gt] = ConstsAndExprs(Expr[], [])
        end
    end
    rt = general_type(return_type) # should we generalise the return type or not?
    if !haskey(all_exprs, rt)
        all_exprs[rt] = ConstsAndExprs(Expr[], [])
        @warn "`generate_return` will return nothing, as no value of the return type has been found"
        # FIXME: this must not be empty!
    end
    if haskey(all_exprs, Any)
        @warn "Any detected. Please specify the parameter and return types in the function signature to avoid issues"
    end

    for i in 1:iters
        generate_op!(all_exprs, algparams)
    end

    all_exprs
end

function generate_op!(all_exprs::Dict{DataType, ConstsAndExprs}, algparams::AlgorithmParameters)
    all_ops = algparams.all_ops

    for (rtype, ops) in all_ops # generate some expressions for each available type
        isempty(ops) && continue # skip empty
        
        op_descr = rand(ops)  # there could be some bias, because we use only one "random" function, that mb have some pattern
        op = op_descr.callee
        params = op_descr.params

        are_all_args_const = true
        args = []
        skip_bc_no_exprs_found = false
        for param_info in params
            gpit = general_type(param_info.type)
            if !(gpit in keys(all_exprs))
                # impossible to generate an expression using this operation, skip
                # TODO: instead of skipping, move to another operation if possible (like in `mutate_pure_expression`)
                skip_bc_no_exprs_found = true
                break
            end
            param_type_exprs = all_exprs[gpit]
            if !param_info.can_be_const
                are_all_args_const = false
                push!(args, rand(param_type_exprs.exprs))
            else
                (ex_, is_const) = rand(param_type_exprs)
                push!(args, deepcopy(ex_))
                are_all_args_const = are_all_args_const && is_const
            end
        end
        if skip_bc_no_exprs_found
            # @warn ""
            continue
        end

        ex = Expr(:call, op, args...)
        # `all_exprs[general_type(rtype)]` should already exist (see `generate_exprs`)
        if are_all_args_const
            push!(all_exprs[general_type(rtype)].consts, ex) 
        else
            push!(all_exprs[general_type(rtype)].exprs, ex)
        end
    end
end

function generate_stmt(all_exprs::Dict{DataType, ConstsAndExprs}, algparams::AlgorithmParameters) # returns the statement
    r = rand()
    
    if !isempty(all_exprs[Bool].exprs) # if-statement generation is possible
        if(r < 0.25)
            return generate_assignment(all_exprs, algparams)
        elseif r < 0.5
            return generate_return(all_exprs, algparams)
        end
        return generate_if(all_exprs, algparams)
    end

    if(r < 0.5)
        return generate_assignment(all_exprs, algparams)
    end
    generate_return(all_exprs, algparams)
end

function generate_assignment(all_exprs::Dict{DataType, ConstsAndExprs}, algparams::AlgorithmParameters) # returns the statement
    arg_types = algparams.f_arg_types

    if isempty(arg_types)
        # TODO: create new variable here once we have support for that
        return :(nothing)
    end
    (var, type) = rand(arg_types)

    Expr(
        :(=),
        var,
        deepcopy(rand(all_exprs[general_type(type)])[1])
    )
end

function generate_return(all_exprs::Dict{DataType, ConstsAndExprs}, algparams::AlgorithmParameters) # returns the statement
    return_type = algparams.f_return_type

    candidates = all_exprs[general_type(return_type)]
    if isempty(candidates)
        # FIXME: this situation needs to be avoided, these lists should never be empty in the first place. figure out how to ensure that the return type contains something as well
        @warn "generate_return returned nothing, as no value of the return type has been found"
        return :(nothing)
    end
    return Expr(:return, deepcopy(rand(candidates)[1]))
end

function generate_block(all_exprs::Dict{DataType, ConstsAndExprs}, algparams::AlgorithmParameters) # returns the statement
    arg_types = algparams.f_arg_types
    return_type = algparams.f_return_type

    stmts = [generate_assignment(all_exprs, algparams)]
    if rand() < 0.5
        push!(stmts, generate_return(all_exprs, algparams))
    end
    return Expr(:block, stmts...)
end

function generate_if(all_exprs::Dict{DataType, ConstsAndExprs}, algparams::AlgorithmParameters) # returns the statement
    candidates_cond = all_exprs[Bool].exprs
    cond = deepcopy(rand(candidates_cond))
    blocks = [generate_block(all_exprs, algparams) for _ in 1:rand(1:2)]
    return Expr(:if, cond, blocks...)
end