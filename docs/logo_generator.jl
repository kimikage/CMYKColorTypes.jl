module LogoGenerator

const JULIA_DOTS_DIST = 8.0 # resolution
const JULIA_DOTS_R = JULIA_DOTS_DIST * 0.75

function clamp_r(x)
    d = x / JULIA_DOTS_R - 1.0
    clamp(-6.0 * d + 0.9, 0.0, 1.4)
end

function simplify(x)
    r = round(x, digits=2)
    string(isinteger(r) ? Int(r) : r)
end

function dist(col::Val, angle, x, y)
    p = col isa Val{:green} ? -90.0 : col isa Val{:red} ? 150.0 : 30.0
    cx = JULIA_DOTS_DIST * cosd(p - angle)
    cy = JULIA_DOTS_DIST * sind(p - angle)
    sqrt((x - cx)^2 + (y - cy)^2)
end

function write_screen(io, color, angle, ig, ir, ip)
    println(io, """
        <g transform="rotate($angle)" fill="$color"
           style="mix-blend-mode: multiply; opacity: 0.9;">""")
    area = round(Int, JULIA_DOTS_DIST) * 2
    for y = -area:2:area, x = -area:2:area
        r_green  = ig * clamp_r(dist(Val(:green),  angle, x, y))
        r_red    = ir * clamp_r(dist(Val(:red),    angle, x, y))
        r_purple = ip * clamp_r(dist(Val(:purple), angle, x, y))
        r = max(r_green, r_red, r_purple)
        r < 0.25 && continue
        rs = simplify(r)
        println(io, """<circle cx="$x" cy="$y" r="$rs"/>""")
    end
    println(io, """</g>""")
end

function write_svg(io)
    ox = simplify(JULIA_DOTS_DIST * -2.0)
    oy = simplify(JULIA_DOTS_DIST * -2.2)
    wh = simplify(JULIA_DOTS_DIST * 4.0)
    println(io, """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <svg xmlns="http://www.w3.org/2000/svg" version="1.1" style="isolation: isolate;"
             viewBox="$ox $oy $wh $wh" height="500pt" width="500pt">""")
    write_screen(io, "#ffed00",  0.0, 0.83, 0.70, 0.00)
    write_screen(io, "#e6007d", 75.0, 0.26, 0.76, 0.65)
    write_screen(io, "#009fe3", 15.0, 0.82, 0.29, 0.52)
    println(io, "</svg>")
end

end # module
