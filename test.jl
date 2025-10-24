# comment out old stuff

# struct Candidate
#     AST::Expr
# end # probably needs to store the signature, variable types and the history

# ALLOWED_OPERATIONS = []
# ALLOWED_COMBINATIONS = []

# dump(ex)
# x = 10
# eval(:(x+x))
# eval(:(:x+:x))

# this file should eventually contain our tests for the CI

using Random
include("merging.jl")

f1 = quote
    function (x)
        if x > 0
            x = 0
        end
        x
    end
end
f1 = f1.args[2]

f2 = quote
    function (x)
        if x < 1
            x = 1  
        end
        x
    end
end
f2 = f2.args[2]

reproduce(f1, f2)
reproduce(f1, f2)
reproduce(f1, f2)

include("mutating.jl")

generate_regression(f1)

mutate(f1)

f1