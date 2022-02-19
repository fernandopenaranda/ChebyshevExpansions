using ChebyshevExpansions
using Documenter

DocMeta.setdocmeta!(ChebyshevExpansions, :DocTestSetup, :(using ChebyshevExpansions); recursive=true)

makedocs(;
    modules=[ChebyshevExpansions],
    authors="Fernando Peñaranda, Pablo San-Jose",
    repo="https://github.com/fernandopenaranda/ChebyshevExpansions.jl/blob/{commit}{path}#{line}",
    sitename="ChebyshevExpansions.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://fernandopenaranda.github.io/ChebyshevExpansions.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/fernandopenaranda/ChebyshevExpansions.jl",
    devbranch="main",
)
