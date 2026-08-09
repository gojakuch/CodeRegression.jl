module CodeRegression

using Random
using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(@__MODULE__)

module Operators
    module Utils
        include("Operators/Utils/expressions.jl")
        include("Operators/Utils/utils.jl")
        include("Operators/Utils/visitor_template.jl")
    end

    module Methods
        module Generation
            module Core

            end

            module Operations

            end

            module GP
                module Operators
                    include("Operators/Methods/Generation/GP/operations/generate_expressions.jl")
                end
            end
        end

        module Literal
            module Core
                
            end

            module Operations
                include("Operators/Methods/Literal/Operations/literal_optimization.jl")
                include("Operators/Methods/Literal/Operations/literal_visitor.jl")
            end
        end

        module Merge
            module Core
                
            end

            module Operations
                include("Operators/Methods/Merge/Operations/merging.jl")
            end
        end

        module Mutation
            module Core
                include("Operators/Methods/Mutation/core/mutation_core.jl")
            end

            module MutationAlgo
                module Operators
                    include("Operators/Methods/Mutation/mutation_algo/operations/mutation.jl")
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
import .Operators.Methods.Generation.GP.Operators: generate_exprs, generate_op!, generate_stmt, generate_assignment, generate_return, generate_block, generate_if

import .Operators.Methods.Literal.Operations: ParamLiteralCandidateFunction, swap_literals_with_params, optimize_literals!, find_literals
import .Operators.Methods.Merge.Operations: crossover
import .Operators.Methods.Mutation.MutationAlgo.Operators: mutate, mutate_pure_expression
import .Operators.Methods.Mutation.Core: __MutationContext

export mutate, crossover, _cw_, CandidateFunction, AlgorithmParameters, AllowedOperationDescription, init, swap_literals_with_params, optimize_literals!, generate_callables!, generate_exprs, generate_op!, generate_stmt, generate_assignment, generate_return, generate_block, generate_if, ConstsAndExprs, make_const_wrap, find_literals, ParamLiteralCandidateFunction, mutate_pure_expression

end
