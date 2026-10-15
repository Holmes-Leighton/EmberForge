-- A rail route through the hub: a few control points {x, y, z} become a smooth, densely sampled line measured in studs, so a position on the route
-- is just a distance `s` from its start. Pure maths (no Roblox types), shared by the server (the cart's real position) and clients (smooth drawing).
local CartPath = {}

local STEP = 4          -- studs between samples

local function CatmullRom(a, b, c, d, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
end

-- controls: array of { x, y, z }. minY (optional) keeps the smoothed line from dipping below the road where a hill starts.
-- Returns { pts = { {x,y,z}... }, s = { cumulative distance per point }, length }
function CartPath.Build(controls, minY)
    local pts = {}
    local n = #controls
    for i = 1, n - 1 do
        local p0, p1, p2, p3 = controls[math.max(i - 1, 1)], controls[i], controls[i + 1], controls[math.min(i + 2, n)]
        local dx, dy, dz = p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]
        local count = math.max(2, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / STEP))
        for k = 0, count - 1 do
            local t = k / count
            table.insert(pts, {
                CatmullRom(p0[1], p1[1], p2[1], p3[1], t),
                CatmullRom(p0[2], p1[2], p2[2], p3[2], t),
                CatmullRom(p0[3], p1[3], p2[3], p3[3], t),
            })
        end
    end
    local last = controls[n]
    table.insert(pts, { last[1], last[2], last[3] })
    if minY then
        for _, p in ipairs(pts) do if p[2] < minY then p[2] = minY end end
    end

    local s, total = { 0 }, 0
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
        total += math.sqrt(dx * dx + dy * dy + dz * dz)
        s[i] = total
    end
    return { pts = pts, s = s, length = total }
end

-- Position, unit tangent (direction of travel) and the slope (the tangent's rise: + uphill, - downhill) at distance s along the path
function CartPath.At(path, s)
    local S, pts = path.s, path.pts
    s = math.clamp(s, 0, path.length)
    local lo, hi = 1, #pts - 1
    while lo < hi do                                   -- last segment that starts at or before s
        local mid = math.ceil((lo + hi) / 2)
        if S[mid] <= s then lo = mid else hi = mid - 1 end
    end
    local a, b = pts[lo], pts[lo + 1]
    local seg = S[lo + 1] - S[lo]
    local f = seg > 0 and (s - S[lo]) / seg or 0
    local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len == 0 then dx, dy, dz, len = 1, 0, 0, 1 end
    local tx, ty, tz = dx / len, dy / len, dz / len
    return a[1] + dx * f, a[2] + dy * f, a[3] + dz * f, tx, ty, tz
end

-- The cart's orientation at distance s: its position, forward (the tangent) and a matching up vector (level, tilted only by the slope). Returns x, y, z, fx, fy, fz, ux, uy, uz.
function CartPath.Frame(path, s)
    local x, y, z, fx, fy, fz = CartPath.At(path, s)
    local d = fy                                   -- remove the part of "straight up" that lies along forward
    local ux, uy, uz = -fx * d, 1 - fy * d, -fz * d
    local len = math.sqrt(ux * ux + uy * uy + uz * uz)
    return x, y, z, fx, fy, fz, ux / len, uy / len, uz / len
end

-- How sharply the route turns at distance s: 1 / radius (studs), measured over 14 studs of flat heading change. 0 on a straight.
function CartPath.Curvature(path, s)
    local a0, a1 = math.max(0, s - 7), math.min(path.length, s + 7)
    local _, _, _, ax, _, az = CartPath.At(path, a0)
    local _, _, _, bx, _, bz = CartPath.At(path, a1)
    local la, lb = math.sqrt(ax * ax + az * az), math.sqrt(bx * bx + bz * bz)
    if la < 1e-4 or lb < 1e-4 or a1 <= a0 then return 0 end
    local ang = math.acos(math.clamp((ax * bx + az * bz) / (la * lb), -1, 1))
    return ang / (a1 - a0)
end

-- The tightest bend on the route: its radius in studs (math.huge on a straight route) and the distance where it is
function CartPath.MinRadius(path)
    local worst, at = 0, 0
    for s = 0, path.length, 2 do
        local k = CartPath.Curvature(path, s)
        if k > worst then worst, at = k, s end
    end
    return worst > 1e-6 and 1 / worst or math.huge, at
end

-- Points every `spacing` studs (for building art along the route): { { s, x, y, z, tx, ty, tz }... }
function CartPath.Samples(path, spacing)
    local out = {}
    local count = math.max(1, math.ceil(path.length / spacing))
    for i = 0, count do
        local s = math.min(path.length, i * path.length / count)
        local x, y, z, tx, ty, tz = CartPath.At(path, s)
        out[#out + 1] = { s = s, x = x, y = y, z = z, tx = tx, ty = ty, tz = tz }
    end
    return out
end

return CartPath
