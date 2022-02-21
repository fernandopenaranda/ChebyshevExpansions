module ChebyshevExpansions
    # Use README as the docstring of the module:
    @doc read(joinpath(dirname(@__DIR__), "README.md"), String) ChebyshevExpansions
    using LinearAlgebra, SparseArrays
    export KPMBuilder, momentaKPM
    #export momentaKPM, densityKPM, dosKPM, averageKPM
    include("KPM.jl")    
end

