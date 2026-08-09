using Random

import CodeRegression.Operators.Utils: CandidateFunction, check_expr_type, get_args, make_const_wrap, is_stmt, get_body

function reproduce(cf1::CandidateFunction, cf2::CandidateFunction)::CandidateFunction
    body1 = deepcopy(get_body(cf1.fdecl))
    body2 = deepcopy(get_body(cf2.fdecl))

    function random_body_merge(body1, body2, arg)::Expr
        try # THIS IS A CRUTCHFIX, WE NEED TO REDESIGN MERGING COMPLETELY (see issue #15)
            check_expr_type(body1, :block)
            check_expr_type(body2, :block)
        catch
            return body1
        end
        new_body = :(return nothing)
        r = rand()

        function find_subblocks(block::Expr, types::Vector{Symbol} = [:block, :if])::Vector{Pair{Expr, Int}} # only searches for blocks, but maybe we need blocks of matching types(?)
            check_expr_type(block, :block)

            subblocks::Vector{Pair{Expr, Int}} = Pair{Expr, Int}[]

            function iter(p::Expr, i::Int)
                if p.head in types # [:block, :while, :for, :if, :do]
                    push!(subblocks, (p => i))
                end
            end
            iter(_::Symbol, i::Int) = nothing
            iter(_::LineNumberNode, i::Int) = nothing
            for i in eachindex(block.args)
                iter(block.args[i], i)
            end

            return subblocks
        end

        function append_expr_to_block(block::Expr, ex)::Expr
            h = block.head 
            if h == :block
                 return Expr(:block, block.args..., ex)
            elseif h == :if 
                f = block # deepcopy(block) # we now call deepcopy all the time
                i = 2 + (length(f.args) > 2 && rand() > 0.5) # decide if we append to the if or to the else
                f.args[i] = (typeof(f.args[i]) == Expr) ? Expr(:block, f.args[i].args..., ex) : Expr(:block, f.args[i], ex)
                return f
            end
            throw("append_expr_to_block failed inside reproduce")
            return block
        end

        function merge_blocks(block1::Expr, block2::Expr, arg)::Expr
            h = block1.head 
            if h == :block
                 return random_body_merge(block1, block2, arg)
            elseif h == :if 
                f = block1 # deepcopy(block1) # we now call deepcopy all the time
                # TODO: add condition merging and smarter if merges generally. check if the conditions are similar, etc.
                i = 2 + (length(f.args) > 2 && length(block2.args) > 2 && rand() > 0.5) # decide if we merge the if or to the else
                f.args[i] = random_body_merge(block1.args[i], block2.args[i], arg)
                return f
            end
            throw("merge_blocks failed inside reproduce")
            return block
        end

        if r < 1/4
            new_body = Expr(:block, 
                body1.args[1:end-1]..., # FIXME: this can sometimes trim a line from a block in recursion. should only ignore the return statements
                body2.args...
            )
        elseif r < 2/4
            # smarter combination
            # TODO: make it smarter and maybe more efficient (other reproduce combination algorithms)
            subblocks1 = find_subblocks(body1)
            merged_blocks = Expr(:block)
            merged_idx = 0
            if !isempty(subblocks1)
                chosen_statement, merged_idx = rand(subblocks1)
                subblocks2 = find_subblocks(body2, [chosen_statement.head])
                if !isempty(subblocks2)
                    merged_blocks = merge_blocks(chosen_statement, rand(subblocks2)[1], arg)
                else
                    merged_blocks = append_expr_to_block(chosen_statement, body2)
                end
                new_body = copy(body1)
            else
                subblocks2 = find_subblocks(body2)
                if !isempty(subblocks2)
                    chosen_statement, merged_idx = rand(subblocks2)
                    merged_blocks = append_expr_to_block(chosen_statement, body1)
                end
                new_body = copy(body2)
            end
            if merged_idx != 0
                new_body.args[merged_idx] = merged_blocks
            else 
                new_body = Expr(:block, 
                    body1.args...,
                    body2.args...
                )
            end
        else
            new_body = Expr(
                :if, 
                Expr(:call, rand([:<, :>]), arg, make_const_wrap(0)), 
                body1, body2)
        end
        return new_body
    end

    # shuffle the bodies
    bodies = [body1, body2]
    Random.shuffle!(bodies)

    # get a random argument and skip the function name if it's not anonymous
    randarg = rand(get_args(cf1.fdecl))
    new_body = random_body_merge(bodies..., randarg)

    new_function_decl = copy(cf1.fdecl)
    new_function_decl.args[2] = new_body

    return CandidateFunction(new_function_decl, cf1.algparams_ref)
end

function myers(A, B)
    # :match: An element in A aligns/matches an element in B.
    # :delete: An element exists in A but has no matching alignment in B (removed from A).
    # :insert: An element exists in B but has no matching alignment in A (added from B).

    is_equivalent(a::Expr, b::Expr) = a.head == b.head
    is_equivalent(a, b) = a == b

    N, M = length(A), length(B)
    V = Dict(1 => 0)
    trace = Vector{Dict{Int, Int}}()
    
    for D in 0:(N + M)
        for k in -D:2:D
            # Select the optimal path based on furthest reaching x
            if k == -D || (k != D && get(V, k - 1, -1) < get(V, k + 1, -1))
                x = get(V, k + 1, -1)
            else
                x = get(V, k - 1, -1) + 1
            end
            y = x - k
            
            # Match
            while x < N && y < M && is_equivalent(A[x + 1], B[y + 1])
                x += 1; y += 1
            end
            V[k] = x
            
            # Stop the moment we consume both vectors entirely
            if x >= N && y >= M
                push!(trace, copy(V))
                return backtrack(trace, A, B, D)
            end
        end
        push!(trace, copy(V))
    end

    return Symbol[]
end

function backtrack(trace, A, B, total_D)
    x, y = length(A), length(B)
    path = Symbol[]
    
    # Work backwards exactly from total_D down to 1
    for d in total_D:-1:1
        V = trace[d+1]
        prev_V = trace[d]
        k = x - y
        
        # Determine if we arrived here via an insert (k+1) or delete (k-1)
        if k == -d || (k != d && get(prev_V, k - 1, -1) < get(prev_V, k + 1, -1))
            k_prev = k + 1
            op = :insert
        else
            k_prev = k - 1
            op = :delete
        end
        
        x_prev = get(prev_V, k_prev, 0)
        y_prev = x_prev - k_prev
        
        # Pinpoint exactly where the diagonal snake started for this step
        if op == :insert
            x_start, y_start = x_prev, y_prev + 1
        else
            x_start, y_start = x_prev + 1, y_prev
        end
        
        # 1. Rewind the matching elements of the snake
        while x > x_start && y > y_start
            pushfirst!(path, :match)
            x -= 1; y -= 1
        end
        
        # 2. Rewind the edit operation itself
        pushfirst!(path, op)
        x, y = x_prev, y_prev
    end
    
    # 3. Handle any leftover matching elements before the very first edit
    while x > 0 && y > 0
        pushfirst!(path, :match)
        x -= 1; y -= 1
    end
    
    return path
end

# Leaf node fallback (symbols, literals, numbers)
crossover(a, b) = rand() > 0.5 ? deepcopy(a) : deepcopy(b)

function crossover(cf1::CandidateFunction, cf2::CandidateFunction)::CandidateFunction
    body1 = get_body(cf1.fdecl)
    body2 = get_body(cf2.fdecl)

    new_function_decl = copy(cf1.fdecl)
    new_function_decl.args[2] = crossover(body1, body2)
    return CandidateFunction(new_function_decl, cf1.algparams_ref)
end

function crossover(e1::Expr, e2::Expr)::Expr
    if e1.head != e2.head
        return rand() > 0.5 ? deepcopy(e1) : deepcopy(e2) 
    end

    if e1.head == (:call) && e1.args[1] == e2.args[1] && length(e1.args) == length(e2.args) # a call to the same function with the same number of arguments
        res = deepcopy(e1)
        for i in 2:length(e1.args)
            res.args[i] = crossover(e1.args[i], e2.args[i])
        end
        return res
    end

    if e1.head == (:block)
        res = Expr(:block)
        matching = myers(e1.args, e2.args)
        idx1 = 1
        idx2 = 1
        for m in matching
            if m == :match
                push!(res.args, crossover(e1.args[idx1], e2.args[idx2]))
                idx1 += 1
                idx2 += 1
            elseif m == :insert
                # TODO: add an option to just skip the unmatched here
                if rand() > 0.5
                    push!(res.args, deepcopy(e2.args[idx2]))
                end
                idx2 += 1
            else # m == :delete
                # TODO: add an option to just skip the unmatched here
                if rand() > 0.5
                    push!(res.args, deepcopy(e1.args[idx1]))
                end
                idx1 += 1
            end
        end

        return res
    end

    if e1.head == (:if) # can have different number of blocks (if there is an `else`)
        if length(e1.args) > length(e2.args)
            (e1, e2) = (e2, e1)
        end
    end

    # other statements must already have the same number of arguments and be of the same type
    if is_stmt(e1)
        res = deepcopy(e1)
        for i in eachindex(e1.args)
            res.args[i] = crossover(e1.args[i], e2.args[i])
        end
        return res
    end

    return rand() > 0.5 ? deepcopy(a) : deepcopy(b)
end

