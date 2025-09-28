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

"""
    returns the list of arguments of a function declaration
"""
function get_args(f::Expr)
    check_expr_type(f, :function)
    sig = get_signature(f)
    args_part = sig.args[(1 + Int(sig.head == :call)):end]
    Set(Expr(:quote, arg) for arg in args_part)
end

function find_random_expr(arr::Set{Any})::Expr
    candidates = filter(x -> !(x.head == :if), arr)
    return rand(candidates)
end