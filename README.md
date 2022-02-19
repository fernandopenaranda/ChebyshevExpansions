# ChebyshevExpansions

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://fernandopenaranda.github.io/ChebyshevExpansions.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://fernandopenaranda.github.io/ChebyshevExpansions.jl/dev)
[![Build Status](https://github.com/fernandopenaranda/ChebyshevExpansions.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/fernandopenaranda/ChebyshevExpansions.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/fernandopenaranda/ChebyshevExpansions.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/fernandopenaranda/ChebyshevExpansions.jl)


# ChebyExpansions.jl
## Introduction
In this package, we implement the Kernel Polynomial Method (KPM) in Julia, an efficient technique to compute spectral and correlation functions using order-N Chebyshev expansions of said quantities. 

Diagonalization in KPM is replaced by matrix multiplications and, thus, the resource consumption for a given precission drops to $\mathcal{O}(D)$ for sparse or $\mathcal{O}(D^2)$ for dense matrices, being $D$ the matrix dimension. 

In this regard, this technique is well suited for **large matrix calculations** where exact diagonalization becomes too expensive. In addition, KPM offers some advantages in terms of stability and resource consumption with respect to other recursive methods such as Lanczos-based techniques, see [1] for a comprehensive review. 

## Practical considerations

1. The energy resolution is controlled by the ratio $W/N$, where $W$ is the bandwidth of $H$ and $N$ the expansion order. The complexity for sparse matrices goes like $\mathcal O(ND)$
2. The error in the stochastic trace estimation $\mathcal{O}(1/\sqrt{DR})$, being R the number of random kets considered.


## Observables 

Currently, given a hamiltonian matrix, $H$ and a generic operator $A$ the following methods are implemented:

* Momenta computation corresponding to traces over the product of Chebyshev polynomials of $H$ and $A$: $\mu_n = \text{Tr}[A T_n(H)]$.
* Calculation of spectral densities of an operator $A(E) = \text{Tr} [A 𝛿(E-H)]$.
* Calculation of thermal averages, i.e. $\langle A\rangle _{E_F} = \text{Tr} [A f(H,E_F)]$

## Exported functions
`momentaKPM`
`dosKPM` computes the density of states $(A == I)$
`densityKPM` 
`averageKPM` 
## References  
    
[1] A. Weiße, G. Wellein, A. Alvermann, and H. Fehske, *The
kernel polynomial method*, [Reviews of Modern Physics **78**, 275 (2006)](https://journals.aps.org/rmp/abstract/10.1103/RevModPhys.78.275).