function generate_regression(f::Expr)
    all_exprs = Expr[]
    
    for i in 1:100
        r = rand()
        push!(all_exprs, derive_new_expr(all_exprs, r));
    end
end

function derive_new_expr(all_exprs::Array{Expr}, r)::Expr

    if(r < 0.25)
    end


end

function generate_BinOp(all_exprs::Vector{Expr}, ConstProb = 0.5, BinProb = 0.5)::Expr
    r = rand()
    CurrProb = ConstProb
    if r < CurrProb
        return find_random_expr(all_exprs)
    end

    CurrProb += BinProb
    if r < CurrProb
        r_norm = (r - CurrProb) / BinProb + 1
        if r_norm < 0.25
            ex = :(nothing + nothing)
        elseif r_norm < 0.5
            ex = :(nothing - nothing)
        elseif r_norm < 0.75
            ex = :(nothing * nothing)
        else
            ex = :(nothing / nothing)
        end
        ConstProb, BinProb = ConstProb + BinProb / 2, BinProb / 2
        ex.args[2] = generate_BinOp(all_exprs, ConstProb, BinProb)
        ex.args[3] = generate_BinOp(all_exprs, ConstProb, BinProb)
    end

    return ex
end