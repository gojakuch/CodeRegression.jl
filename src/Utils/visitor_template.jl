# this file describes a general visitor template

Data = Vector{Any} # replace this with your propagated data type

function visit_function!(f::Expr, ::Data)
    
end


function visit_block!(body::Expr, ::Data)
    
end


function visit_if!(if_expr::Expr, ::Data)
    
end


function visit_assign!(assign_expr::Expr, ::Data)
    
end


function visit_return!(r::Expr, ::Data)
    
end


function visit_call!(c::Expr, ::Data)
    
end


"""
Dispatch an expression to the visitor hook matching its head.
"""
function visit!(e::Expr, data::Data)
    dispatch = Dict(
        :function => visit_function!,
        :block => visit_block!,
        :if => visit_if!,
        :(=) => visit_assign!,
        :return => visit_return!,
        :call => visit_call!
    )
    if haskey(dispatch, e.head)
        dispatch[e.head](e, data)
    end
end


"""
Visit the body of a function declaration and return the visitor's accumulated data.
"""
function visit(f::Expr)::Data
    check_expr_type(f, :function)
    data = Data()
    visit!(get_body(f), data)
    return data
end
