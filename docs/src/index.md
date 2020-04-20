# CMYKColorTypes

This package is an add-on to [ColorTypes](https://github.com/JuliaGraphics/ColorTypes.jl),
and provides color types for [process color](https://en.wikipedia.org/wiki/CMYK_color_model),
i.e. cyan, magenta, yellow and key (black) color model.

```@setup ex
using CMYKColorTypes
```
## Type design
The [`CMYK`](@ref) type is defined as follows:
```julia
struct CMYK{T <: Fractional} <: AbstractCMYK{T}
    c::T # cyan in [0, 1]
    m::T # magenta in [0, 1]
    y::T # yellow in [0, 1]
    k::T # black in [0, 1]
    CMYK{T}(c::T, m::T, y::T, k::T=zero(T)) where {T} = new{T}(c, m, y, k)
end
```
For each component value, `0` means 0% ink density and `1` means 100% ink
density. Thus, `CMYK(0, 0, 0, 0)` means white (i.e. the underlying color) and
`CMYK(1, 1, 1, 1)` means [registration black](https://en.wikipedia.org/wiki/Registration_black)
 (or 400% black).
Note that some graphics tools and image formats may encode 0% ink density as a
saturated value and 100% ink density as zero. You can invert the scale using
[`CMYKColorTypes.complement`](@ref).

The parameter `T` specifies the type of the components. You can use
`AbstractFloat` and [`FixedPoint`](https://github.com/JuliaMath/FixedPointNumbers.jl)
for `T`. It defaults to `N0f8`.

In addition, the transparent color variants [`ACMYK`](@ref) and [`CMYKA`](@ref)
are defined.

Similarly to `AbstractRGB` and `TransparentRGB`, `CMYK` and `ACMYK`/`CMYKA` are
defined as subtypes of [`AbstractCMYK`](@ref) and [`TransparentCMYK`](@ref)
respectively.
Although this package does not define any other concrete types, some subtypes
specific to certain storage formats or color profiles may be used. When writing
generic code, it is recommended to use the accessors ([`cyan`](@ref),
[`magenta`](@ref), [`yellow`](@ref), and [`black`](@ref)), instead of accessing
the fields directly.

`CMYK`, `ACMYK`, and `CMYKA` have the constructors within the same style as for
the other color types defined in ColorTypes.jl.

```@repl ex
CMYK{Float32}(1, 0.5, 0.2, 0) # explicitly specifying the component type
CMYK(1, 0, 0, 0) # If all arguments are integers (`0` or `1`), `N0f8` will be used
CMYK(1, 0.5, 0.2f0, 0) # the component type is promoted to `Float64`
CMYK(1.0f0, 0.5f0, 0.2f0) # `k` (black) can be omitted
ACMYK(1, 0.5, 0.2, 0, 0.8) # alpha (`= 0.8`) is always last
ACMYK(CMYK(1, 0, 0, 0)) # alpha defaults to `1`
CMYKA(ACMYK(1, 0, 0, 0, 1), 0.8) # overwriting the alpha
```

## Conversion
In principle, CMYKColorTypes does not support the color space conversion. While
`RGB` is associated with an absolute color space "sRGB" by default, `CMYK` is
not associated with a specific color profile. There is no point in conversions
which are not based on color profiles, and the handling of color profiles is out
of scope of this minimal package.

In practice, however, CMYKColorTypes does implement the conversion between
`AbstractRGB` and `CMYK` only for preview purposes.

!!! warning
    You should never use the default conversions for commercial printing or
    academic papers. For color space conversions, please use proper color
    profiles and configurations (e.g. rendering intent) with a color management
    system.

    The implementation of the default conversions is completely custom to this
    package, and there are no intentions to keep it compatible in future
    versions.

```@repl ex
using ColorTypes;
convert(RGB, CMYK(1.0, 0.5, 0.2, 0.1))
convert(CMYK, RGB24(1.0, 0.5, 0.2))
```
```@example ex
using Colors
[CMYK(1.0, 0.5, 0.2, 0.1), CMYK(0.1, 1.0, 0.5, 0.2), CMYK(0.2, 0.1, 1.0, 0.5)]
```
On the other hand, in some use cases, conversion methods that are independent of
color profiles and devices may be useful. Hence, this package provides the
conversion methods defined in
[CSS Color Module Level 4 (Working Draft)](https://www.w3.org/TR/css-color-4/#cmyk-rgb)
as [`CMYKColorTypes.naively_convert`](@ref).
```@repl ex
using CMYKColorTypes: naively_convert;
seagreen = colorant"seagreen"
naively_convert(CMYK, seagreen)
```
Of course, this methods yields very different results from conversions based on
practical color profiles for printed materials.
- Lab colors from the Fogra MediaWedge CMYK V3.0
```@example ex
permutedims(reshape(first.(Main.FOGRA53_COLORS_SRGB), (24, 3))) # hide
```
- `naively_convert`
```@example ex
permutedims(reshape(naively_convert.(RGB, first.(Main.FOGRA53_COLORS)), (24, 3))) # hide
```
- default conversion
```@example ex
permutedims(reshape(first.(Main.FOGRA53_COLORS), (24, 3))) # hide
```

## Arithmetic
If we consider each CMYK component value as an amount of ink, it is physically
reasonable to assume the linearity. Therefore, the arithmetic operations of
addition, subtraction and real number scaling are implemented. However, there
are no definitions for multiplying CMYK colors or for arithmetic between
different color spaces.

```@repl ex
CMYK(0.1, 0.2, 0.3, 0.5) + CMYK(0.0, 0.2, 0.125, 0.25)
CMYK(0.1, 0.2, 0.3, 0.5) - CMYK(0.0, 0.2, 0.125, 0.25)
CMYK(0.1, 0.2, 0.3, 0.5) * 0.5
CMYK(0.1, 0.2, 0.3, 0.5) / 2
```
Note that if the component type is a `FixedPoint` type such as `N0f8`, the
operation result will be wrapped around when an overflow occurs.
```@repl ex
using FixedPointNumbers;
CMYK{N0f8}(0.2, 0.4, 0.6, 0.8) + CMYK{N0f8}(0.4, 0.4, 0.4, 0.4) # overflow in K
```
