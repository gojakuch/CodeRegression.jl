module CodeRegression

using Random
using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(CodeRegression)

module SomeAlgo

    include("./some_algo/core/types.jl");

    include("./some_algo/literal/literal_optimization.jl");
    include("./some_algo/literal/literal_visitor.jl");
    include("./some_algo/literal/visitor_template.jl");

    include("./some_algo/operations/generation.jl");
    include("./some_algo/operations/merging.jl");
    include("./some_algo/operations/mutation.jl");

    include("./some_algo/utils.jl");

end #module SomeAlgo

export mutate, reproduce, _cw_, CandidateFunction, AlgorithmParameters, AllowedOperationDescription, init, swap_literals_with_params, optimize_literals!, generate_callables!

end # module CodeRegression
