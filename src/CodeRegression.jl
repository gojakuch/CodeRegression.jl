module CodeRegression

using Random

include("types.jl");
include("utils.jl");
include("literal_visitor.jl");
include("constructors.jl");
include("init.jl");
include("merging.jl");
include("generating.jl");
include("mutating.jl");
include("literal_optimization.jl");

export mutate, reproduce, _cw_, CandidateFunction, AlgorithmParameters, AllowedOperationDescription, init, swap_literals_with_params, optimize_literals!

end # module CodeRegression
