include("generating.jl")

struct FunctionContext
    exprs::Vector
    fdecl::Expr
end

FunctionContext() = FunctionContext([], :(1+undefined))

function mutate_function!(f::Expr, ::FunctionContext)
    check_expr_type(f, :function)
    fc::FunctionContext = FunctionContext(generate_regression(f, 1), f)
    mutate!(get_body(f), fc)
end

function insertexpr!(arr, fc::FunctionContext)
    r = rand()
    ex = :(nothing)
    if r < 0.2
        ex = generate_assignment(fc.exprs, fc.fdecl)
    else
        ex = generate_if(fc.exprs)
    end

    if length(arr) > 1
        insert!(arr, rand(1:(length(arr)-1)), ex)
    else
        insert!(arr, 1, ex)
    end
end

function mutate_block!(body::Expr, fc::FunctionContext)
    # just add smth before the return (random line)
    r = rand()
    # body_args = get_body(new_f).args
    if r < 0.4
        insertexpr!(body.args, fc)
        return
    end

    # filter indices
    inds = filter(i -> (typeof(body.args[i]) == Expr), 1:(length(body.args)-1))

    if isempty(inds)
        insertexpr!(body.args, fc)
        return
    end

    ind = rand(inds)
    # remove something
    if r < 0.65
        deleteat!(body.args, ind)
        return
    end

    # modify something (again, we'll need to do this recursively, it's dumb not to)
    # do we need to modify the return in the end?
    mutate!(body.args[ind], fc)
end

function mutate_if!(if_expr::Expr, fc::FunctionContext)
    # choose if we modify the body or cond
    # recursion here later
    r = rand()
    if r < 1/3
        # modify cond
        conds = filter(x -> (typeof(x)==Expr && (x.head == :call)), fc.exprs)
        if !isempty(conds)
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
        insertexpr!(if_expr.args[i].args, fc)
        # r = rand()
        # ex = :(nothing)
        # if r < 0.5
        #     ex = generate_assignment(exprs, new_f)
        # else
        #     ex = generate_if(exprs)
        # end

        # insert!(ex_i.args[i].args, rand(1:(length(ex_i.args[i].args)-1)), ex)
    end
end

function mutate_assign!(assign_expr::Expr, fc::FunctionContext)
    # choose the side
    r = 1
    if length(get_args(fc.fdecl)) > 1 # check if there are other variables to assign to
        r = rand()
    end
    if r < 0.3
        # lhs
        assign_expr.args[1] = rand(get_args(fc.fdecl))
    else
        # TODO: separate recursion for the rhs. potential SR.jl integration here (optional)
        # var = assign_expr.args[1]
        # assign_expr = generate_assignment(fc.exprs, rand(get_args(fc.fdecl)))
        # assign_expr.args[1] = var
        # body.args[ind] = assign_expr
        assign_expr.args[2] = rand(fc.exprs)
    end
end

function mutate_return!(r::Expr, fc::FunctionContext)
    r.args[1] = rand(fc.exprs)
end

function mutate!(e::Expr, fc::FunctionContext)
    dispatch = Dict(
        :function => mutate_function!,
        :block => mutate_block!,
        :if => mutate_if!,
        :(=) => mutate_assign!,
        :return => mutate_return!
    )
    dispatch[e.head](e, fc)
end

function mutate(f::Expr)::Expr
    new_f = deepcopy(f)
    mutate!(new_f, FunctionContext())
    return new_f
end
