using SortMark
using Documenter

DocMeta.setdocmeta!(SortMark, :DocTestSetup, :(using SortMark); recursive=true)

makedocs(;
    modules=[SortMark],
    authors="Lilith Orion Hafner <60898866+LilithHafner@users.noreply.github.com> and contributors",
    repo="https://github.com/LilithHafner/SortMark.jl/blob/{commit}{path}#{line}",
    sitename="SortMark.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/SortMark.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/SortMark.jl",
    devbranch="main",
)
