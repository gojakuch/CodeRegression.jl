module CodeRegression

using Random

include("types.jl");
include("utils.jl");
include("constructors.jl");
include("merging.jl");
include("generating.jl");
include("mutating.jl");

export mutate, reproduce

end # module CodeRegression
