using ChebyshevExpansions
using Test

@testset "ChebyshevExpansions.jl" begin
    
    using Quantica:hamiltonian, LatticePresets, RegionPresets, LatticePresets.honeycomb,
        RegionPresets.circle, hopping, unitcell

    using LinearAlgebra
    h = hamiltonian(unitcell(LatticePresets.honeycomb(a0 = .2), 
        region = RegionPresets.circle(1)), hopping(I))

    hmat = h.harmonics[1].h
    ket = ChebyshevExpansions.randomkets(eltype(hmat), eltype(hmat), size(hmat,1), 1)
    momentaKPM(hmat)
    momentaKPM(hmat, hmat, ket = 2)
    densityKPM(hmat, hmat, ket = 2)

end
