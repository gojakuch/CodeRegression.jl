# this file describes the mutation visitor based on the general visitor template in "visitor_template.jl"

function mutate_function!(::Expr, ::MutationContext)
    throw("tried to modify a nested function decl. nested functions are not allowed")
end

function insertstmt!(arr, mc::MutationContext)
    stmt = generate_stmt(mc.all_exprs, mc.f.algparams_ref)

    if length(arr) > 1
        insert!(arr, rand(1:(length(arr)-1)), stmt)
    else
        insert!(arr, 1, stmt)
    end
end

function mutate_block!(body::Expr, mc::MutationContext)
    # just add smth before the return (random line)
    r = rand()
    # body_args = get_body(new_f).args
    if r < 0.4
        insertstmt!(body.args, mc)
        return
    end

    # filter indices # FIXME: remove this filter
    inds = filter(i -> (typeof(body.args[i]) == Expr), 1:(length(body.args)-1))

    if isempty(inds)
        insertstmt!(body.args, mc)
        return
    end

    ind = rand(inds)
    # remove something
    if r < 0.65
        deleteat!(body.args, ind)
        return
    end

    # do we need to modify the return in the end?
    mutate!(body.args[ind], mc)
end

function mutate_if!(if_expr::Expr, mc::MutationContext)
    # choose if we modify the body or cond
    # recursion here later
    r = rand()
    if r < 1/3
        # modify cond
        conds = mc.all_exprs[Bool].exprs
        if !isempty(conds) && rand() < 0.5 # conds should not be empty if we do everything correctly
            if_expr.args[1] = rand(conds)
        else
            if_expr.args[1] = Expr(:call, :(!), if_expr.args[1])
        end
    else
        # insert to the block
        i = 2 + (length(if_expr.args) > 2 && rand() > 0.5) # decide if we append to the if or to the else
        if typeof(if_expr.args[i]) != Expr
            if_expr.args[i] = Expr(:block, if_expr.args[i])
        end
        insertstmt!(if_expr.args[i].args, mc)
    end
end

"""
    this function does not follow the typical mutation visitor pattern because it does not mutate the original expression.
    it is used to mutate rhs of assignments or subexpressions of return statements.

    `ex` is supposed to be a pure expression (or a Symbol or value), and `dt` its type.
"""
function mutate_pure_expression(ex, dt::DataType, mc::MutationContext)
    gdt = general_type(dt)
    if !mc.f.algparams_ref.apply_mutate_to_pure_exprs || isempty(mc.f.algparams_ref._type_preserving_ops[gdt])
        # if apply_mutate_to_pure_exprs==false or there are no type-preserving operations for `gdt` return a random expression of this type
        return rand(mc.all_exprs[gdt])[1]
    end

    # TODO: dispatch on `ex`
    r = rand()
    nosubexprs = typeof(ex) != Expr || (ex.head == :call && ex.args[1] == :_cw_) # TODO: is everything covered by this check?
    if nosubexprs || 3*r < 1
        # add something: apply a random type-preserving operation
        (op, idx_arr) = rand(mc.f.algparams_ref._type_preserving_ops[gdt])
        selected_i = rand(idx_arr) 
        args = []
        for i in eachindex(op.params)
            param_info = op.params[i]
            if i == selected_i
                push!(args, ex)
                continue
            end
            if !param_info.can_be_const # TODO: add an option to add an optimisable literal coefficient here for all the new terms of type `Number`
                push!(args, rand(mc.all_exprs[general_type(param_info.type)].exprs))
            else
                (ex_, _) = rand(mc.all_exprs[general_type(param_info.type)])
                push!(args, deepcopy(ex_))
            end
        end

        return Expr(:call, op.callee, args...)
    elseif 3*r < 2
        # remove something in the expression

        # 1. if the expression is formed using a type-preserving operation, just get one of its arguments and return
        if ex.head == :call
            for (op, param_idx_arr) in mc.f.algparams_ref._type_preserving_ops[gdt]
                if op.callee == ex.args[1] && length(op.params) == (length(ex.args)-1) # FIXME: this is not enough. some argument types might still differ
                    param_idx = rand(param_idx_arr)+1
                    return deepcopy(ex.args[param_idx])
                end
            end
        end
        # 2. otherwise, go to "change a subexpression"
    end

    # change a subexpression: determine a random subexpression and it's type and call mutate_pure_expression on it
    if ex.head == :call
        for op::AllowedOperationDescription in mc.f.algparams_ref.all_ops[gdt]
            if op.callee == ex.args[1] && length(op.params) == (length(ex.args)-1) # FIXME: this is not enough. some argument types might still differ
                new_ex = deepcopy(ex)
                param_idx = rand(eachindex(op.params))+1
                new_ex.args[param_idx] = mutate_pure_expression(new_ex.args[param_idx], op.params[param_idx-1].type, mc) # FIXME: tis can mess up the `can_be_const`
                return new_ex
            end
        end
    end

    @warn "something went wrong inside `mutate_pure_expression` and this line was reached. `ex` was: "*string(ex)
end

function mutate_assign!(assign_expr::Expr, mc::MutationContext)
    # potential SR.jl integration here (optional)

    var = assign_expr.args[1] # TODO: add a possible lhs modification with proper types
    assign_expr.args[2] = mutate_pure_expression(assign_expr.args[2], mc.f.algparams_ref.f_arg_types[var], mc)
end

function mutate_return!(r::Expr, mc::MutationContext)
    r.args[1] = mutate_pure_expression(r.args[1], mc.f.algparams_ref.f_return_type, mc)
end

function mutate_call!(c::Expr, mc::MutationContext)
    @warn "cannot mutate calls yet" # TODO: implement this like in `mutate_pure_expression`
end

function mutate!(e::Expr, mc::MutationContext)
    dispatch = Dict(
        :function => mutate_function!,
        :block => mutate_block!,
        :if => mutate_if!,
        :(=) => mutate_assign!,
        :return => mutate_return!,
        :call => mutate_call!
    )
    if haskey(dispatch, e.head)
        dispatch[e.head](e, mc)
    end
end

"""
    mutates a CandidateFunction and returns the new one.
    
    the only mutate wraper the user should call.
"""
function mutate(cf::CandidateFunction)::CandidateFunction
    new_f = deepcopy(cf.fdecl)
    new_cf = CandidateFunction(new_f, cf.algparams_ref)
    mutate!(get_body(new_f), MutationContext(new_cf))
    return new_cf
end
