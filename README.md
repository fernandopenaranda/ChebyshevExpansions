# ChebyExpansions.jl
## Introduction
In this package, we implement the [Kernel Polynomial Method (KPM)](https://journals.aps.org/rmp/abstract/10.1103/RevModPhys.78.275) [1] in Julia, an efficient technique to compute spectral and correlation functions using order-N Chebyshev expansions of said quantities. 

Diagonalization in KPM is replaced by matrix multiplications and, thus, the resource consumption for a given precision drops to  <img src="https://latex.codecogs.com/svg.image?\mathcal{O}(D)" title="\mathcal{O}(D)" /> for sparse or <img src="https://latex.codecogs.com/svg.image?\mathcal{O}(D^2)" /> for dense matrices, being <img src="https://latex.codecogs.com/svg.image?D" />  the matrix dimension. 

In this regard, this technique is well suited for **large matrix calculations** where exact diagonalization becomes too expensive, e.g. when computing the density of states of a large multiorbital system.

In addition, KPM offers some advantages in terms of stability and resource consumption with respect to other recursive methods such as Lanczos-based techniques, see [1] for a comprehensive review. 

## Practical considerations

1. The energy resolution is controlled by the ratio <img src="https://latex.codecogs.com/svg.image?W/N" /> , where <img src="https://latex.codecogs.com/svg.image?W" />  is the bandwidth of <img src="https://latex.codecogs.com/svg.image?H" />  and <img src="https://latex.codecogs.com/svg.image?N" />  the expansion order. The complexity for sparse matrices goes like <img src="https://latex.codecogs.com/svg.image?\mathcal{O}(ND)" title="\mathcal{O}(ND)" />
2. The error in the stochastic trace estimation <img src="https://latex.codecogs.com/svg.image?&space;\mathcal{O}(1/\sqrt{DR})" title=" \mathcal{O}(1/\sqrt{DR})" />, being <img src="https://latex.codecogs.com/svg.image?R" /> the number of random kets considered.
3. For sparse matrices (the usual scenario) `h` and `A` should be `AbstractSparseMatrix` the preferred type (although it is not required).
## Observables 

Currently, given a hamiltonian matrix, <img src="https://latex.codecogs.com/svg.image?H" /> and a generic operator <img src="https://latex.codecogs.com/svg.image?A" /> the following methods are implemented:

* Momenta computation corresponding to traces over the product of Chebyshev polynomials of <img src="https://latex.codecogs.com/svg.image?H " /> and <img src="https://latex.codecogs.com/svg.image?A " />: <img src="https://latex.codecogs.com/svg.image?\mu_n&space;=&space;\text{Tr}[A&space;T_n(H)]" title="\mu_n = \text{Tr}[A T_n(H)]" />.
* Calculation of spectral densities of an operator <img src="https://latex.codecogs.com/svg.image?A(E)&space;=&space;\text{Tr}&space;[A&space;\delta(E-H)]" title="A(E) = \text{Tr} [A \delta(E-H)]" />.
* Calculation of thermal averages, i.e. <img src="https://latex.codecogs.com/svg.image?\langle&space;A\rangle&space;_{E_F}&space;=&space;\text{Tr}&space;[A&space;f(H,E_F)]" title="\langle A\rangle _{E_F} = \text{Tr} [A f(H,E_F)]" />.

Although, currently not implemented KPM momenta from `momentaKPM` can be used as the basis for a Chebyshev expansion of many interesting functions and observables such as correlation (Green's) functions, optical conductivities[1], equilibrium supercurrents[2]... 
## Exported functions
`randomkets, momentaKPM, densityKPM, dosKPM, averageKPM`
1. `randomkets` generates a collection of random kets for stochastic trace estimation
2. `momentaKPM` computes the Kernel Polynomial Method (KPM) momenta corresponding to the spectral densities or thermal average calculations
3. `densityKPM` computes the spectral density of some operator `A::AbstractMatrix` given a hamiltonian matrix `h::AbstractMatrix` using `momentaKPM`
4. `dosKPM` computes the density of states of `h::AbstractMatrix`. Note that <img src="https://latex.codecogs.com/svg.image?(A&space;==&space;I)" title="(A == I)" />
5. `averageKPM()` Thermal average KPM calculation of `A` given `h`. Finite temperature `kBT != 0`is not yet implemented.  

## References  
    
[1] A. Weiße, G. Wellein, A. Alvermann, and H. Fehske, *The
kernel polynomial method*, [Reviews of Modern Physics **78**, 275 (2006)](https://journals.aps.org/rmp/abstract/10.1103/RevModPhys.78.275).

[2] M. Irfan, S. R.Kuppuswamy, D. Varjas, P. M. Perez-Piskunow, R. Skolasinski, M. Wimmer, & A. R.  Akhmerov, (2019). *Hybrid kernel polynomial method*, [arXiv: arXiv:1909.09649v2](https://arxiv.org/abs/1909.09649v2).
