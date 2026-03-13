module CodeRegression

using Random
using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(CodeRegression)

include("types.jl");
include("utils.jl");
include("literal_visitor.jl");
include("constructors.jl");
include("init.jl");
include("merging.jl");
include("generation.jl");
include("mutation.jl");
include("literal_optimization.jl");
include("recipes.jl");

export mutate, reproduce, _cw_, CandidateFunction, AlgorithmParameters, AllowedOperationDescription, init, swap_literals_with_params, optimize_literals!, generate_callables!

end # module CodeRegression
