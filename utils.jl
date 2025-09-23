function check_expr_type(e::Expr, t::Symbol)
    if e.head != t
        error("expected expression of type :" * string(t) * " but :" * string(e.head) * " was given")
    end
end

function get_body(f::Expr) 
    check_expr_type(f, :function)
    f.args[2]
end

function get_signature(f::Expr) 
    check_expr_type(f, :function)
    f.args[1]
end