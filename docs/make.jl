using Documenter, CMYKColorTypes
using Colors

include("logo_generator.jl")
using .LogoGenerator
open(joinpath(@__DIR__, "src", "assets", "logo.svg"), "w+") do f
    LogoGenerator.write_svg(f)
end

include(joinpath(@__DIR__, "..", "test", "samples.jl"))

makedocs(
    clean=false,
    checkdocs=:exports,
    modules=[CMYKColorTypes],
    format=Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true",
                           assets = ["assets/favicon.ico"]),
    sitename="CMYKColorTypes",
    pages=[
        "Introduction" => "index.md",
        "References" => "references.md",
    ]
)

deploydocs(
    repo="github.com/kimikage/CMYKColorTypes.jl.git",
    devbranch = "main",
    push_preview = true
)
