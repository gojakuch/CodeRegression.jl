module CodeRegression

using Random
using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(@__MODULE__)

module Operators
    module Utils
        include("Operators/Utils/expressions.jl")
        include("Operators/Utils/utils.jl")
    end

    module Methods
        module Generation
            module GP
                module Operators
                    include("Operators/Methods/Generation/GP/Operations/generate_expressions.jl")
                end
            end
        end

        module Literal
            include("Operators/Methods/Literal/literal_visitor.jl")
            include("Operators/Methods/Literal/visitor_template.jl")
            include("Operators/Methods/Literal/literal_optimization.jl")
        end

        module Mutation
            module Core
                include("Operators/Methods/Mutation/core/mutation_core.jl")
            end

            module MergingAlgo
                module Operators
                    include("Operators/Methods/Mutation/merging_algo/Operations/merging.jl")
                end
            end

            module MutationAlgo
                module Operators
                    include("Operators/Methods/Mutation/mutation_algo/Operations/mutation.jl")
                end
            end
        end
    end
end

module Pipelines
    include("Pipelines/instance1.jl")
end

import .Operators.Utils: AllowedOperationDescription, AlgorithmParameters, CandidateFunction, ConstsAndExprs, _cw_, make_const_wrap, init, generate_callables!, check_expr_type, get_body, get_signature, get_symbol_type_pair, get_args, get_arg_types, general_type, get_return_type
import .Operators.Utils: _cw_, make_const_wrap
import .Operators.Methods.Literal: ParamLiteralCandidateFunction, swap_literals_with_params, optimize_literals!, find_literals
import .Operators.Methods.Mutation.MergingAlgo.Operators: reproduce
import .Operators.Methods.Mutation.MutationAlgo.Operators: mutate, mutate_pure_expression
import .Operators.Methods.Mutation.Core: __MutationContext
import .Operators.Methods.Generation.GP.Operators: generate_exprs, generate_op!, generate_stmt, generate_assignment, generate_return, generate_block, generate_if

export mutate, reproduce, _cw_, CandidateFunction, AlgorithmParameters, AllowedOperationDescription, init, swap_literals_with_params, optimize_literals!, generate_callables!, generate_exprs, generate_op!, generate_stmt, generate_assignment, generate_return, generate_block, generate_if, ConstsAndExprs, make_const_wrap, find_literals, ParamLiteralCandidateFunction, mutate_pure_expression

end
