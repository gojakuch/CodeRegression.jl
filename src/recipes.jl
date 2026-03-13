"""
    Generates callable for every candidate function without a callable in the candidates pair array.
"""
function generate_callables!(candidates::Vector{Pair{CandidateFunction, Float64}})
    for (cf, _) in candidates
        if isnothing(cf.callable)
            def = cf.fdecl
            cf.callable = @RuntimeGeneratedFunction(def)
        end
    end

    nothing
end

# TODO: add more complete pipelines here