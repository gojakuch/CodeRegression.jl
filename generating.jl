include("utils.jl")

function generate_regression(f::Expr)
    all_exprs = get_args(f)

    for i in 1:10
        r = rand()
        derive_new_expr!(all_exprs, r)
    end

    all_exprs
end

function derive_new_expr!(all_exprs::Vector, r)
    if(r < 0.5)
        push!(all_exprs, generate_bin_op(all_exprs))
    elseif r < 0.95
        push!(all_exprs, generate_return(all_exprs))
    elseif r < 1 
        push!(all_exprs, generate_if(all_exprs))
    end
end

function generate_bin_op(all_exprs::Vector, ConstProb = 0.5, BinProb = 0.5)
    r = rand()

    CurrProb = ConstProb
    if r < CurrProb
        candidates = filter(x -> !(typeof(x)==Expr && x.head == :if), all_exprs) # TODO remove typeofs in all those filters
        if isempty(candidates)
            return :(nothing)
        end
        return rand(candidates)
    end

    CurrProb += BinProb
    if r < CurrProb
        r_norm = (r - CurrProb) / BinProb + 1
        if r_norm < 0.5
            ex = :(nothing > nothing)
        else
            ex = :(nothing < nothing)
        end
        ConstProb, BinProb = ConstProb + BinProb / 2, BinProb / 2
        left = generate_bin_op(all_exprs, ConstProb, BinProb)
        ex.args[2] = (typeof(left) == Expr) ? left.args[1] : left # TODO remove typeof
        right = generate_bin_op(all_exprs, ConstProb, BinProb)
        ex.args[3] = (typeof(right) == Expr) ? right.args[1] : right # TODO remove typeof
    end

    return ex
end

function generate_return(all_exprs::Vector)
    candidates = filter(x -> !(typeof(x)==Expr && (x.head == :if || x.head == :return)), all_exprs) # TODO remove typeof
    if isempty(candidates)
        return :(nothing)
    end
    c = rand(candidates)
    return Expr(:return, ((typeof(c) == Expr) ? c.args[1] : c)) # TODO remove typeof
end

function generate_if(all_exprs::Vector)
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