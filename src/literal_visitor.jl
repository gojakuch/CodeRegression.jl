# this file describes a visitor based on the general visitor template in "visitor_template.jl"

function find_literals_function!(f::Expr, literals::Vector{Expr})
    find_literals!(get_body(f), literals)
end

function find_literals_block!(body::Expr, literals::Vector{Expr})
    for line in body.args
        find_literals!(line, literals)
    end
end

function find_literals_if!(if_expr::Expr, literals::Vector{Expr})
    for line in if_expr.args
        find_literals!(line, literals)
    end
end

function find_literals_assign!(assign_expr::Expr, literals::Vector{Expr})
    find_literals!(assign_expr.args[2], literals)
end

function find_literals_return!(r::Expr, literals::Vector{Expr})
    find_literals!(r.args[1], literals)
end

function find_literals_call!(c::Expr, literals::Vector{Expr})
    if c.args[1] === _cw_
        push!(literals, c)
        return
    elseif length(c.args) < 2
        return
    end
    for line in c.args[2:end]
        find_literals!(line, literals)
    end
end

function find_literals!(e::Expr, literals::Vector{Expr})
    dispatch = Dict(
        :function => find_literals_function!,
        :block => find_literals_block!,
        :if => find_literals_if!,
        :(=) => find_literals_assign!,
        :return => find_literals_return!,
        :call => find_literals_call!
    )
    if haskey(dispatch, e.head)
        dispatch[e.head](e, literals)
    end
end
function find_literals!(::LineNumberNode, ::Vector{Expr})
end
function find_literals!(::Symbol, ::Vector{Expr})
end
function find_literals!(::Number, ::Vector{Expr})
    # TODO: maybe wrap the numbers in cw automatically later?
end

"""
    a visitor wrapper that returns all the :(cw(LITERAL)) subexpressions in the given expression
"""
function find_literals(f::Expr)::Vector{Expr}
    literals = Expr[]
    find_literals!(f, literals)
    return literals
end
