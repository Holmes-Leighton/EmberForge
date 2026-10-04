-- Turns a Courier Run course (a list of obstacle modules, see CourierData) into concrete geometry: the platforms, the moving and crumbling pieces, the spinners and crushers,
-- the checkpoints and the finish. Pure maths with no Roblox types, so tests can check that every jump in every course can really be made.
-- The course runs east (+X) from `base`. A "cursor" remembers where the last platform ended; each module adds platforms after it.
--   platforms  { x, y, z, sx, sy, sz }   solid boxes (centre and size)
--   movers     { x0, x1, y, z, sx, sy, sz, period, phase }   a platform sliding between two X positions (sine-eased)
--   crumbles   { x, y, z, sx, sy, sz, delay, respawn }       a platform that drops away after being stood on
--   spinners   { x, y(top of the platform), z, radius, barY, thick, omega, phase }   a bar sweeping round, to jump over
--   crushers   { x, y(top of the platform), z, sx, sz, height, open, closed, phase }   a block that slams down on a timer
--   checkpoints{ x, y, z }   places to respawn (the first is the start)
--   finish     { x, y, z, hx, hz }  the drop-off zone
local CourierLayout = {}

local THICK = 2
CourierLayout.THICK = THICK

local function Plat(L, x0, len, top, z, width, extra)
    local p = { x = x0 + len / 2, y = top - THICK / 2, z = z, sx = len, sy = THICK, sz = width, kind = "platform" }
    if extra then for k, v in pairs(extra) do p[k] = v end end
    table.insert(L.platforms, p)
    return p
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Each module takes the layout L, the cursor { x = far edge of the last platform, y = its top, z = its centre } and its params, and moves the cursor on.
local Modules = {}

-- A wide safe platform with a checkpoint in the middle
function Modules.rest(L, cur, p)
    local x0 = cur.x + (p.gap or 0)
    Plat(L, x0, p.len or 26, cur.y, cur.z, p.width or 26)
    table.insert(L.checkpoints, { x = x0 + (p.len or 26) / 2, y = cur.y + 3, z = cur.z })
    cur.x = x0 + (p.len or 26)
end

-- A row of small platforms with gaps between them
function Modules.steps(L, cur, p)
    for i = 1, p.n do
        local x0 = cur.x + p.gap
        cur.y += (p.rises and p.rises[(i - 1) % #p.rises + 1]) or 0
        cur.z = Clamp(cur.z + ((p.zigs and p.zigs[(i - 1) % #p.zigs + 1]) or 0), L.base.z - L.zRange, L.base.z + L.zRange)
        Plat(L, x0, p.len, cur.y, cur.z, p.width)
        cur.x = x0 + p.len
    end
end

-- Ledges that climb: each one higher than the last
function Modules.climb(L, cur, p)
    for i = 1, p.n do
        local x0 = cur.x + p.gap
        cur.y += p.rise
        cur.z = Clamp(cur.z + ((p.zigs and p.zigs[(i - 1) % #p.zigs + 1]) or 0), L.base.z - L.zRange, L.base.z + L.zRange)
        Plat(L, x0, p.len, cur.y, cur.z, p.width)
        cur.x = x0 + p.len
    end
end

-- A gap crossed on a platform that slides back and forth between the two sides, then a landing platform
function Modules.mover(L, cur, p)
    local a, b = cur.x + 2 + p.len / 2, cur.x + p.span - 2 - p.len / 2
    table.insert(L.movers, { x0 = a, x1 = b, y = cur.y - THICK / 2, z = cur.z, sx = p.len, sy = THICK, sz = p.width, period = p.period, phase = p.phase or 0 })
    local x0 = cur.x + p.span
    Plat(L, x0, p.landing or 10, cur.y, cur.z, p.landingWidth or p.width)
    cur.x = x0 + (p.landing or 10)
end

-- Platforms that fall away shortly after you land on them
function Modules.crumble(L, cur, p)
    for i = 1, p.n do
        local x0 = cur.x + p.gap
        local plat = { x = x0 + p.len / 2, y = cur.y - THICK / 2, z = cur.z, sx = p.len, sy = THICK, sz = p.width, delay = p.delay or 0.6, respawn = p.respawn or 3 }
        table.insert(L.crumbles, plat)
        cur.x = x0 + p.len
    end
end

-- A long platform with a bar sweeping round its middle: jump it
function Modules.spinner(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width)
    table.insert(L.spinners, { x = x0 + p.len / 2, y = cur.y, z = cur.z, radius = p.radius, barY = 1.4, thick = 1.4, omega = p.omega, phase = p.phase or 0 })
    cur.x = x0 + p.len
end

-- A corridor with blocks that slam down in turn: time your dash
function Modules.crusher(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width)
    for i = 1, p.n do
        local cx = x0 + (p.len / (p.n + 1)) * i
        table.insert(L.crushers, { x = cx, y = cur.y, z = cur.z, sx = p.zone or 6, sz = p.width, height = 12, open = p.open, closed = p.closed, phase = (p.phase or 0) + (i - 1) * (p.stagger or 1.5) })
    end
    cur.x = x0 + p.len
end

-- A thin beam to walk along
function Modules.beam(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width)
    cur.x = x0 + p.len
end

-- The drop-off: a wide platform with the finish zone on it
function Modules.finish(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    local len = p.len or 30
    Plat(L, x0, len, cur.y, cur.z, p.width or 28)
    L.finish = { x = x0 + len / 2, y = cur.y + 3, z = cur.z, hx = len / 2 - 3, hz = (p.width or 28) / 2 }
    cur.x = x0 + len
end

-- course: { base = { x, y, z }, modules = { { "rest", { ... } }, ... }, zRange }. Returns the layout.
function CourierLayout.Build(course)
    local L = {
        base = course.base, zRange = course.zRange or 14,
        platforms = {}, movers = {}, crumbles = {}, spinners = {}, crushers = {}, checkpoints = {},
    }
    local cur = { x = course.base.x, y = course.base.y, z = course.base.z }
    for _, m in ipairs(course.modules) do
        local fn = Modules[m[1]]
        assert(fn, "unknown Courier module " .. tostring(m[1]))
        fn(L, cur, m[2] or {})
    end
    L.endX = cur.x
    L.length = cur.x - course.base.x
    L.start = L.checkpoints[1]
    -- the lowest point anything stands at: falling well below the last checkpoint costs a respawn
    local top = math.huge
    for _, p in ipairs(L.platforms) do top = math.min(top, p.y + p.sy / 2) end
    L.lowestTop = top
    return L
end

-- ── Checks used by the tests (and handy for tuning) ──────────────────────────
-- How far a default Roblox character can jump (walking speed 16, jump height 7.2): air time about 0.54 s, so ~8.6 studs flat; a safe gap is a good bit less
CourierLayout.JUMP_REACH_FLAT = 8.6
CourierLayout.JUMP_HEIGHT     = 7.2

-- The solid pieces a player walks on, in course order (platforms, crumbles and the extremes of movers), as { x1, x2, y(top), z, w }
function CourierLayout.WalkOrder(L)
    local out = {}
    local function add(x1, x2, top, z, w, kind) table.insert(out, { x1 = x1, x2 = x2, top = top, z = z, w = w, kind = kind }) end
    for _, p in ipairs(L.platforms) do add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "platform") end
    for _, p in ipairs(L.crumbles) do add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "crumble") end
    for _, m in ipairs(L.movers) do
        add(m.x0 - m.sx / 2, m.x0 + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover")
        add(m.x1 - m.sx / 2, m.x1 + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover")
    end
    table.sort(out, function(a, b) return a.x1 < b.x1 end)
    return out
end

return CourierLayout
