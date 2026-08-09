"""
    Generates callable for every candidate function without a callable in the candidates pair array.
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

function check_expr_type(e::Expr, t::Symbol)
    if e.head != t
        error("expected expression of type :" * string(t) * " but :" * string(e.head) * " was given")
    end
end

"""
    returns true if e is of stmt type
"""
function is_stmt(e::Expr)::Bool
    t = e.head
    t == (:if) || t == (:block) || t == (:for) || t == (:while) || t == (:return) || t == :(=) # Only the necessary
end

"""
    returns the body of a function declaration
"""
function get_body(f::Expr) 
    check_expr_type(f, :function)
    f.args[2]
end

"""
    returns the signature of a function declaration
"""
function get_signature(f::Expr) 
    check_expr_type(f, :function)
    f.args[1]
end

"""
    returns a pair with the symbol and it's type parsed from :(s::Type)
"""
function get_symbol_type_pair(s::Expr)
    check_expr_type(s, :(::))
    return (s.args[1] => eval(s.args[2]))
end
function get_symbol_type_pair(s::Symbol)
    return (s => Any)
end

"""
    returns the list of arguments of a function declaration
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
    returns a named tuple of all the function args with their types
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
    when generating and mutating code we need to keep track of the values but we want to generalise some types for expressions. 
    given a type, returns its generalisation
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
    returns the return type of a function declaration
"""
function get_return_type(f::Expr)
    check_expr_type(f, :function)
    s = f.args[1]
    if s.head == :(::)
        return eval(s.args[2])
    end
    return Any
end

function Base.rand(t::NamedTuple) # we sample from named tuples
    i = rand(eachindex(t))
    return (i, getfield(t, i))
end

function Base.rand(ce::ConstsAndExprs)
    idx = rand(1:(length(ce.consts) + length(ce.exprs)))
    if idx <= length(ce.consts)
        return (ce.consts[idx], true)
    end
    return (ce.exprs[idx-length(ce.consts)], false)
end

"""
    _cw_(x) = x 

    used to wrap literals.
"""
_cw_(x) = x

"""
    x must be smth representable as a literal!

    returns Expr(:call, :_cw_, x)
"""
function make_const_wrap(x)::Expr 
    Expr(:call, :_cw_, x)
end

# TODO: split this file