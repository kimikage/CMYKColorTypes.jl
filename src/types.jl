
"""
    AbstractCMYK{T} <: Color{T, 4}

Abstract supertype for opaque CMYK color types.
"""
abstract type AbstractCMYK{T} <: Color{T, 4} end

"""
    TransparentCMYK{C <: AbstractCMYK, T} = TransparentColor{C, T, 5}

An alias for the abstract supertype for transparent CMYK color types.
"""
TransparentCMYK{C <: AbstractCMYK, T} = TransparentColor{C, T, 5}

"""
    AbstractACMYK{C <: AbstractCMYK, T} = AlphaColor{C, T, 5}

An alias for the abstract supertype for CMYK color types with alpha stored
first.
"""
AbstractACMYK{C <: AbstractCMYK, T} = AlphaColor{C, T, 5}

"""
    AbstractCMYKA{C <: AbstractCMYK, T} = ColorAlpha{C, T, 5}

An alias for the abstract supertype for CMYK color types with alpha stored last.
"""
AbstractCMYKA{C <: AbstractCMYK, T} = ColorAlpha{C, T, 5}

const ColorantCMYK = Union{AbstractCMYK, TransparentCMYK}
const ColorantRGB = Union{AbstractRGB, TransparentRGB}

"""
    CMYK{T <: Fractional} <: AbstractCMYK{T}

`CMYK` is a general type for representing process color (i.e. cyan, magenta,
yellow and black). For each component value, `0` means 0% ink density and `1`
means 100% ink density.
"""
struct CMYK{T <: Fractional} <: AbstractCMYK{T}
    c::T # cyan in [0, 1]
    m::T # magenta in [0, 1]
    y::T # yellow in [0, 1]
    k::T # black in [0, 1]
    CMYK{T}(c::T, m::T, y::T, k::T=zero(T)) where {T} = new{T}(c, m, y, k)
end

"""
    ACMYK{T <: Fractional} <: AbstractACMYK{CMYK{T}, T}

`ACMYK` is a transparent color variant of [`CMYK`](@ref). `ACMYK` stores the
alpha component first, but its constructors always take the alpha component
last, i.e. in order of (cyan, magenta, yellow, black, alpha).
"""
struct ACMYK{T <: Fractional} <: AbstractACMYK{CMYK{T}, T}
    alpha::T
    c::T
    m::T
    y::T
    k::T
    function ACMYK{T}(c::T, m::T, y::T, k::T=zero(T), alpha::T=oneunit(T)) where T
        new{T}(alpha, c, m, y, k)
    end
end

"""
    CMYKA{T <: Fractional} <: AbstractCMYKA{CMYK{T}, T}

`CMYKA` is a transparent color variant of [`CMYK`](@ref). `ACMYK` stores the
alpha component last. See also [`ACMYK`](@ref).
"""
struct CMYKA{T <: Fractional} <: AbstractCMYKA{CMYK{T}, T}
    c::T
    m::T
    y::T
    k::T
    alpha::T
    function CMYKA{T}(c::T, m::T, y::T, k::T=zero(T), alpha::T=oneunit(T)) where T
        new{T}(c, m, y, k, alpha)
    end
end

eltype_default(::Type{<:AbstractCMYK}) = N0f8

alphacolor(::Type{CMYK}) = ACMYK
coloralpha(::Type{CMYK}) = CMYKA

(::Type{C})(c, m, y) where {C <: AbstractCMYK} = C(c, m, y, zero(c))
(::Type{C})(c, m, y) where {C <: TransparentCMYK} = C(c, m, y, zero(c), 1)

if !hasmethod(CMYK, ())
    include("types_ctor.jl")
end
