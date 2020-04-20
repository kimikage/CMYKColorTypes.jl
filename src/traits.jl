
"""
    cyan(c)

Returns the cyan component of an `AbstractCMYK` or `TransparentCMYK` color.
"""
cyan(c::Union{AbstractCMYK, TransparentCMYK}) = c.c

"""
    magenta(c)

Returns the magenta component of an `AbstractCMYK` or `TransparentCMYK` color.
"""
magenta(c::Union{AbstractCMYK, TransparentCMYK}) = c.m

"""
    yellow(c)

Returns the yellow component of an `AbstractCMYK` or `TransparentCMYK` color.
"""
yellow(c::Union{AbstractCMYK, TransparentCMYK}) = c.y

"""
    black(c)

Returns the black component of an `AbstractCMYK` or `TransparentCMYK` color.
"""
black(c::Union{AbstractCMYK, TransparentCMYK}) = c.k

comp1(c::Union{AbstractCMYK, TransparentCMYK}) = cyan(c)
comp2(c::Union{AbstractCMYK, TransparentCMYK}) = magenta(c)
comp3(c::Union{AbstractCMYK, TransparentCMYK}) = yellow(c)
comp4(c::Union{AbstractCMYK, TransparentCMYK}) = black(c)

"""
    CMYKColorTypes.complement(c)

Return the color with the color components of the complement (i.e.
`1 - compN(c)`).
If `c` is a `TransparentCMYK`, the alpha component is left untouched.

This function has the same functionality as `ColorVectorSpace.complement`.
Therefore, if you are using `ColorVectorSpace`, you do not need to specify the
module name explicitly. Also, to avoid name collisions, do not (re-)export this
function.

# Examples
```jldoctest; setup=(using CMYKColorTypes)
julia> CMYKColorTypes.complement(CMYKA(0.0, 0.2, 0.5, 0.75, 0.7)) # keeping the alpha
CMYKA{Float64}(1.0, 0.8, 0.5, 0.25, 0.7)
```
"""
complement(c::AbstractCMYK) = mapc(v -> oneunit(v) - v, c)
complement(c::C) where {C <: TransparentCMYK} = C(complement(color(c)), alpha(c))

"""
    total_ink_coverage(c::AbstractCMYK)

Returns the total ink coverage (TIC), or the total amount of cyan, magenta,
yellow, and black inks in percentage.
Although not exact, this value is often used as a substitute for the total area
coverage (TAC).
This function cannot be used for `TransparentCMYK` colors, because the physical
meaning is unclear.

# Examples
```jldoctest; setup=(using CMYKColorTypes)
julia> total_ink_coverage(CMYK{Float32}(1.0, 0.3, 0.2, 0.0))
150.0f0
```
"""
total_ink_coverage(c::AbstractCMYK) = mapreducec(float, +, zero(cyan(c)), c) * 100
