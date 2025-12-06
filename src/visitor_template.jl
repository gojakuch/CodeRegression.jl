# this file describes a visitor based on the general visitor template in "visitor_template.jl"

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
    
"""
function visit(f::Expr)::Data
    check_expr_type(f, :function)
    data = Data()
    visit!(get_body(f), data)
    return data
end
