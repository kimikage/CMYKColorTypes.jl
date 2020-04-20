using ColorTypes: ColorantN, ColorN, TransparentColorN, GrayLike, eltype_ub, checkval

@inline function promote_args_type(::Type{C}, args...) where {C<:Color}
    T = promote_type(map(typeof, args)...)
    _promote_args_type(eltype_ub(C), eltype_default(C), T)
end
@inline function promote_args_type(::Type{C}, args...) where {C<:TransparentColor}
    Ta = typeof(last(args)) # alpha
    T = _promote_wol(map(typeof, args)...)
    if T <: Union{Integer,FixedPoint} && Ta <: Integer
        _promote_args_type(eltype_ub(C), eltype_default(C), T)
    else
        _promote_args_type(eltype_ub(C), eltype_default(C), promote_type(T, Ta))
    end
end
# a variant of `promote_type` that ignores the last  (i.e. alpha) element
@inline _promote_wol(t, tail...) = length(tail) == 1 ? t : promote_type(t, _promote_wol(tail...))

_promote_args_type(::Type{AbstractFloat}, ::Type{Tdef}, ::Type{T}) where {Tdef,T<:AbstractFloat} = T
_promote_args_type(::Type{AbstractFloat}, ::Type{Tdef}, ::Type{T}) where {Tdef,T<:Real} = Tdef
_promote_args_type(::Type{Fractional}, ::Type{Tdef}, ::Type{T}) where {Tdef,T<:Fractional} = T
_promote_args_type(::Type{Fractional}, ::Type{Tdef}, ::Type{T}) where {Tdef,T<:Real} = Tdef
_promote_args_type(::Type, ::Type{Tdef}, ::Type{T}) where {Tdef,T} = promote_type(Tdef, T)

function (::Type{C})() where {C<:AbstractCMYK}
    d0 = zero(eltype_default(C))
    _new_colorant(C, d0, d0, d0, d0)
end
function (::Type{C})() where {C<:TransparentCMYK}
    d0 = zero(eltype_default(C))
    _new_colorant(C, d0, d0, d0, d0, oneunit(eltype_default(C)))
end

(::Type{C})(x) where {C<:AbstractCMYK} = _new_colorant(C, x)
(::Type{C})(x, y, z, w) where {C<:AbstractCMYK} = _new_colorant(C, x, y, z, w)

(::Type{C})(x) where {C<:TransparentCMYK} = _new_colorant(C, x)
(::Type{C})(x, alpha) where {C<:TransparentCMYK} = _new_colorant(C, x, alpha)
(::Type{C})(x, y, z, w, alpha=1) where {C<:TransparentCMYK} = _new_colorant(C, x, y, z, w, alpha)

function _new_colorant(::Type{C}, args::Vararg{Any,N}) where {N,C<:ColorantN{N}}
    rargs = real.(args)
    base_colorant_type(C){promote_args_type(C, rargs...)}(rargs...)
end

function _new_colorant(::Type{C}, c::Colorant) where {N,C<:ColorantN{N}}
    convert(C, c)
end

function _new_colorant(::Type{C}, c::Colorant, alpha) where {N,C<:TransparentColorN{N}}
    convert(C, color(c), alpha)
end

# T might be a Normed, and so some inputs will result in an error.
# Try to make it a nice error.
function _new_colorant(::Type{C}, args::Vararg{GrayLike,N}) where {N,T,C<:AbstractCMYK{T}}
    r = real.(args)
    checkval(C, r...)
    C(_rem.(r, T)...)
end
function _new_colorant(::Type{TC}, args::Vararg{GrayLike,N}) where {N,T,C,TC<:TransparentCMYK{C,T}}
    r = real.(args)
    checkval(TC, r...)
    TC(_rem.(r, T)...)
end

_rem(x, ::Type{T}) where {T<:Normed} = x % T
_rem(x, ::Type{T}) where {T} = convert(T, x)
