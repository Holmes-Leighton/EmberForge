-- Turns a Courier Run course (a list of obstacle modules, see CourierData) into concrete geometry: the platforms, the moving and crumbling pieces, the spinners and crushers,
-- the checkpoints and the finish. Pure maths with no Roblox types, so tests can check that every jump in every course can really be made.
-- The course runs east (+X) from `base`. A "cursor" remembers where the last platform ended; each module adds platforms after it.
--   platforms  { x, y, z, sx, sy, sz }   solid boxes (centre and size)
--   movers     { x0, x1, y, z, sx, sy, sz, period, phase }   a platform sliding between two X positions (sine-eased)
--   crumbles   { x, y, z, sx, sy, sz, delay, respawn }       a platform that drops away after being stood on
--   spinners   { x, y(top of the platform), z, radius, barY, thick, omega, phase }   a bar sweeping round, to jump over
--   crushers   { x, y(top of the platform), z, sx, sz, height, open, closed, phase }   a block that slams down on a timer
--   kills      { x, y(top of the floor), z, sx, sz }   a deadly red tile on a floor
--   grids      { x1, x2, top, z, w }   a floor made of falling tiles (its tiles are in `crumbles` with grid = true), for the walk-order tests
--   trusses    { x, y(foot), z, height }   a ladder you climb
--   bounces    { x, y(top of the pad), z, sx, sz, power, hspeed, rise }   a pad that throws you up (Y speed `power`) and forward (`hspeed` along the course)
--   sweepers   { x, y(top of the platform), z, amp, period, phase, thick }   a bar sliding across Z
--   (platforms may also carry conveyor = speed, ice = true, viaTruss / viaBounce = true on the landing of a ladder or bounce)
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
    local bars = p.bars or 1                                     -- 1 bar, 2 (a cross), 3 (a six-armed star): the bars share a hub and turn together
    for b = 0, bars - 1 do
        table.insert(L.spinners, { x = x0 + p.len / 2, y = cur.y, z = cur.z, radius = p.radius, barY = 1.4, thick = 1.4, omega = p.omega, phase = (p.phase or 0) + b * math.pi / bars })
    end
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
    Plat(L, x0, p.len, cur.y, cur.z, p.width, p.pipe and { pipe = true } or nil)             -- (pipe = true: drawn as a round steel pipe you balance on)
    cur.x = x0 + p.len
end

-- A floor with deadly tiles. `pattern` is a list of rows (across the course) of characters, one per tile along the course: "." safe, "X" a red tile that sends you back to the start
-- of the level. Hand-designed; the tests check a safe route always exists.
function Modules.killfloor(L, cur, p)
    local rows, cols = #p.pattern, #p.pattern[1]
    local tile = p.tile or 5.4
    local x0 = cur.x + (p.gap or 3)
    local len, width = cols * tile, rows * tile
    Plat(L, x0, len, cur.y, cur.z, width, { killfloor = true })
    for r = 1, rows do
        for c = 1, cols do
            if p.pattern[r]:sub(c, c) == "X" then
                table.insert(L.kills, { x = x0 + (c - 0.5) * tile, y = cur.y, z = cur.z + ((r - 0.5) - rows / 2) * tile, sx = tile - 0.3, sz = tile - 0.3 })
            end
        end
    end
    cur.x = x0 + len
end

-- A floor of tiles that each drop away shortly after you touch them. `pattern` rows as above: "." a tile, "o" a hole (no tile). Delays vary tile to tile.
function Modules.tilefall(L, cur, p)
    local rows, cols = #p.pattern, #p.pattern[1]
    local tile = p.tile or 5.4
    local x0 = cur.x + (p.gap or 3)
    local len, width = cols * tile, rows * tile
    for r = 1, rows do
        for c = 1, cols do
            if p.pattern[r]:sub(c, c) ~= "o" then
                table.insert(L.crumbles, { x = x0 + (c - 0.5) * tile, y = cur.y - THICK / 2, z = cur.z + ((r - 0.5) - rows / 2) * tile, sx = tile - 0.4, sy = THICK, sz = tile - 0.4,
                    delay = (p.delay or 0.5) + ((r * 3 + c * 5) % 4) * 0.12, respawn = p.respawn or 3.5, grid = true })
            end
        end
    end
    table.insert(L.grids, { x1 = x0, x2 = x0 + len, top = cur.y, z = cur.z, w = width })
    cur.x = x0 + len
end

-- A vertical ladder (a truss you climb) from the platform you are on up to a small landing: `height` studs higher. Real climbing, so it can rise far more than a jump.
function Modules.ladder(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    local foot = Plat(L, x0, p.footLen or 8, cur.y, cur.z, p.width or 10)                -- somewhere to stand at the bottom
    table.insert(L.trusses, { x = x0 + (p.footLen or 8) + 1, y = cur.y, z = cur.z, height = p.height })
    cur.y += p.height
    local top = Plat(L, x0 + (p.footLen or 8) + 1.5, p.landLen or 9, cur.y, cur.z, p.width or 10, { viaTruss = true })
    cur.x = x0 + (p.footLen or 8) + 1.5 + (p.landLen or 9)
end

-- A platform that carries you along (a conveyor belt): speed in studs/s, positive = the way the course runs. Against it is the hard way.
function Modules.conveyor(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width, { conveyor = p.speed })
    cur.x = x0 + p.len
end

-- Slippery ice stepping stones: little grip, so you slide on landing
function Modules.ice(L, cur, p)
    for i = 1, p.n do
        local x0 = cur.x + p.gap
        cur.z = Clamp(cur.z + ((p.zigs and p.zigs[(i - 1) % #p.zigs + 1]) or 0), L.base.z - L.zRange, L.base.z + L.zRange)
        Plat(L, x0, p.len, cur.y, cur.z, p.width, { ice = true })
        cur.x = x0 + p.len
    end
end

-- A bounce pad that launches you up to a high landing. `rise` is how much higher the landing is; the pad's power is chosen to clear it with room to spare.
function Modules.bounce(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.padLen or 10, cur.y, cur.z, p.width or 12)
    local padX = x0 + (p.padLen or 10) / 2
    table.insert(L.bounces, { x = padX, y = cur.y, z = cur.z, sx = (p.padLen or 10) - 2, sz = (p.width or 12) - 2, power = p.power or 78, hspeed = p.hspeed or 28, rise = p.rise })
    local landX = x0 + (p.padLen or 10) + p.span
    cur.y += p.rise
    Plat(L, landX, p.landLen or 14, cur.y, cur.z, p.landWidth or 14, { viaBounce = true, bounceGap = p.span, bounceRise = p.rise })
    cur.x = landX + (p.landLen or 14)
end

-- A long narrow beam with a bar that sweeps across it: time it, or get knocked off
function Modules.sweeper(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width)
    for i = 1, p.n do
        table.insert(L.sweepers, { x = x0 + (p.len / (p.n + 1)) * i, y = cur.y, z = cur.z, amp = p.amp, period = p.period, phase = (p.phase or 0) + (i - 1) * (p.stagger or 1.7), thick = 1.6 })
    end
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
        platforms = {}, movers = {}, crumbles = {}, spinners = {}, crushers = {}, checkpoints = {}, trusses = {}, bounces = {}, sweepers = {}, kills = {}, grids = {},
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
    for _, m in ipairs(L.movers) do                      -- a mover is one piece from its near extreme to its far one (you ride it across)
        add(m.x0 - m.sx / 2, m.x1 + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover")
    end
    table.sort(out, function(a, b) return a.x1 < b.x1 end)
    return out
end

return CourierLayout
