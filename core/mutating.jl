include("generating.jl")

struct FunctionContext # TODO: rename this struct
    exprs::Dict{DataType, Vector} # list of expressions that have value (for every type). no statements like if, for, or assignments allowed.
    arg_types::NamedTuple
    return_type::DataType
    fdecl::Expr
end

FunctionContext() = FunctionContext(Dict{DataType, Vector}(), NamedTuple(), Any, :(1+undefined))
function FunctionContext(_fdecl, gen_depth::Integer) 
    argtypes = get_arg_types(_fdecl)
    rtype = get_return_type(_fdecl)

    FunctionContext(generate_exprs(argtypes, rtype, gen_depth), argtypes, rtype, _fdecl)
end

function mutate_function!(f::Expr, ::FunctionContext)
    check_expr_type(f, :function)

    fc = FunctionContext(f, 1) # TODO: this depth in the generate_exprs call should be a parameter
    mutate!(get_body(f), fc)
end

function insertstmt!(arr, fc::FunctionContext)
    r = rand()
    stmt = generate_stmt(fc.exprs, fc.arg_types, fc.return_type)

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

    # filter indices
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
        conds = fc.exprs[Bool]
        if rand() < 0.5
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
    assign_expr.args[2] = rand(fc.exprs[general_type(fc.arg_types[var])])
end

function mutate_return!(r::Expr, fc::FunctionContext)
    r.args[1] = rand(fc.exprs[general_type(fc.return_type)])
end

function mutate_call!(c::Expr, fc::FunctionContext)
    @warn "cannot mutate calls for now" # TODO: implement this
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

function mutate(f::Expr)::Expr # maybe accept function context here as well
    new_f = deepcopy(f)
    mutate!(new_f, FunctionContext())
    return new_f
end
