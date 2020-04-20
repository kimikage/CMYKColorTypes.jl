# Any AbstractCMYK types can be interconverted
function _convert(::Type{Cout}, ::Type{Ccmp}, ::Type{Ccmp}, c) where {Cout<:AbstractCMYK,Ccmp<:AbstractCMYK}
    Cout(cyan(c), magenta(c), yellow(c), black(c))
end
function _convert(::Type{A}, ::Type{Ccmp}, ::Type{Ccmp}, c, alpha=alpha(c)) where {A<:TransparentCMYK,Ccmp<:AbstractCMYK}
    A(cyan(c), magenta(c), yellow(c), black(c), alpha)
end


# In principle, CMYKColorTypes does not support conversion between color spaces.
# Here, only auxiliary conversions are implemented.

_n(c) = oneunit(c) - c # complement

"""
    naively_convert(::Type{<:Color}, c::Colorant)
    naively_convert(::Type{<:TransparentColor}, c::Colorant[, alpha])

Convert color types using the "naive" algorithm for RGB <--> CMYK conversions
defined in [CSS Color Module Level 4 (Working Draft)](https://www.w3.org/TR/css-color-4/#cmyk-rgb).

!!! warning
    This methods yields very different results from conversions based on
    practical color profiles for printed materials.
"""
function naively_convert(::Type{Cout},
    c::Union{AbstractCMYK,TransparentCMYK}) where {Cout<:Colorant}
    convert(Cout, natively_convert(Cout <: TransparentColor ? ARGB : RGB, c))
end

function naively_convert(::Type{Cout}, col::ColorantCMYK) where {Cout<:ColorantRGB}
    C = ccolor(Cout, typeof(col))
    c, m, y, k = cyan(col), magenta(col), yellow(col), black(col)
    r = _n(min(oneunit(c), muladd(c, _n(k), k)))
    g = _n(min(oneunit(m), muladd(m, _n(k), k)))
    b = _n(min(oneunit(y), muladd(y, _n(k), k)))
    return Cout <: TransparentColor ? C(r, g, b, alpha(col)) : C(r, g, b)
end

function naively_convert(::Type{Cout}, col::ColorantRGB) where {Cout<:ColorantCMYK}
    C = ccolor(Cout, typeof(col))
    r, g, b = red(col), green(col), blue(col)
    w = max(r, g, b)
    k = _n(w)
    if k === oneunit(k)
        z = zero(k)
        Cout <: TransparentColor ? C(z, z, z, k, alpha(col)) : C(z, z, z, k)
    end
    c = _n(r + k) / w
    m = _n(g + k) / w
    y = _n(b + k) / w
    return Cout <: TransparentColor ? C(c, m, y, k, alpha(col)) : C(c, m, y, k)
end


# Default conversions

# Here we overload the internal API of ColorTypes.jl so as not to interfere with
# the overriding with other conversion implementations in the higher-level
# packages.
function _convert(::Type{Cout}, ::Type{C1}, ::Type{C2}, c::AbstractRGB) where {Cout<:AbstractCMYK,C1<:Color,C2<:AbstractRGB}
    srgb_to_cmyk(Cout, c)
end

function _convert(::Type{Cout}, ::Type{C1}, ::Type{C2}, c::AbstractCMYK) where {Cout<:AbstractRGB,C1<:Color,C2<:AbstractCMYK}
    cmyk_to_srgb(Cout, c)
end

function _convert(::Type{Cout}, ::Type{C1}, ::Type{C2}, c::AbstractCMYK) where {Cout<:TransparentRGB,C1<:Color,C2<:AbstractCMYK}
    Cout(cmyk_to_srgb(C1, c), alpha(c))
end

function srgb_to_cmyk(::Type{Cout}, srgb::C) where {Cout<:AbstractCMYK,C<:AbstractRGB}
    return Cout(0, 0, 0, 0)
end

function cmyk_to_srgb(::Type{Cout}, cmyk::C) where {Cout<:AbstractRGB,C<:AbstractCMYK}
    #naively_convert(Cout, cmyk)
    return Cout(luv_to_srgb(cmyk_to_luv(cmyk)))
end

"""
    cmyk_to_luv(cmyk)

Converts a CMYK color into the L*u*v*-like color space without using costly
exponential functions.
"""
function cmyk_to_luv(cmyk::AbstractCMYK)
    c = Float32(cyan(cmyk))
    m = Float32(magenta(cmyk))
    y = Float32(yellow(cmyk))
    k = Float32(black(cmyk))
    cx = muladd(-0.52565930f0, c, 1.525659300f0) * c
    mx = muladd(-0.57580410f0, m, 1.548923500f0) * m
    yx = muladd(-0.51718330f0, y, 1.590272900f0) * y
    kx = muladd(-0.49250540f0, k, 1.475012700f0) * k
    @fastmath x = max(max(cx, mx), max(yx, kx))
    t = x === cx ? (0.542407900f0, 0.168309480f0, 0.054697484f0, 0.234585150f0) :
        x === mx ? (0.149083900f0, 0.577366000f0, 0.051057506f0, 0.222492640f0) :
        x === yx ? (0.211209520f0, 0.247950970f0, 0.233920370f0, 0.306919130f0) :
        (0.092350110f0, 0.100450610f0, 0.021816660f0, 0.785382600f0)
    l = 1.0f0 - sum((cx, mx, yx, kx) .* t)
    u = cosd(50.0f0) * (y + m) - c
    v = sind(50.0f0) * (y - m)
    return l, u, v
end

function luv_to_srgb(luv::NTuple{3,Float32})
    l, u, v = luv

    rl = @evalpoly(l, 0.0469305f0, -0.54071563f0, 2.336452f0, -1.3941513f0)
    ru = @evalpoly(l, 0.1539599f0, 1.1677985f0, -0.28224063f0, -1.1236708f0)
    rv = @evalpoly(l, -0.054397885f0, -1.1588284f0, 1.0031421f0, 0.48253167f0)
    r0 = @evalpoly(l, -0.0049729384f0, 0.66561717f0, 0.44100732f0, -0.59613305f0)
    gl = @evalpoly(l, -0.0037297956f0, 0.024432192f0, 1.1380341f0, -0.67750263f0)
    gu = @evalpoly(l, -0.020710705f0, -0.5516958f0, 0.11880806f0, 0.48552653f0)
    gv = @evalpoly(l, -0.18217045f0, 2.696454f0, -4.826348f0, 2.5084994f0)
    g0 = @evalpoly(l, -0.0065828683f0, 1.1974206f0, -0.68989617f0, -0.025275912f0)
    bl = @evalpoly(l, -0.1149118f0, 1.0777423f0, -1.3523277f0, 1.0286452f0)
    bu = @evalpoly(l, -0.20883206f0, 0.060814004f0, -1.6416869f0, 1.4992846f0)
    bv = @evalpoly(l, -0.3406363f0, 0.1043919f0, -0.37633023f0, -0.26443774f0)
    b0 = @evalpoly(l, -0.06707764f0, 1.7751663f0, -1.7879254f0, 0.55831516f0)

    r = clamp(rl * l + ru * u + rv * v + r0, 0.0f0, 1.0f0)
    g = clamp(gl * l + gu * u + gv * v + g0, 0.0f0, 1.0f0)
    b = clamp(bl * l + bu * u + bv * v + b0, 0.0f0, 1.0f0)

    return RGB(r, g, b)
end


function srgb_to_luv(rgb::AbstractRGB)
    r = Float32(red(rgb))
    g = Float32(green(rgb))
    b = Float32(blue(rgb))
    y = 0.299f0 * r + 0.587f0 * g + 0.114f0 * b

    ur = @evalpoly(y, 2.875582f0, -7.755033f0, 1.058406f01, -3.814208f0)
    ug = @evalpoly(y, -7.117121f-2, 2.362828f0, -1.031161f01, 7.440491f0)
    ub = @evalpoly(y, -1.892886f0, 1.701220f0, 1.925627f0, -2.607688f0)
    u0 = @evalpoly(y, 4.629790f-3, -1.337076f-1, 2.492981f0, -2.779856f0)

    vr = @evalpoly(y, -2.020922f-1, -1.272873f0, 9.775019f-1, -5.293535f-1)
    vg = @evalpoly(y, 4.024177f0, -2.945432f0, -2.934186f0, 4.866119f0)
    vb = @evalpoly(y, -2.093502f0, -5.327426f0, 1.690097f01, -1.149884f01)
    v0 = @evalpoly(y, -6.095449f-2, -1.273964f0, 5.100798f0, -3.970372f0)

    u = ur * r + ug * g + ub * b + u0
    v = vr * r + vg * g + vb * b + v0
    (y, u, v)
end
