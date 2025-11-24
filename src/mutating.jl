# FunctionContext() = FunctionContext(Dict{DataType, Vector}(), NamedTuple(), Any, :(1+undefined))
function FunctionContext(_fdecl, return_type::DataType, gen_depth::Integer)
    argtypes = get_arg_types(_fdecl)
    FunctionContext(generate_exprs(argtypes, return_type, gen_depth), argtypes, return_type, _fdecl)
end

function mutate_function!(f::Expr, ::FunctionContext)
    throw("tried to modify a nested function decl. nested functions are not allowed")
end

function insertstmt!(arr, fc::FunctionContext)
    stmt = generate_stmt(fc.all_exprs, fc.arg_types, fc.return_type)

    if length(arr) > 1
        insert!(arr, rand(1:(length(arr)-1)), stmt)
    else
        insert!(arr, 1, stmt)
    end
end

function mutate_block!(body::Expr, fc::FunctionContext)
    # just add smth before the return (random line)
    r = rand()
    # body_args = get_body(new_f).args
    if r < 0.4
        insertstmt!(body.args, fc)
        return
    end

    # filter indices # FIXME: remove this filter
    inds = filter(i -> (typeof(body.args[i]) == Expr), 1:(length(body.args)-1))

    if isempty(inds)
        insertstmt!(body.args, fc)
        return
    end

    ind = rand(inds)
    # remove something
    if r < 0.65
        deleteat!(body.args, ind)
        return
    end

    # do we need to modify the return in the end?
    mutate!(body.args[ind], fc)
end

function mutate_if!(if_expr::Expr, fc::FunctionContext)
    # choose if we modify the body or cond
    # recursion here later
    r = rand()
    if r < 1/3
        # modify cond
        conds = fc.all_exprs[Bool].exprs
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
        insertstmt!(if_expr.args[i].args, fc)
    end
end

function mutate_assign!(assign_expr::Expr, fc::FunctionContext)
    # TODO: add a possible lhs modification with proper types
    # TODO: separate recursion for the rhs (mutate_expr or smth if it's a literal). potential SR.jl integration here (optional)
    # var = assign_expr.args[1]
    # assign_expr = generate_assignment(fc.exprs, rand(get_args(fc.fdecl)))
    # assign_expr.args[1] = var
    # body.args[ind] = assign_expr

    var = assign_expr.args[1]
    assign_expr.args[2] = rand(fc.all_exprs[general_type(fc.arg_types[var])])
end

function mutate_return!(r::Expr, fc::FunctionContext)
    r.args[1] = rand(fc.all_exprs[general_type(fc.return_type)])[1]
end

function mutate_call!(c::Expr, fc::FunctionContext)
    @warn "cannot mutate calls yet" # TODO: implement this
end

function mutate!(e::Expr, fc::FunctionContext)
    dispatch = Dict(
        :function => mutate_function!,
        :block => mutate_block!,
        :if => mutate_if!,
        :(=) => mutate_assign!,
        :return => mutate_return!,
        :call => mutate_call!
    )
    if haskey(dispatch, e.head)
        dispatch[e.head](e, fc)
    end
end

"""
    mutates a function declaration and returns the new one.
    
    the only mutate wraper the user should call. only accepts function declarations as f.
"""
function mutate(f::Expr, return_type::DataType, expr_gen_depth::Int=1)::Expr
    check_expr_type(f, :function)
    new_f = deepcopy(f)
    mutate!(get_body(new_f), FunctionContext(new_f, return_type, expr_gen_depth))
    return new_f
end
