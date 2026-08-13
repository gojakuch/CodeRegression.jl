"""
Generate a callable for each candidate that does not already have one.

The `CandidateFunction.callable` field is mutated in place for candidates if callable is `nothing`.

# Returns
- `Nothing`
"""
function generate_callables!(candidates::Vector{Pair{CandidateFunction, Float64}})
    for (cf, _) in candidates
        if isnothing(cf.callable)
            def = cf.fdecl
            cf.callable = @RuntimeGeneratedFunction(def)
        end
    end

    nothing
end


"""
Verify that an expression has the expected head.

# Throws
- `ErrorException`: If `e.head` is not `t`.
"""
function check_expr_type(e::Expr, t::Symbol)
    if e.head != t
        error("expected expression of type :" * string(t) * " but :" * string(e.head) * " was given")
    end
end


"""
Return the body of a Julia function declaration expression.

# Throws
- `ErrorException`: If `f` is not a function declaration.
"""
function get_body(f::Expr) 
    check_expr_type(f, :function)
    f.args[2]
end


"""
Return the signature expression of a Julia function declaration.

# Throws
- `ErrorException`: If `f` is not a function declaration.
"""
function get_signature(f::Expr) 
    check_expr_type(f, :function)
    f.args[1]
end


"""
Parse a typed argument expression into a symbol and its evaluated type.

# Returns
- `Pair{Symbol, DataType}`: The argument name paired with its type.
"""
function get_symbol_type_pair(s::Expr)
    check_expr_type(s, :(::))
    return (s.args[1] => eval(s.args[2]))
end


"""
Return an untyped symbol paired with `Any`.
"""
function get_symbol_type_pair(s::Symbol)
    return (s => Any)
end


"""
TODO
Return the argument names from a function declaration expression.
"""
function get_args(f::Expr)
    check_expr_type(f, :function)
    s = f.args[1]
    if s.head == :(::)
        s = s.args[1]
    end
    [get_symbol_type_pair(pair)[1] for pair in s.args[(1+Int(s.head == :call)):end]]
end


"""
TODO
Return function argument names paired with their declared types.
"""
function get_arg_types(f::Expr)::NamedTuple
    check_expr_type(f, :function)
    s = f.args[1]
    if s.head == :(::)
        s = s.args[1]
    end
    NamedTuple(Dict(get_symbol_type_pair(pair) for pair in s.args[(1+Int(s.head == :call)):end]))
end


"""
Return the generalized numeric type used to group generated expressions.
"""
function general_type(type::DataType)
    d = Dict{DataType, DataType}(
        Int => Integer,
        Int8 => Integer,
        Int16 => Integer,
        Int32 => Integer,
        Int64 => Integer,
        Int128 => Integer,
        Float16 => Number,
        Float32 => Number,
        Float64 => Number,
    )
    get(d, type, type)
end


"""
Return the declared return type of a function declaration, or `Any` when none is declared.
"""
function get_return_type(f::Expr)
    check_expr_type(f, :function)
    s = f.args[1]
    if s.head == :(::)
        return eval(s.args[2])
    end
    return Any
end


"""
Sample one field from a named tuple and return its index paired with its value.
"""
function Base.rand(t::NamedTuple) # we sample from named tuples
    i = rand(eachindex(t))
    return (i, getfield(t, i))
end


"""
Sample an expression and indicate whether it came from `ce.consts`.
"""
function Base.rand(ce::ConstsAndExprs)
    idx = rand(1:(length(ce.consts) + length(ce.exprs)))
    if idx <= length(ce.consts)
        return (ce.consts[idx], true)
    end
    return (ce.exprs[idx-length(ce.consts)], false)
end


"""
Return `x` unchanged. This marker is used to identify literals in generated expressions.
"""
_cw_(x) = x


"""
    x must be smth representable as a literal!

    Returns literal wraped in _cw_ marker
"""
function make_const_wrap(x)::Expr 
    Expr(:call, :_cw_, x)
end

# TODO: move helper functions from the `reproduce` here
# TODO: split this file