struct Candidate
    AST::Expr
end # probably need some signatures

# user defined operations and functions allowed

# genetic programming + stochastic optimisation like simulated annealing type shit for it to be more constrained but also efficient (different algorithms for search etc)

# minimal steps that don't change the result that much so if we add a loop it needs and then maybe track the beneficial changes for each cadidate to continue on them and change the direction sometimes (so like let the candidates have history that we can orient to)

# automatic debugging and save the last error in addition to the history so that we could fix the error deliberately

# solving 3 types: competitive (RL), function approximation, learning from a dataset

# builtin initial candidate population generators like a bunch of ifs from data points or smth

# later: translate to python and C++ and also make it possible for the objective to be defined there (tutorials on it)

# 1) solve sign function; 2) solve a board game; 3) solve something in physics

# ADVERTISE IT A LOT AND MAYBE WRITE A PAPER


ex = quote 
    for i in 1:100
        println(i)
    end
end

ex.head
typeof(ex.args[1])

ALLOWED_OPERATIONS = []
ALLOWED_COMBINATIONS = []

ex = :(a + b * c)

ex = quote
    if x > 0
        return 1
    else 
        2
    end
end

a = :(a + b)

f1 = quote
    function (x)
        if x > 0
            x = 0
        end
        x
    end
end
f1 = f1.args[2]

f2 = quote
    function (x)
        x = 1
        x
    end
end
f2 = f2.args[2]

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

function reproduce(f1::Expr, f2::Expr)
    body1 = get_body(f1)
    (typeof(body1.args[end]) != Expr || body1.args[end].head != :return) && (body1.args[end] = Expr(:return, body1.args[end])) # add return to the last value
    body2 = get_body(f2)
    (typeof(body2.args[end]) != Expr || body2.args[end].head != :return) && (body2.args[end] = Expr(:return, body2.args[end])) # add return to the last value

    function find_subblocks(block) 
        check_expr_type(block, :block)

        
    end

    function random_body_merge(body1, body2, arg)
        new_body = Expr(:nothing)
        r = rand()
        if r < 1/4
            new_body = Expr(:block, 
                body1.args[1:end-1]...,
                body2.args...
            )
        elseif r < 3/4
            # smarter combination
            # find a subblock for both bodies (if, for or whatever)
            # either merge them recursively (if possible) or add one body to the subblock of another (maybe partially?)
        else
            new_body = Expr(
                :if, 
                Expr(:call, rand([<, >]), arg, 0), 
                body1, body2)
        end
        return new_body
    end

    # get a random argument and skip the function name if it's not anonymous
    randarg = rand(get_signature(f1).args[(1+Int(get_signature(f1).head == :call)):end])
    new_body = random_body_merge(body1, body2, randarg)

    new_function_decl = copy(f1)
    new_function_decl.args[2] = new_body

    return new_function_decl
end

:(nothing * x)

ex1 = copy(ex)
ex1.args[2].args[1].args[1] = :new_name
ex1

ex1.args[2].args[2]

ex

dump(ex)