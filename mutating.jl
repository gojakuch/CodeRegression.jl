include("generating.jl")

function mutate(f::Expr)
    check_expr_type(f, :function)

    r = rand()

    # TODO
    if r < 0.25
        # just add smth
        
    end
end