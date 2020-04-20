using Test, CMYKColorTypes

using ColorTypes
using ColorTypes.FixedPointNumbers

@testset "accessors" begin
    cmyk = CMYK{Float32}(0.1, 0.2, 0.3, 0.4)
    acmyk = ACMYK{N0f8}(0.1, 0.2, 0.3, 0.4, 0.8)
    cmyka = CMYKA{Float64}(0.1, 0.2, 0.3, 0.4, 0.8)

    @test cyan(cmyk)  === 0.1f0
    @test cyan(acmyk) === 0.1N0f8
    @test cyan(cmyka) === 0.1

    @test magenta(cmyk)  === 0.2f0
    @test magenta(acmyk) === 0.2N0f8
    @test magenta(cmyka) === 0.2

    @test yellow(cmyk)  === 0.3f0
    @test yellow(acmyk) === 0.3N0f8
    @test yellow(cmyka) === 0.3

    @test black(cmyk)  === 0.4f0
    @test black(acmyk) === 0.4N0f8
    @test black(cmyka) === 0.4

    @test alpha(cmyk)  === 1.0f0
    @test alpha(acmyk) === 0.8N0f8
    @test alpha(cmyka) === 0.8
end

@testset "total_ink_coverage" begin
    @test total_ink_coverage(CMYK{Float64}(0.25, 0.75, 0.125, 0.125)) === 125.0
    @test total_ink_coverage(CMYK{N0f8}(1, 1, 1, 1)) === 400.0f0
    @test_throws MethodError total_ink_coverage(ACMYK())
end
