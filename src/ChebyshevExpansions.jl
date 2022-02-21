module ChebyshevExpansions
    # Use README as the docstring of the module:
    @doc read(joinpath(dirname(@__DIR__), "README.md"), String) ChebyshevExpansions
    using LinearAlgebra, SparseArrays, ProgressMeter, FFTW, ArnoldiMethod
    export KPMBuilder, randomkets, momentaKPM, densityKPM, dosKPM, averageKPM
    #export momentaKPM, densityKPM, dosKPM, averageKPM
    include("KPM.jl")    
end

