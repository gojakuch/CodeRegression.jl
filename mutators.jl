function generate_regression(f::Expr)

    all_exprs = Set()
    # push!(all_exprs, Expr(:quote, 0))
    # push!(all_exprs, Expr(:quote, 1))
    union!(all_exprs, get_args(f1))
    # dump(all_exprs)
    # dump(generate_return(all_exprs))

    for i in 1:5
        r = rand()
        # println(r)
        v = derive_new_expr(all_exprs, r)
        # push!(all_exprs, v);
    end

    print(all_exprs)
end

function derive_new_expr(all_exprs::Set{Any}, r)
    if(r<0.5)
        push!(all_exprs, generate_BinOp(all_exprs))
    elseif r<0.95
        push!(all_exprs, generate_return(all_exprs))
    elseif r < 1 
        push!(all_exprs, generate_if(all_exprs))
    end
end

function generate_BinOp(all_exprs::Set{Any}, ConstProb = 0.5, BinProb = 0.5)::Expr
    r = rand()

    CurrProb = ConstProb
    if r < CurrProb
        return find_random_expr(all_exprs)
    end

    CurrProb += BinProb
    if r < CurrProb
        r_norm = (r - CurrProb) / BinProb + 1
        # if r_norm < 0.01
        #     ex = :(nothing + nothing)
        # elseif r_norm < 0.02
        #     ex = :(nothing - nothing)
        # elseif r_norm < 0.03
        #     ex = :(nothing * nothing)
        # elseif r_norm < 0.04
        #     ex = :(nothing / nothing)

        if r_norm < 0.5
            ex = :(nothing > nothing)
        else
            ex = :(nothing < nothing)
        end
        ConstProb, BinProb = ConstProb + BinProb / 2, BinProb / 2
        ex.args[2] = generate_BinOp(all_exprs, ConstProb, BinProb).args[1]
        ex.args[3] = generate_BinOp(all_exprs, ConstProb, BinProb).args[1]
    end

    return ex
end

function generate_return(all_exprs::Set{Any})
    candidates = filter(x -> !(x.head == :if || x.head == :return ), all_exprs)
    return Expr(:return, rand(candidates).args[1])
end

function generate_if(all_exprs::Set{Any})
    candidates_cond = filter(x -> !(x.head == :if || x.head == :return), all_exprs)
    candidates_body = filter(x -> !(x.head == :if), all_exprs)
    return Expr(:if, rand(candidates_cond), rand(candidates_body), rand(candidates_body))
end