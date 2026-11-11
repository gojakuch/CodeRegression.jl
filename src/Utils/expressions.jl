using RuntimeGeneratedFunctions

import RuntimeGeneratedFunctions: RuntimeGeneratedFunction

RuntimeGeneratedFunctions.init(@__MODULE__)

"""
    all mutation algorithm implementations must inherit from this type.
"""
abstract type MutationAlgorithmBackend end


"""
    all crossover algorithm implementations must inherit from this type.
"""
abstract type CrossoverAlgorithmBackend end


"""
    all selection algorithm implementations must inherit from this type.
"""
abstract type SelectionAlgorithmBackend end


"""
Store generated constant expressions separately from expressions that depend on values.

# Fields
- `consts::Vector{Expr}`: Expressions whose arguments are all constants
- `exprs::Vector{Any}`: Expressions that contain variables or non-constant subexpressions
"""
struct ConstsAndExprs
    consts::Vector{Expr}
    exprs::Vector{Any}
end

Base.isempty(ce::ConstsAndExprs) = isempty(ce.consts) && isempty(ce.exprs)


"""
Describe one parameter accepted by a generated operation.

# Arguments
- `type::Type`: Required parameter type
- `can_be_const::Bool`: Whether a generated argument may be a constant expression
"""
struct _AllowedOperationDescriptionParameter
    type::Type # FIXME: should generalise the type automatically in its constructor
    can_be_const::Bool
end


"""
Describe an operation that may be used during expression generation and mutation.

# Arguments
- `callee::Symbol`: Name of the operation to call.
- `params`: Parameter descriptions, supplied as named tuples containing `type` and `can_be_const`.

# Returns
- `AllowedOperationDescription`: The normalized operation description.
"""
struct AllowedOperationDescription
    callee::Symbol
    params::Vector{_AllowedOperationDescriptionParameter}
end


"""
Construct an operation description from named tuples with `type` and `can_be_const` fields.
"""
function AllowedOperationDescription(callee::Symbol, params::Vector{NamedTuple})
    paramlist = _AllowedOperationDescriptionParameter[]
    for tup in params
        push!(paramlist, _AllowedOperationDescriptionParameter(tup.type, tup.can_be_const))
    end
    AllowedOperationDescription(callee, paramlist)
end


_default_statement_weights() = Dict(
    :assignment => 1.0,
    :return => 1.0,
    :if => 2.0,
)


"""
Describe the search algorithm and the function signature used by generation, mutation, merging, and literal optimization.

# Type arguments
- CrossoverType<:CrossoverAlgorithmBackend
- SelectionType<:SelectionAlgorithmBackend

# Fields
- `f_arg_types::NamedTuple`: Argument names and their declared types.
- `f_return_type::Type`: Declared return type.
- `all_ops::Dict{Type, Vector{AllowedOperationDescription}}`: Operations grouped by result type.
- `expr_gen_depth::Int`: Number of expression-generation rounds.
- `apply_mutate_to_pure_exprs::Bool`: Whether pure expressions may be recursively changed.
- `crossover_backend::CrossoverType`: The backend to use for the crossover stage.
- `selection_backend::SelectionType`: The backend to use for the selection stage.
- `apply_literal_optim::Bool`: Whether literal optimization is enabled by the pipeline.
- `literal_optim_iters::Int`: Number of literal-optimization iterations.
- `statement_weights::Dict{Symbol, Float64}`: Static relative weights for generated statement kinds.
"""
struct AlgorithmParameters{
        MutationType<:MutationAlgorithmBackend, 
        CrossoverType<:CrossoverAlgorithmBackend, 
        SelectionType<:SelectionAlgorithmBackend
    }

    # problem setup details (function signature)
    f_arg_types::NamedTuple
    f_return_type::Type
    statement_weights::Dict{Symbol, Float64}
    # algorithm details
    all_ops::Dict{Type, Vector{AllowedOperationDescription}}
    # stages:
    ## mutation
    mutation_backend::MutationType
    ## crossover
    crossover_backend::CrossoverType
    ## selection
    selection_backend::SelectionType
    ## literal optimisation
    apply_literal_optim::Bool
    literal_optim_iters::Int

    # constructors
    function AlgorithmParameters(
        _f_arg_types::NamedTuple,
        _f_return_type::Type,
        _all_ops::Dict{Type, Vector{AllowedOperationDescription}},
        _mutation_backend::MutationType,
        _crossover_backend::CrossoverType,
        _selection_backend::SelectionType,
        _apply_literal_optim::Bool,
        _literal_optim_iters::Int;
        statement_weights::AbstractDict{Symbol, <:Real}=_default_statement_weights(),
    ) where {MutationType<:MutationAlgorithmBackend, CrossoverType<:CrossoverAlgorithmBackend, SelectionType<:SelectionAlgorithmBackend}
        valid_statement_kinds = (:assignment, :return, :if)
        normalized_statement_weights = _default_statement_weights()
        for (kind, weight) in statement_weights
            kind in valid_statement_kinds || throw(ArgumentError("unknown statement kind in statement_weights: $kind"))
            normalized_weight = Float64(weight)
            isfinite(normalized_weight) && normalized_weight >= 0 || throw(ArgumentError("statement weights must be finite and non-negative"))
            normalized_statement_weights[kind] = normalized_weight
        end

        new{MutationType, CrossoverType, SelectionType}(
            _f_arg_types,
            _f_return_type,
            normalized_statement_weights,
            _all_ops,
            _mutation_backend,
            _crossover_backend,
            _selection_backend,
            _apply_literal_optim,
            _literal_optim_iters,
        )
    end
end


"""
Wrap a function declaration expression and the algorithm configuration used to transform it.

- `CriterionType`: a type that is used to save the criterion result for the function. typically, `Float64` can be used. this type must define a `Base.zero(::CriterionType)` just to be able to create dummy objects of this type.
- `AlgorithmParametersType<:AlgorithmParameters`: should be a fully formed concrete AlgorithmParameters type for efficiency

# Fields
- `fdecl::Expr`: Julia function declaration represented as an expression.
- `algparams_ref::AlgorithmParameters`: Configuration shared by candidates.
- `callable::Union{RuntimeGeneratedFunction, Nothing}`: Generated callable, or `nothing` until compilation.
- `criterion::CriterionType`: the computed value of the objective function / criterion for this candidate function. for numerical criterion of type `T<:Number`, bigger value of criterion indicates worse performance of the candidate function.
- `computed_criterion::Bool`: whether the criterion has been computed yet. if `true`, the `criterion` field should be safe to use, otherwise `criterion` needs to be computed first.
"""
mutable struct CandidateFunction{CriterionType, AlgorithmParametersType <: AlgorithmParameters}
    fdecl::Expr
    algparams_ref::AlgorithmParametersType
    callable::Union{RuntimeGeneratedFunction, Nothing} # WARNING: check if there's no mismatch between fdecl and callable occuring anywhere if fdecl is changed potentially
    criterion::CriterionType
    computed_criterion::Bool
end

function CandidateFunction{T, AP}(fdecl::Expr, algparams_ref::AP) where {T, AP<:AlgorithmParameters}
    CandidateFunction{T, AP}(fdecl, algparams_ref, nothing, Base.zero(T), false)
end


"""
Create linked algorithm parameters and an initial candidate function.

# Returns
- `Tuple{AlgorithmParameters, CandidateFunction{_candidate_function_criterion_type}}`: The configuration and candidate sharing that configuration.
"""
function init(
    _initial_fdecl::Expr,
    _f_return_type::Type,
    _all_ops::Dict{Type, Vector{AllowedOperationDescription}},
    _mutation_backend::MutationType,
    _crossover_backend::CrossoverType,
    _selection_backend::SelectionType,
    _apply_literal_optim::Bool,
    _literal_optim_iters::Int,
    ::Type{CT};
    statement_weights::AbstractDict{Symbol, <:Real}=_default_statement_weights(),
) where {MutationType <: MutationAlgorithmBackend, CrossoverType <: CrossoverAlgorithmBackend, SelectionType <: SelectionAlgorithmBackend, CT}
    algparams = AlgorithmParameters(
        get_arg_types(_initial_fdecl),
        _f_return_type,
        _all_ops,
        _mutation_backend,
        _crossover_backend,
        _selection_backend,
        _apply_literal_optim,
        _literal_optim_iters;
        statement_weights,
    )
    cf = CandidateFunction{CT, typeof(algparams)}(_initial_fdecl, algparams)
    generate_callable!(cf)
    return algparams, cf
end
