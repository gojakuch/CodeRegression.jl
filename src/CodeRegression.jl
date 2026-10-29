module CodeRegression
    using Random
    using RuntimeGeneratedFunctions

    RuntimeGeneratedFunctions.init(@__MODULE__)

    module Utils
        include("Utils/expressions.jl")
        export SelectionAlgorithmBackend, ConstsAndExprs, AllowedOperationDescription, AlgorithmParameters, CandidateFunction, init

        include("Utils/utils.jl")
        export generate_callable!, check_expr_type, is_stmt, get_body, get_signature, get_symbol_type_pair, get_args, get_arg_types, general_type, get_return_type, _cw_, make_const_wrap
    end
    using .Utils
    # TODO: move these from Utils, they are important and exported, they don't belong here
    export AllowedOperationDescription, AlgorithmParameters, CandidateFunction, init, _cw_, make_const_wrap, generate_callable!

    module Stages
        module Literals
            module Core
                using CodeRegression.Utils
                include("Stages/Literals/Core/literal_visitor.jl")

                export find_literals, find_literals!
            end
            using .Core

            # actual algorithms
            module GradientBased
                using ..Core
                using CodeRegression.Utils
                include("Stages/Literals/GradientBased/literal_optimization.jl")

                export ParamLiteralCandidateFunction, swap_literals_with_params, optimize_literals! 
            end
            using .GradientBased

            # TODO: make it export a general `optimize_literals!` only, so that each algorithm just reimplements a method of it
            export ParamLiteralCandidateFunction, swap_literals_with_params, optimize_literals! 
        end
        using .Literals
        # TODO: make it export a general `optimize_literals!` only, so that each algorithm just reimplements a method of it
        export ParamLiteralCandidateFunction, swap_literals_with_params, optimize_literals! 

        module Crossover
            module Core
                using CodeRegression.Utils
            end
            using .Core

            # actual algorithms
            module SimpleMyers
                using ..Core
                using CodeRegression.Utils
                include("Stages/Crossover/SimpleMyers/crossover.jl") # TODO: should define SimpleMyers as a struct (like Selection)

                export crossover
            end
            using .SimpleMyers

            export crossover
        end
        using .Crossover
        export crossover

        module Mutation
            using CodeRegression.Utils

            module Core
                using CodeRegression.Utils
                module Generation
                    using CodeRegression.Utils
                    include("Stages/Mutation/Core/Generation/generate_expressions.jl")

                    export generate_exprs, generate_stmt
                end
                using .Generation

                include("Stages/Mutation/Core/mutation_core.jl")

                export __MutationContext, generate_stmt # only this
            end
            using .Core

            # actual algorithms
            include("Stages/Mutation/Naive/naive.jl") # TODO: should define Naive as a struct (like Selection)
            export mutate, mutate!
        end
        using .Mutation
        export mutate, mutate!

        module Selection
            using CodeRegression.Utils

            module Core
                using CodeRegression.Utils
                include("Stages/Selection/Core/selection_core.jl")

                export select, __select_compare
            end
            using .Core
            import .Core: select

            include("Stages/Selection/Truncation/truncation.jl")
            export Truncation, select

            include("Stages/Selection/Tournament/tournament.jl")
            export Tournament, select
        end
        using .Selection
        export select, Truncation, Tournament
    end
    using .Stages
    export swap_literals_with_params, optimize_literals!, crossover, mutate, mutate!, select, Truncation, Tournament

    module Pipelines
        include("Pipelines/instance1.jl") # TODO
    end
end
