#######################################################################
# randomkets
#######################################################################
"""
    randomkets(h, A, n)

Creates `n` random vectors with length `D = dim(h)` and stacks them into a `D×n` matrix.
The resulting ket amplitudes are normalized by `1/√n`.

This type of ket structure is useful e.g. in stochastic trace evaluation of KPM methods,
where the amplitude, `a = cis(2pi*rand())` is chosen as a random function s.t. `⟨a⟩ = 0`,
`⟨aa⟩ = 0` and `⟨a'a⟩ = 1`. Then,
the normalized trace of an operator `A` can be estimated with `Tr[A]/N₀ ≈ ∑⟨ket|A|ket⟩`,
where the sum is taken over the `n` random kets `|ket⟩` of norm `1/√n` produced by
`randomkets`, and `N₀` is the total number of orbitals in the full unit cell.

By default when applied to a multiorbital system with a maximum of `N` orbitals per site, 
the generated kets have independent, complex, normally-distributed random components.
"""
function randomkets(h, A, n)
    dim = size(h,1)
    rkets = zeros(promote_type(eltype(h), eltype(A)), dim, n)
    [rkets[i,j] = cis(2pi*rand())/√n for i in 1:dim for j in 1:n]
    return rkets
end

#######################################################################
# Kernel Polynomial Method : momenta
#######################################################################
using Base.Threads

struct MomentaKPM{T, B<:Tuple}
    mulist::Vector{T}
    bandbracket::B
end

struct KPMBuilder{AM,HM<:AbstractMatrix,T,K<:AbstractMatrix,B}
    hmat::HM
    Amat::AM
    ket0::K
    ket1::K
    ket2::K
    bandbracket::Tuple{B,B}
    order::Int
    mulist::Vector{T}
end

function KPMBuilder(h, A, ket_or_randkets, order, bandrange) where {L}
    eh = eltype(eltype(h))
    eA = eltype(eltype(A))
    mulist = zeros(promote_type(eh, eA), order + 1)
    bandbracket = bandbracketKPM(h, bandrange)
    zeroket = ketseed_KPM(ket_or_randkets)
    builder = KPMBuilder(h, A, zeroket, similar(zeroket), similar(zeroket), bandbracket, 
        order, mulist)
    return builder
end

ketseed_KPM(k::AbstractVector) = 
    size(k,1) > size(k,2) ? reshape(k, :, 1) : reshape(Matrix(k'), :, 1)

ketseed_KPM(k::AbstractMatrix) = reshape(k[:,1],:,1)


"""
    `momentaKPM(h, A = I; kets = randomkets(h, A, n), order = 10, bandrange = missing)`

Compute the Kernel Polynomial Method (KPM) momenta `μₙ = ⟨k|Tₙ(h) A|k⟩`, where `|k⟩` may 
either refer to a single ket (kets::AbstractVector), or a set of `kets::AbstractMatrix` 
stored as columns, or to a collection of `n` random kets generated by `randomkets(h, A, n)`.
`A` is an observable (`AbstractMatrix`) and `Tₙ(h)` is the order-`n` Chebyshev polynomial of
the Hamiltonian `h`.

For the randomkets case, `μₙ` is summed over all kets, `μₙ= ∑_k ⟨k|Tₙ(h) A|k⟩`. 
If `kets` are a multi-column ket, a sum over columns will similarly be performed. 

`kets` generated with `randomkets()` are useful to estimate momenta of normalized traces 
using the stochastic trace approach, whereby `μ_n = Tr[A T_n(h)]/N₀ ≈ ∑ₖ⟨k|A T_n(h)|k⟩`. 
Here the `|k⟩`s are `n` random kets of norm `1/√n` and `N₀` is the total number of orbitals
per unit cell of `h` (see `randomkets`).

The order of the Chebyshev expansion is `order`. The `bandbrange = (ϵmin, ϵmax)` should
completely encompass the full bandwidth of `hamiltonian`. If `missing` it is computed
automatically using `ArnoldiMethod` (must be loaded `using ArnoldiMethod`). 

# Examples

```
julia> momentaKPM(h, I, kets = randomkets(h, I, 5), order = 20)

julia> momentaKPM(h, bandrange = (-6,6)).mulist |> length

```
"""
function momentaKPM(h, A = I; kets = randomkets(h, A, 1), order = 10, bandrange = missing) 
    builder = KPMBuilder(h, A, kets, order, bandrange)
    momentaKPM!(builder, kets)
    jackson!(builder.mulist)
    return MomentaKPM(builder.mulist, builder.bandbracket)
end

function momentaKPM!(b::KPMBuilder, kets::AbstractMatrix)
    aux_ket = b.ket0 # pointer to b.ket0
    for i in 1:size(kets, 2) #number of vectors
        aux_ket .= kets[:, i] #updating builder content
        pmeter = Progress(b.order, "Computing moments: ")
        addmomentaKPM!(b, pmeter)
    end
    return nothing
end

function momentaKPM!(b::KPMBuilder, kets::AbstractVector)  
    momentaKPM!(b, reshape(kets,:,1))
end


# This iterates bras <psi_n| = <psi_0|AT_n(h) instead of kets (faster CSC multiplication)
# In practice we iterate their conjugate |psi_n> = T_n(h') A'|psi_0>, and do the projection
# onto the start ket, |psi_0>
function addmomentaKPM!(b::KPMBuilder{<:AbstractMatrix,<:AbstractSparseMatrix}, pmeter)
    mulist = b.mulist
    kmat, kmat0, kmat1 = parent.((b.ket0, b.ket1, b.ket2))
    h, A, bandbracket = b.hmat, b.Amat, b.bandbracket
    order = length(mulist) - 1
    mul!(kmat0, A', kmat)
    mulscaled!(kmat1, h', kmat0, bandbracket)
    mulist[1] += proj(kmat0, kmat)
    mulist[2] += proj(kmat1, kmat)
    for n in 3:(order+1)
        ProgressMeter.next!(pmeter; showvalues = ())
        iterateKPM!(kmat0, h', kmat1, bandbracket)
        mulist[n] += proj(kmat0, kmat)
        kmat0, kmat1 = kmat1, kmat0
    end
    return mulist
end

function addmomentaKPM!(b::KPMBuilder{<:UniformScaling, <:AbstractSparseMatrix,T}, pmeter) where {T}
    mulist = b.mulist
    kmat, kmat0, kmat1 = parent.((b.ket0, b.ket1, b.ket2))
    h, A, bandbracket = b.hmat, b.Amat, b.bandbracket
    order = length(mulist) - 1
    kmat0 .= kmat
    mulscaled!(kmat1, h', kmat0, bandbracket)
    mulist[1] += μ0 = proj(kmat0, kmat0)
    mulist[2] += μ1 = proj(kmat1, kmat0)
    # This is not used in the currently activated codepath (BLAS mul!), but is needed in the
    # commented out @threads codepath
    thread_buffers = (zeros(T, Threads.nthreads()), zeros(T, Threads.nthreads()))
    for n in 3:2:(order+1)
        ProgressMeter.next!(pmeter; showvalues = ())
        ProgressMeter.next!(pmeter; showvalues = ()) # twice because of 2-step
        proj11, proj10 = iterateKPM!(kmat0, h', kmat1, bandbracket, thread_buffers)
        mulist[n] += 2 * proj11 - μ0
        n + 1 > order + 1 && break
        mulist[n + 1] += 2 * proj10 - μ1
        kmat0, kmat1 = kmat1, kmat0
    end
    A.λ ≈ 1 || (mulist .*= A.λ)
    return mulist
end

function mulscaled!(y, h´, x, (center, halfwidth))
    mul!(y, h´, x)
    invhalfwidth = 1/halfwidth
    @. y = (y - center * x) * invhalfwidth
    return y
end

function iterateKPM!(kmat0, h´, kmat1, (center, halfwidth), buff = ())
    α = 2/halfwidth
    β = 2center/halfwidth
    mul!(kmat0, h´, kmat1, α, -1)
    @. kmat0 = kmat0 - β * kmat1
    return proj_or_nothing(buff, kmat0, kmat1)
end

proj_or_nothing(::Tuple{}, kmat0, kmat1) = nothing
proj_or_nothing(buff, kmat0, kmat1) = (proj(kmat1, kmat1), proj(kmat1, kmat0))

# This is equivalent to tr(kmat1'*kmat2) for matrices
proj(kmat1, kmat2) = dot(kmat1, kmat2)

# function iterateKPM!(ket0, h´, ket1, (center, halfwidth), thread_buffers = ())
#     h = parent(h´)
#     nz = nonzeros(h)
#     rv = rowvals(h)
#     α = -2 * center / halfwidth
#     β = 2 / halfwidth
#     reset_buffers!(thread_buffers)
#     @threads for row in 1:size(ket0, 1)
#         ptrs = nzrange(h, row)
#         @inbounds for col in 1:size(ket0, 2)
#             k1 = ket1[row, col]
#             tmp = α * k1 - ket0[row, col]
#             for ptr in ptrs
#                 tmp += β * adjoint(nz[ptr]) * ket1[rv[ptr], col]
#             end
#             # |k0⟩ → (⟨k1|2h - ⟨k0|)' = 2h'|k1⟩ - |k0⟩
#             ket0[row, col] = tmp
#             update_buffers!(thread_buffers, k1, tmp)
#         end
#     end
#     return sum_buffers(thread_buffers)
# end

# reset_buffers!(::Tuple{}) = nothing
# function reset_buffers!((q, q´))
#     fill!(q, zero(eltype(q)))
#     fill!(q´, zero(eltype(q´)))
#     return nothing
# end

# @inline update_buffers!(::Tuple{}, k1, tmp) = nothing
# @inline function update_buffers!((q, q´), k1, tmp)
#     q[threadid()]  += dot(k1, k1)
#     q´[threadid()] += dot(tmp, k1)
#     return nothing
# end

# @inline sum_buffers(::Tuple{}) = nothing
# @inline sum_buffers((q, q´)) = (sum(q), sum(q´))

function jackson!(μ::AbstractVector)
    order = length(μ) - 1
    @inbounds for n in eachindex(μ)
        μ[n] *= ((order - n + 1) * cos(π * n / (order + 1)) +
                sin(π * n / (order + 1)) * cot(π / (order + 1))) / (order + 1)
    end
    return μ
end

function bandbracketKPM(h, ::Missing)
    bandbracketKPM(h, bandrangeKPM(h))
end

bandbracketKPM(h, (ϵmin, ϵmax)::Tuple{T,T}, pad = float(T)(0.01)) where {T} = 
    ((ϵmax + ϵmin) / 2, (ϵmax - ϵmin) / (2 - pad))

function bandrangeKPM(h::AbstractMatrix{T}; quiet = false) where {T}
    if quiet == true 
        nothing
    else @warn "Computing spectrum bounds... Consider using the `bandrange` 
            option for faster performance."
    end
    R = real(T)
    decompl, _ = Main.ArnoldiMethod.partialschur(h, nev=1, tol=1e-4, 
        which = Main.ArnoldiMethod.LR());
    decomps, _ = Main.ArnoldiMethod.partialschur(h, nev=1, tol=1e-4, 
        which = Main.ArnoldiMethod.SR());
    ϵmax = R(real(decompl.eigenvalues[1]))
    ϵmin = R(real(decomps.eigenvalues[1]))
    if quiet == true nothing
    else @warn("Computed bandrange = ($ϵmin, $ϵmax)") end
    return (ϵmin, ϵmax)
end

#######################################################################
# Kernel Polynomial Method : observables
#######################################################################
"""
    dosKPM(h::AbstractMatrix; resolution = 2, kets = randomkets(1), kw...)

Compute, using the Kernel Polynomial Method (KPM), the local density of states `ρₖ(ϵ) =
⟨k|δ(ϵ-h)|k⟩` for a single ket `|k⟩`, a collection of `{|k_i⟩}`, or a set of randomly-
generated kets for a stochastic trace calculation(see `momentaKPM`).

The result is a tuple of energy points `ϵᵢ::Vector` spanning the band range,
and real `ρₖ(ϵᵢ)::Vector` values (any residual imaginary part in `ρₖ` is dropped). The
number of energy points `ϵᵢ` is `order * resolution`, rounded to the closest integer.

If `kets` contains more than a single ket, the sum `∑ₖρₖ(ε)` over all models will be
computed. In the case of the default `kets = randomkets(h, I, n)`, this results in an
estimate of the total density of states per orbital, computed through an stochastic trace, 
`ρ(ϵ) = ∑ₖ⟨k|δ(ϵ-h)|k⟩/n ≈ Tr[δ(ϵ-h)]/N₀`, where `N₀` is the total number of orbitals in the
unit cell.

`dosKPM` is a particular case of `densityKPM` for an operator `A = I` and with any residual
imaginary parts dropped

    `dosKPM(μ::MomentaKPM; resolution = 2)`

Same as above with KPM momenta `μ` as input.

# See also
    `momentaKPM`, `densityKPM`, `averageKPM`
"""
dosKPM(h; resolution = 2, kets = randomkets(h, I, 1), kw...) =
    dosKPM(momentaKPM(h, I; kets = kets, kw...), resolution = resolution)

dosKPM(μ::MomentaKPM; resolution = 2) = real.(densityKPM(μ; resolution = resolution))

"""
    densityKPM(h::AbstractMatrix, A; resolution = 2, kets = randomkets(1), kw...)

Compute, using the Kernel Polynomial Method (KPM), the spectral density of `A`, `ρᴬₖ(ϵ) =
⟨k|A δ(ϵ-h)|k⟩` for a single ket `|k⟩`, a collection of `{|k_i⟩}`, or a set of randomly-
generated kets for a stochastic trace calculation(see `momentaKPM`).

The result is a tuple of energy points `ϵᵢ::Vector` spanning the band  range, and real 
`ρᴬₖ(ϵᵢ)::Vector` values. The number of energy points `ϵᵢ` is `order *resolution`, 
rounded to the closest integer.

If `kets` contains more than a single ket, the sum `∑ₖρₖ(ε)` over all models will be
computed. In the case of the default `kets = randomkets(h, I, n)`, this results in an
estimate of the total density of states per orbital, computed through an stochastic trace, 
`ρ(ϵ) = ∑ₖ⟨k|δ(ϵ-h)|k⟩/n ≈ Tr[δ(ϵ-h)]/N₀`, where `N₀` is the total number of orbitals in the
unit cell.

    `densityKPM(μ::MomentaKPM; resolution = 2)`

Same as above with KPM momenta `μ` as input.

# See also
    `dosKPM`, `momentaKPM`, `averageKPM`
"""
densityKPM(h, A; resolution = 2, kw...) =
    densityKPM(momentaKPM(h, A; kw...); resolution = resolution)

function densityKPM(momenta::MomentaKPM{T}; resolution = 2) where {T}
    (center, halfwidth) = momenta.bandbracket
    numpoints = round(Int, length(momenta.mulist) * resolution)
    ρlist = zeros(T, numpoints)
    copyto!(ρlist, momenta.mulist)
    Main.FFTW.r2r!(ρlist, Main.FFTW.REDFT01, 1)  # DCT-III in FFTW
    xk = [cos(π * (k + 0.5) / numpoints) for k in 0:numpoints - 1]
    @. ρlist = center + halfwidth * ρlist / (π * sqrt(1.0 - xk^2))
    @. xk = center + halfwidth * xk
    return xk, ρlist
end

"""
    `averageKPM(h::AbstractMatrix, A; kBT = 0, Ef = 0, kw...)`

Compute, using the Kernel Polynomial Method (KPM), the thermal expectation value `⟨A⟩ = Σ_k
f(E_k) ⟨k|A|k⟩ = ∫dE f(E) Tr [A δ(E-H)]/N₀ = Tr [A f(H)]/N₀` for a given hermitian operator
`A` and a zero-dimensional hamiltonian `h` with a total of `N₀` orbitals (see `momentaKPM`
and its options `kw` for further details). `f(E)` is the Fermi-Dirac distribution function,
`|k⟩` are `h` eigenstates with energy `E_k`, kBT` is the temperature in energy units and
`Ef` the Fermi energy.

    `averageKPM(μ::MomentaKPM, A; kBT = 0, Ef = 0)``

Same as above with the KPM momenta as input (see `momentaKPM`).

# See also
    `dosKPM`, `momentaKPM`, `averageKPM`
"""
averageKPM(h, A; kBT = 0, Ef = 0, kw...) = averageKPM(momentaKPM(h, A; kw...); kBT = kBT, 
    Ef = Ef)

function averageKPM(momenta::MomentaKPM; kBT = 0.0, Ef = 0.0)
    (center, halfwidth) = momenta.bandbracket
    order = length(momenta.mulist) - 1
    # if !iszero(kBT)
    #     @warn "Finite temperature requires numerical evaluation of the integrals"
    #     checkloaded(:QuadGK)
    # end
    average = sum(n -> momenta.mulist[n + 1] * fermicheby(n, Ef, kBT, center, halfwidth),
         0:order)
    return average
end

# Pending issue: Unexpected behaviour with center != 0.
function fermicheby(n, Ef, kBT, center, halfwidth)
    kBT´ = kBT / halfwidth;
    Ef´ = (Ef - center) / halfwidth;
    T = typeof(Ef´)
    if kBT´ == 0
        int = n == 0 ? 0.5+asin(Ef´)/π : -2.0*sin(n*acos(Ef´))/(n*π)
    else
        throw(error("Finite temperature not yet implemented"))
        # η = 1e-10
        # int = Main.QuadGK.quadgk(E´ -> _intfermi(n, E´, Ef´, kBT´), -1.0+η, 1.0-η, 
        #   atol= 1e-10, rtol=1e-10)[1]
    end
    return T(int)
end

_intfermi(n, E´, Ef´, kBT´) = fermifun(E´, Ef´, kBT´) * 2/(π*(1-E´^2)^(1/2)) * 
    chebypol(n, E´) / (1+(n == 0 ? 1 : 0))

fermifun(E´, Ef´, kBT´) = kBT´ == 0 ? (E´<Ef´ ? 1.0 : 0.0) : (1/(1+exp((E´-Ef´)/(kBT´))))

function chebypol(m::Int, x::T) where {T<:Number}
    cheby0 = one(T)
    cheby1 = x
    if m == 0
        chebym = cheby0
    elseif m == 1
        chebym = cheby1
    else
        for i in 2:m
            chebym = 2x * cheby1 - cheby0
            cheby0, cheby1 = cheby1, chebym
        end
    end
    return chebym
end
