-- A rail route through the hub: a few control points {x, y, z} become a smooth, densely sampled line measured in studs, so a position on the route
-- is just a distance `s` from its start. Pure maths (no Roblox types), shared by the server (the cart's real position) and clients (smooth drawing).
local CartPath = {}

CartPath.MIN_RADIUS = 7        -- studs: the tightest bend the road is drawn with
local STEP = 1          -- studs between samples (fine, so the tightest bends are round and not a few sharp corners)

local function CatmullRom(a, b, c, d, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
end

-- Pulls the sharpest bends open: no point of the route (seen from three points 3 studs apart, flat) is allowed a radius smaller than minRadius. The ends stay put.
-- (A road 16 studs wide and a cart 9 long cannot turn in 3 studs: the control points of the harder courses had a few sharp kinks.)
-- The same polyline with points an even `step` apart along it (the first and last stay exactly where they were)
local function Resample(pts, step)
    local out = { { pts[1][1], pts[1][2], pts[1][3] } }
    local carry = 0
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
        local at = step - carry
        while at <= len do
            local f = len > 0 and at / len or 0
            out[#out + 1] = { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }
            at += step
        end
        carry = len - (at - step)
    end
    local last, tail = pts[#pts], out[#out]
    if math.sqrt((last[1] - tail[1]) ^ 2 + (last[3] - tail[3]) ^ 2) > 0.05 then out[#out + 1] = { last[1], last[2], last[3] } else out[#out] = { last[1], last[2], last[3] } end
    return out
end

local function Relax(pts, minRadius, step)
    local W = 5                                                 -- neighbours smoothed along with a sharp vertex
    for _ = 1, 120 do
        local bad, any = {}, false
        for i = 2, #pts - 1 do
            local a, b, c = pts[i - 1], pts[i], pts[i + 1]
            local ax, az, bx, bz = b[1] - a[1], b[3] - a[3], c[1] - b[1], c[3] - b[3]
            local la, lb = math.sqrt(ax * ax + az * az), math.sqrt(bx * bx + bz * bz)
            if la > 1e-4 and lb > 1e-4 then
                local turn = math.acos(math.clamp((ax * bx + az * bz) / (la * lb), -1, 1))
                if turn > 1e-4 and (la + lb) / 2 / turn < minRadius then
                    any = true
                    for j = math.max(2, i - W), math.min(#pts - 1, i + W) do bad[j] = true end
                end
            end
        end
        if not any then break end
        local new = {}
        for i = 1, #pts do new[i] = { pts[i][1], pts[i][2], pts[i][3] } end
        for i = 2, #pts - 1 do
            if bad[i] then
                new[i][1] = 0.25 * pts[i - 1][1] + 0.5 * pts[i][1] + 0.25 * pts[i + 1][1]
                new[i][3] = 0.25 * pts[i - 1][3] + 0.5 * pts[i][3] + 0.25 * pts[i + 1][3]
            end
        end
        pts = Resample(new, step)                               -- (and spread the points evenly again, so "a vertex" is always about one step wide)
    end
    return pts
end

-- controls: array of { x, y, z }. minY (optional) keeps the smoothed line from dipping below the road where a hill starts.
-- Returns { pts = { {x,y,z}... }, s = { cumulative distance per point }, length }
function CartPath.Build(controls, minY, minRadius)
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
    pts = Relax(Resample(pts, STEP), minRadius or CartPath.MIN_RADIUS, STEP)
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

-- Points along the route with a step that shrinks where the route bends: the heading changes by no more than about maxTurn (radians) between neighbours, as long as that
-- does not need a step shorter than minStep; on a straight the step is maxStep. Each is { s, x, y, z, tx, ty, tz }, like Samples.
function CartPath.AdaptiveSamples(path, maxStep, minStep, maxTurn)
    local out = {}
    local function add(s)
        local x, y, z, tx, ty, tz = CartPath.At(path, s)
        out[#out + 1] = { s = s, x = x, y = y, z = z, tx = tx, ty = ty, tz = tz }
    end
    local function turnBetween(s0, s1)
        local _, _, _, ax, _, az = CartPath.At(path, s0)
        local _, _, _, bx, _, bz = CartPath.At(path, s1)
        local la, lb = math.sqrt(ax * ax + az * az), math.sqrt(bx * bx + bz * bz)
        if la < 1e-4 or lb < 1e-4 then return 0 end
        return math.acos(math.clamp((ax * bx + az * bz) / (la * lb), -1, 1))
    end
    local s = 0
    add(0)
    while s < path.length - 1e-6 do
        local step = maxStep
        while step > minStep and turnBetween(s, math.min(path.length, s + step)) > maxTurn do step = math.max(minStep, step * 0.75) end
        s = math.min(path.length, s + step)
        add(s)
    end
    return out
end

return CartPath
