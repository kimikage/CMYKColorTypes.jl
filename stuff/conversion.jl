#=
# Default conversions

The default conversion mimics the conversion between sRGB and eciCMYK (FOGRA53)
with the relative colorimetric rendering intent.

You can download "eciCMYK.icc" from the European Color Initiative (ECI) website:
http://www.eci.org/doku.php?id=en:downloads

As many CMYK exchange color space profiles do, "eciCMYK.icc" uses PCSLAB as the
profile connection space. However, while sRGB uses the D65 white point, PCSLAB
uses the D50 white point. Also, the exponential functions required to convert
between sRGB and Lab are expensive.

Hence, we first define a color space analogous to Luv as the PCS here. In this
Luv space, L corresponds to the grayscale of sRGB, and the u-v coordinates
correspond to the CMY components of eciCMYK.

Also, this implementation uses a polynomial approximation instead of lookup
tables.
=#

using Pkg
Pkg.develop("CMYKColorTypes")
using CMYKColorTypes

using Colors
using FixedPointNumbers
using StaticArrays
using Interpolations
using JuMP
using Ipopt # I am not sure which solver is the most suitable.

profile = IOBuffer()
write(profile, read(joinpath(@__DIR__, "eciCMYK.icc")))

read_u8(io) = read(io, UInt8)
read_u16(io) = ntoh(read(io, UInt16))
read_u32(io) = ntoh(read(io, UInt32))

clampq16(x) = clamp(Float32(x), 0.0f0, Float32(0xffffp-16))

function get_pos(io, sig)
    seek(io, 128)
    n = ntoh(read(io, UInt32))
    for i = 1:n
        sigbytes = read(io, 4)
        offset = read_u32(io)
        size = read_u32(io)
        sigbytes == sig && return offset, size
    end
    error("tag not found")
end

function read_lut16(io, sig)
    offset, size = get_pos(io, sig)
    seek(io, offset)
    read(io, 4) == b"mft2" || error("lut16Type is expected")
    read_u32(io) # reserved
    Ni, No, Ng = Int(read_u8(io)), Int(read_u8(io)), Int(read_u8(io))
    read_u8(io) # reserved
    mat = [read_u32(io) for i = 1:3, j = 1:3]
    mat == [0x10000 * (i == j) for i = 1:3, j = 1:3] || error("identity matrix is expected")
    n = Int(read_u16(io))
    m = Int(read_u16(io))
    input_curves = ntuple(_ -> Vector{Float32}(undef, n), Ni)
    output_curves = ntuple(_ -> Vector{Float32}(undef, m), No)
    clut = Array{SVector{No, Float32}}(undef, ntuple(_ -> Ng, Ni))
    clutp = PermutedDimsArray(clut, Ni:-1:1)
    for t in input_curves, i = 1:n
        @inbounds t[i] = read_u16(io) * Float32(0x1p-16)
    end
    for I in CartesianIndices(clutp)
        @inbounds clutp[I] = SVector(ntuple(_ -> read_u16(io) * Float32(0x1p-16), No))
    end
    for t in output_curves, i = 1:m
        @inbounds t[i] = read_u16(io) * Float32(0x1p-16)
    end
    range_n = range(0.0f0, clampq16(1), length=n)
    range_m = range(0.0f0, clampq16(1), length=m)
    range_g = range(0.0f0, clampq16(1), length=Ng)
    itp_input  = map(curve -> LinearInterpolation(range_n, curve), input_curves)
    itp_output = map(curve -> LinearInterpolation(range_m, curve), output_curves)
    itp_clut = CubicSplineInterpolation(ntuple(_ -> range_g, Ni), clut)
    return (itp_input, itp_clut, itp_output)
end

const A2B1 = read_lut16(profile, b"A2B1")
const B2A1 = read_lut16(profile, b"B2A1")

function pcslab_to_cmyk(c::Lab)
    lab = clampq16.((c.l / 100 * clampq16(1),
                     (c.a + 128) * 0x101p-16,
                     (c.b + 128) * 0x101p-16))
    lab01 = map(((f, v),) -> f(v), zip(B2A1[1], lab))
    cmyk01 = clampq16.(B2A1[2]((clampq16.(lab01))...))
    CMYK{Float32}(map(((f, v),) -> f(v) / clampq16(1), zip(B2A1[3], cmyk01))...)
end

function cmyk_to_pcslab(c::CMYK)
    cmyk = clampq16.((c.c, c.m, c.y, c.k) .* clampq16(1))
    cmyk01 = map(((f, v),) -> f(v), zip(A2B1[1], cmyk))
    lab01 = clampq16.(A2B1[2]((clampq16.(cmyk01))...))
    lab = map(((f, v),) -> f(v), zip(A2B1[3], lab01))
    Lab{Float32}(lab[1] * 100 / clampq16(1),
                 lab[2] / 0x101p-16 - 128,
                 lab[3] / 0x101p-16 - 128)
end

cmyk_to_srgb(c::CMYK) = pcslab_to_srgb(cmyk_to_pcslab(c))
srgb_to_cmyk(c::RGB)  = pcslab_to_cmyk(srgb_to_pcslab(c))

# Since the LUT of GamutTag has low resolution, a method based on round-tripness
# is used here.
function ingamut(c::Lab)
    c2 = cmyk_to_pcslab(pcslab_to_cmyk(c))
    colordiff(c, c2) < 0.75
end

function ingamut(c::RGB)
    c2 = cmyk_to_srgb(srgb_to_cmyk(c))
    colordiff(c, c2) < 0.75
end

include(joinpath(@__DIR__, "..", "test", "samples.jl"))


# Step 1: sRGB --> MyLuv.l

function fit_srgb_to_l(N)
    range01 = range(1 / N, 1.0, length=N)
    rgbs = [Iterators.product(range01, range01, range01)...]
    ls = map(t -> srgb_to_pcslab(RGB(t...)).l / 100, rgbs)
    n = length(ls)

    model = Model(with_optimizer(Ipopt.Optimizer))
    set_optimizer_attribute(model, "print_level", 1)

    @variable(model, kr, start=0.25)
    @variable(model, kg, start=0.65)
    @variable(model, _ls[1:n])

    @constraint(model, [i = 1:n],
        _ls[i] == kr * rgbs[i][1] + kg * rgbs[i][2] + (1 - kr - kg) * rgbs[i][3])

    @objective(model, Min, sum((ls[i] - _ls[i])^2 for i in 1:n))

    optimize!(model)
    println("Step 1: sRGB --> MyLuv.l")
    println("    objective: ", sqrt(objective_value(model) / n))
    kr_ = value(kr)
    kg_ = value(kg)
    kb_ = 1.0 - kr_ - kg_
    println("    $kr_ * r + $kg_ * g + $kb_ * b")
    return kr_, kg_, kb_
end

const kr, kg, kb = fit_srgb_to_l(50)

srgb_to_l(c::RGB) = Float32(kr * c.r + kg * c.g + kb * c.b)


# Step 2: CMYK --> MyLuv.l

function fit_cmyk_to_l(N)
    count = 0
    dks = Vector{Float32}(undef, N)
    cmyks = Vector{SVector{4, Float32}}(undef, N)
    while count < N
        c = rand(Float32)
        m = rand(Float32)
        y = rand(Float32)
        k = min(3.5f0 - c - m - y, rand(Float32))
        cmyk = CMYK(c, m, y, k)
        lab = cmyk_to_pcslab(cmyk)
        srgb = pcslab_to_srgb(lab)
        l = srgb_to_l(srgb)
        l > 0.1 || continue
        lab2 = srgb_to_pcslab(srgb)
        colordiff(lab, lab2) < 0.75 || continue
        count += 1
        cmyks[count] = (c, m, y, k)
        dks[count] = 1.0f0 - l
    end

    dks4 = ntuple(_ -> Float32[], 4)
    cmyks4 = ntuple(_ -> SVector{4, Float32}[], 4)
    for (i, cmyk) in enumerate(cmyks)
        x = maximum(cmyk)
        for j = 1:4
            x == cmyk[j] || continue
            push!(dks4[j], dks[i])
            push!(cmyks4[j], cmyk)
        end
    end
    n = minimum(length, dks4)

    model = Model(with_optimizer(Ipopt.Optimizer))
    set_optimizer_attribute(model, "max_cpu_time", 60.0)
    set_optimizer_attribute(model, "print_level", 1)

    @variable(model, g2_4[1:4], start=-0.5)
    @variable(model, g1_4[1:4], start=1.5)
    @constraint(model, g1_4[1] + g2_4[1] == 1.0)

    @variable(model, kcmyk4[1:4, 1:4], start=0.25)
    @variable(model, _dks4[1:4, 1:n], start=0.25)

    @expression(model, dk4[j = 1:4, i = 1:n], begin
            cmykx = g2_4[j] .* cmyks4[j][i].^2 .+ g1_4[j] .* cmyks4[j][i]
            sum(cmykx .* kcmyk4[j, :])
        end)
    @constraint(model, [j = 1:4, i = 1:n], _dks4[j, i] == dk4[j, i])


    @objective(model, Min,
        sum((_dks4[j, i] - dks4[j][i])^2 for j in 1:4, i in 1:n))

    optimize!(model)

    println("Step 2: CMYK --> MyLuv.l")
    println("    objective value: ", sqrt(objective_value(model) / 4 / n))
    println("    g2_4 = ", value.(g2_4))
    println("    g1_4 = ", value.(g1_4))
    println("    kcmyk4 = ", value.(kcmyk4))
    return value.(g2_4), value.(g1_4), value.(kcmyk4)
end

g2_4, g1_4, kcmyk4 = fit_cmyk_to_l(10000)

# Step 3: CMY hue angles
#=
For color management in printed materials, the D50 is generally adopted as the
light source. For this reason, when cyan, magenta, and yellow inks are mixed
equally, the color will be a slightly "reddish" gray from the view point of
sRGB with the D65 white point.
Here, to make the centroid more "bluish", we tweak the hue angles.
=#
function fit_hue_angles()
    grays = 64:255
    N = length(grays)
    cs = srgb_to_cmyk.(RGB.(grays ./ 255.0f0))

    model = Model(with_optimizer(Ipopt.Optimizer))
    set_optimizer_attribute(model, "max_cpu_time", 60.0)
    set_optimizer_attribute(model, "print_level", 1)

    @variable(model, 0.0 <= coshm <= 1.0, start=cosd(-60.0))
    @variable(model, 0.0 <= coshy <= 1.0, start=cosd(60.0))
    @variable(model, -1.0 <= sinhm <= 0.0)
    @variable(model,  0.0 <= sinhy <= 1.0)
    @variable(model, us[1:N])
    @variable(model, vs[1:N])

    @constraint(model, coshm^2 + sinhm^2 == 1.0)
    @constraint(model, coshy^2 + sinhy^2 == 1.0)
    @constraint(model, [i = 1:N], us[i] == coshm * cs[i].m + coshy * cs[i].y - cs[i].c)
    @constraint(model, [i = 1:N], vs[i] == sinhm * cs[i].m + sinhy * cs[i].y)

    @objective(model, Min, sum(us[i]^2 + vs[i]^2 for i in 1:N))

    optimize!(model)

    println("Step 3: CMY hue angles")
    println("    objective value: ", sqrt(objective_value(model) / N))
    hm = atand(value(sinhm), value(coshm))
    hy = atand(value(sinhy), value(coshy))
    println("    hm[deg]: ", hm)
    println("    hy[deg]: ", hy)
    return hm, hy
end
const hm, hy = fit_hue_angles()

# Step 4: MyLuv --> sRGB

# Step X: Output

open(joinpath(@__DIR__, "out.jl"), "w+") do f
    k4 = kcmyk4
    pf32(v) = rpad(string(Float32(v)), 10, '0') * "f0"

    write(f,
        """
        function cmyk_to_luv(cmyk::AbstractCMYK)
            c = Float32(cyan(cmyk))
            m = Float32(magenta(cmyk))
            y = Float32(yellow(cmyk))
            k = Float32(black(cmyk))
            cx = muladd($(pf32(g2_4[1])), c, $(pf32(g1_4[1]))) * c
            mx = muladd($(pf32(g2_4[2])), m, $(pf32(g1_4[2]))) * m
            yx = muladd($(pf32(g2_4[3])), y, $(pf32(g1_4[3]))) * y
            kx = muladd($(pf32(g2_4[4])), k, $(pf32(g1_4[4]))) * k
            @fastmath x = max(max(cx, mx), max(yx, kx))
            t = x === cx ? ($(pf32(k4[1,1])), $(pf32(k4[1,2])), $(pf32(k4[1,3])), $(pf32(k4[1,4]))) :
                x === mx ? ($(pf32(k4[2,1])), $(pf32(k4[2,2])), $(pf32(k4[2,3])), $(pf32(k4[2,4]))) :
                x === yx ? ($(pf32(k4[3,1])), $(pf32(k4[3,2])), $(pf32(k4[3,3])), $(pf32(k4[3,4]))) :
                           ($(pf32(k4[4,1])), $(pf32(k4[4,2])), $(pf32(k4[4,3])), $(pf32(k4[4,4])))
            l = 1.0f0 - sum((cx, mx, yx, kx) .* t)
            u = cosd($(pf32(hm))) * m + cosd($(pf32(hy))) * y - c
            v = sind($(pf32(hm))) * m + sind($(pf32(hy))) * y
            return l, u, v
        end
        """)
    println(f)

end