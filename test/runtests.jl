using Test, CMYKColorTypes

using ColorTypes
using Colors
using FixedPointNumbers

@test isempty(detect_ambiguities(CMYKColorTypes, Base, ColorTypes, Colors))

@testset "types" begin
    # include("types.jl")
end
@testset "traits" begin
    include("traits.jl")
end

@testset "conversions" begin
    include("conversions.jl")
end

@testset "show" begin
    io = IOBuffer()
    cmyk = CMYK(0.2, 0.4, 0.6, 0.8)
    cmyk_f32 = CMYK{Float32}(0.2, 0.4, 0.6, 0.8)
    acmyk = ACMYK{N0f8}(0.2, 0.4, 0.6, 0.8, 1.0)
    show(io, CMYK)
    @test String(take!(io)) == "CMYK"
    show(io, cmyk)
    @test replace(String(take!(io)), ", " => ",") == "CMYK{Float64}(0.2,0.4,0.6,0.8)"
    show(IOContext(io, :compact => true), cmyk_f32)
    @test replace(String(take!(io)), ", " => ",") == "CMYK{Float32}(0.2,0.4,0.6,0.8)"
    show(IOContext(io, :compact => true), acmyk)
    @test replace(String(take!(io)), ", " => ",") == "ACMYK{N0f8}(0.2,0.4,0.6,0.8,1.0)"
end
