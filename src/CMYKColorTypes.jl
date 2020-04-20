module CMYKColorTypes

using ColorTypes
using ColorTypes.FixedPointNumbers

import ColorTypes: eltype_default, coloralpha, alphacolor, comp1, comp2, comp3, comp4
import ColorTypes: _convert
import Base: +, -, *, /, convert

export AbstractCMYK, TransparentCMYK, AbstractACMYK, AbstractCMYKA
export CMYK, ACMYK, CMYKA
export cyan, magenta, yellow, black, total_ink_coverage


include("types.jl")
include("traits.jl")
include("conversions.jl")
include("operations.jl")

end # module
