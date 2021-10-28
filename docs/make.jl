using Sortmark
using Documenter

DocMeta.setdocmeta!(Sortmark, :DocTestSetup, :(using Sortmark); recursive=true)

makedocs(;
    modules=[Sortmark],
    authors="Lilith Orion Hafner <60898866+LilithHafner@users.noreply.github.com> and contributors",
    repo="https://github.com/LilithHafner/Sortmark.jl/blob/{commit}{path}#{line}",
    sitename="Sortmark.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/Sortmark.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/Sortmark.jl",
    devbranch="main",
)
