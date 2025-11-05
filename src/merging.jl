using Random

function reproduce(f1::Expr, f2::Expr)::Expr
    body1 = get_body(f1)
    body2 = get_body(f2)

    function random_body_merge(body1, body2, arg)::Expr
        check_expr_type(body1, :block)
        check_expr_type(body2, :block)
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
                f = deepcopy(block)
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
                f = deepcopy(block1)
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
                Expr(:call, rand([:<, :>]), arg, 0), 
                body1, body2)
        end
        return new_body
    end

    # shuffle the bodies
    bodies = [body1, body2]
    Random.shuffle!(bodies)

    # get a random argument and skip the function name if it's not anonymous
    randarg = rand(get_args(f1))
    new_body = random_body_merge(bodies..., randarg)

    new_function_decl = copy(f1)
    new_function_decl.args[2] = new_body

    return new_function_decl
end
