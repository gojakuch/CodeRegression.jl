# this file describes a visitor based on the general visitor template in "visitor_template.jl"

"""
Collect wrapped literal expressions from a function declaration and append them to `literals`.

# Arguments
- `f::Expr`: Function declaration expression to inspect.
- `literals::Vector{Expr}`: Mutable output vector that receives any discovered literal AST nodes.

# Returns
- `Nothing`: The `literals` argument is updated in place.

"""
function find_literals_function!(f::Expr, literals::Vector{Expr})
    find_literals!(get_body(f), literals)
end


"""
Collect wrapped literal expressions from each statement in a block and append them to `literals`.

# Arguments
- `body::Expr`: Block expression to traverse.
- `literals::Vector{Expr}`: Mutable output vector that receives any discovered literal AST nodes.

# Returns
- `Nothing`: The `literals` argument is updated in place.
"""
function find_literals_block!(body::Expr, literals::Vector{Expr})
    for line in body.args
        find_literals!(line, literals)
    end
end


"""
Collect wrapped literal expressions from an `if` expression and append them to `literals`.

# Arguments
- `if_expr::Expr`: `if` expression to inspect.
- `literals::Vector{Expr}`: Mutable output vector that receives any discovered literal AST nodes.

# Returns
- `Nothing`: The `literals` argument is updated in place.
"""
function find_literals_if!(if_expr::Expr, literals::Vector{Expr})
    for line in if_expr.args
        find_literals!(line, literals)
    end
end


"""
Collect wrapped literal expressions from the right-hand side of an assignment and append them to `literals`.

# Arguments
- `assign_expr::Expr`: Assignment expression to inspect.
- `literals::Vector{Expr}`: Mutable output vector that receives any discovered literal AST nodes.

# Returns
- `Nothing`: The `literals` argument is updated in place.
"""
function find_literals_assign!(assign_expr::Expr, literals::Vector{Expr})
    find_literals!(assign_expr.args[2], literals)
end


"""
Traverse a return expression and collect wrapped literals.

# Arguments
- `r::Expr`: A return expression node.
- `literals::Vector{Expr}`: The vector into which discovered literal AST nodes are pushed in-place.

# Returns
- `Nothing`: The function operates by mutating the `literals` vector in-place.
"""
function find_literals_return!(r::Expr, literals::Vector{Expr})
    find_literals!(r.args[1], literals)
end


"""
Collect a wrapped literal call or recursively traverse a general call.

# Arguments
- `c::Expr`: A call expression node.
- `literals::Vector{Expr}`: The vector into which discovered literal AST nodes are pushed in-place.

# Returns
- `Nothing`: The function operates by mutating the `literals` vector in-place.
"""
function find_literals_call!(c::Expr, literals::Vector{Expr})
    if c.args[1] == :_cw_
        push!(literals, c)
        return
    elseif length(c.args) < 2
        return
    end
    for line in c.args[2:end]
        find_literals!(line, literals)
    end
end


"""
Dispatch literal collection for an expression and mutate `literals` in place.

# Arguments
- `e::Expr`: The current expression node being traversed.
- `literals::Vector{Expr}`: The vector into which matching literal AST nodes are pushed in-place. **(Mutated)**

# Returns
- `Nothing`: The function operates by mutating the `literals` argument in-place.
"""
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
Return all `_cw_(literal)` subexpressions found in a function declaration.

# Arguments
- `f::Expr`: The root expression AST node to search.

# Returns
- `Vector{Expr}`: A list of expression AST nodes (`Expr`) corresponding to the identified literals in `f`.
"""

function find_literals(f::Expr)::Vector{Expr}
    literals = Expr[]
    find_literals!(f, literals)
    return literals
end
