include("generating.jl")

function mutate(f::Expr)::Expr
    # FIXME: this is a prototype!!! this should NOT go any further than the proof of concept
    # TODO: I think we need to replace this with a modifying visitor that finds what to change recursively and that has modular system (meaning the user can turn on and off some possible changes or supply custom ones)

    check_expr_type(f, :function)

    new_f = deepcopy(f)
    exprs = generate_regression(f, 1)

    function insertexpr!(arr)
        r2 = rand()
        ex = :(nothing)
        if r2 < 0.2
            ex = generate_assignment(exprs, new_f)
        else
            ex = generate_if(exprs)
        end

        if length(arr) > 1
            insert!(arr, rand(1:(length(arr)-1)), ex)
        else
            insert!(arr, 1, ex)
        end
    end

    r = rand()
    if r < 0.4
        # just add smth before the return (random line)
        insertexpr!(get_body(new_f).args)
    elseif r < 0.75
        # modify something (again, we'll need to do this recursively, it's dumb not to)
        # do we need to modify the return in the end?

        inds = filter(i -> (typeof(get_body(new_f).args[i]) == Expr), 1:(length(get_body(new_f).args)-1))
        if isempty(inds)
            insertexpr!(get_body(new_f).args)
            return new_f
        end
        ind = rand(inds)
        ex_i = get_body(new_f).args[ind]

        if ex_i.head == :if 
            # choose if we modify the body or cond
            # recursion here later
            r2 = rand()
            if r2 < 1/3
                # modify cond
                ex_i.args[1] = rand(filter(x -> !(typeof(x)==Expr && (x.head == :if || x.head == :return)), exprs))
            else
                # insert to the block
                i = 2 + (length(ex_i.args) > 2 && rand() > 0.5) # decide if we append to the if or to the else
                if typeof(ex_i.args[i]) != Expr
                    ex_i.args[i] = Expr(:block, ex_i.args[i])
                end
                insertexpr!(ex_i.args[i].args)
                # r2 = rand()
                # ex = :(nothing)
                # if r2 < 0.5
                #     ex = generate_assignment(exprs, new_f)
                # else
                #     ex = generate_if(exprs)
                # end

                # insert!(ex_i.args[i].args, rand(1:(length(ex_i.args[i].args)-1)), ex)
            end
        elseif ex_i.head == :(=)
            # choose the side
            r2 = 1
            if length(get_args(f)) > 1 # check if there are other variables to assign to
                r2 = rand()
            end
            if r2 < 0.3
                # lhs
                ex_i.args[1] = rand(get_args(f))
            else
                # TODO: separate recursion for the rhs. potential SR.jl integration here (optional)
                var = ex_i.args[1]
                ex_i = generate_assignment(exprs, new_f)
                ex_i.args[1] = var
                get_body(new_f).args[ind] = ex_i
            end
        end
    else
        # remove something
        inds = filter(i -> (typeof(get_body(new_f).args[i]) != LineNumberNode), 1:(length(get_body(new_f).args)-1))
        if isempty(inds)
            insertexpr!(get_body(new_f).args)
            return new_f
        end
        ind = rand(inds)
        deleteat!(get_body(new_f).args, ind)
    end

    return new_f
end