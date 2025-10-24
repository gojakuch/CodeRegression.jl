include("utils.jl")

# TODO: generate statements, LHS, and RHS expression lists separately. manage these lists properly so that this helps to achieve the optimum

function generate_regression(f::Expr, iters=10)
    check_expr_type(f, :function)

    all_exprs = get_args(f)
    # TODO: values!!
    push!(all_exprs, :0)
    push!(all_exprs, :1)
    push!(all_exprs, :(-1)) # FIXME: kinda cheating for now. should be generated from 1 naturally via the RHS mutator

    for i in 1:iters
        derive_new_expr!(all_exprs, f, rand())
    end

    all_exprs
end

function derive_new_expr!(all_exprs::Vector, f, r)
    if(r < 0.5)
        push!(all_exprs, generate_assignment(all_exprs, f))
    elseif(r < 0.75)
        push!(all_exprs, generate_bin_op(all_exprs))
    elseif r < 0.95
        push!(all_exprs, generate_return(all_exprs))
    elseif r < 1 
        push!(all_exprs, generate_if(all_exprs))
    end
end

function generate_assignment(all_exprs::Vector, f::Expr)
    # TODO: we should accept 2 different arrays: for conds and for bodies generated separately if we want to continue using this approach. filtering is inefficient. 
    candidates = filter(x -> !(typeof(x)==Expr && (x.head == :if || x.head == :return)), all_exprs) # TODO remove typeof
    Expr(
        :(=),
        rand(get_args(f)),
        rand(candidates)
    )
end

function generate_bin_op(all_exprs::Vector, ConstProb = 0.5, BinProb = 0.5)
    r = rand()

    CurrProb = ConstProb
    if r < CurrProb
        candidates = filter(x -> !(typeof(x)==Expr && (x.head == :if || x.head == :return || x.head == :(=))), all_exprs) # TODO remove typeofs in all those filters. actually, remove the filters entirely, only accept arrays with what's acceptable
        if isempty(candidates)
            return :(nothing)
        end
        return rand(candidates)
    end

    CurrProb += BinProb
    if r < CurrProb
        r_norm = (r - CurrProb) / BinProb + 1
        if r_norm < 1/3
            ex = :(0 > 0)
        elseif r_norm < 2/3
            ex = :(0 == 0)
        else
            ex = :(0 < 0)
        end
        ConstProb, BinProb = ConstProb + BinProb / 2, BinProb / 2
        left = generate_bin_op(all_exprs, ConstProb, BinProb)
        ex.args[2] = left #(typeof(left) == Expr) ? left.args[end] : left # TODO remove typeof
        right = generate_bin_op(all_exprs, ConstProb, BinProb)
        ex.args[3] = right #(typeof(right) == Expr) ? right.args[end] : right # TODO remove typeof
    end

    return ex
end

function generate_return(all_exprs::Vector)
    # TODO: we should accept 2 different arrays: for conds and for bodies generated separately if we want to continue using this approach. filtering is inefficient. 
    candidates = filter(x -> !(typeof(x)==Expr && (x.head == :if || x.head == :return || x.head == :(=))), all_exprs) # TODO remove typeof
    if isempty(candidates)
        return :(nothing)
    end
    c = rand(candidates)
    return Expr(:return, ((typeof(c) == Expr) ? c.args[1] : c)) # TODO remove typeof
end

function generate_if(all_exprs::Vector)
    # TODO: we should accept 2 different arrays: for conds and for bodies generated separately if we want to continue using this approach. filtering is inefficient. 
    candidates_cond = filter(x -> !(typeof(x)==Expr && (x.head == :if || x.head == :return)), all_exprs) # TODO remove typeof
    candidates_body = filter(x -> !(typeof(x)==Expr && x.head == :if), all_exprs) # TODO remove typeof
    if isempty(candidates_body)
        return :(nothing)
    end
    cond = :(true)
    if !isempty(candidates_cond)
        cond = rand(candidates_cond)
    end
    return Expr(:if, cond, rand(candidates_body), rand(candidates_body))
end