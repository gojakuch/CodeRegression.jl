struct Candidate
    AST::Expr
end # probably needs to store the signature, variable types and the history

ALLOWED_OPERATIONS = []
ALLOWED_COMBINATIONS = []

include("utils.jl")

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

function reproduce(f1::Expr, f2::Expr)
    body1 = get_body(f1)
    (typeof(body1.args[end]) != Expr || body1.args[end].head != :return) && (body1.args[end] = Expr(:return, body1.args[end])) # add return to the last value
    body2 = get_body(f2)
    (typeof(body2.args[end]) != Expr || body2.args[end].head != :return) && (body2.args[end] = Expr(:return, body2.args[end])) # add return to the last value

    function find_subblocks(block::Expr)::Array{Expr} # only searches for blocks, but maybe we need blocks of matching types(?)
        check_expr_type(block, :block)

        subblocks::Array{Expr} = Expr[]

        function iter(p::Expr)
            if p.head == :block
                push!(subblocks, p)
            end
        end
        iter(_::LineNumberNode) = nothing
        for p in block
            iter(p)
        end

        return subblocks
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
            subblocks1 = find_subblocks(body1)
            subblocks2 = find_subblocks(body2)

            if !empty(subblocks1)
                if !empty(subblocks2)
                    new_body = random_body_merge(rand(subblocks1), rand(subblocks2), arg)
                else
                    new_body = copy(rand(subblocks1)) # nope, need the index of it
                end
            elseif !empty(subblocks2)
                
            end
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

dump(ex)