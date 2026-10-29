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
--   walls      { x, y(top of the platform), z, sx, sy, sz }   a solid wall on a platform: tall ones to weave round (slalom), low ones to jump (hurdle)
--   (platforms may also carry conveyor = speed, ice = true, viaTruss / viaBounce = true on the landing of a ladder or bounce)
--   rotors     { x, y(top), z, radius, arms, width, omega, phase, hub }   a windmill: arms turning round a hub, carrying you; the hub is a small solid platform (platforms, rotor = true)
--   blinkers   { x, y, z, sx, sy, sz, period, duty, phase }   a platform that is solid for `duty` of every `period` seconds, flickers as a warning, then vanishes
--   helixes    { x1, x2, top, bottom, z, w, ledges, radius, ledge, rise }   a spiral of ledges (each also in platforms / crumbles with helix = true), climbed as one piece
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

-- A long platform with walls across it. With `hurdle` each wall spans the whole width and is low enough to jump over (wallH, about 2.5 to 3.4). Otherwise each wall is tall
-- (wallH, about 9: too high to jump) and leaves a gap of `open` studs on alternate sides, so you have to weave from side to side round them.
function Modules.slalom(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width)
    local open = p.open or 6
    for i = 1, p.n do
        local x = x0 + (p.len / (p.n + 1)) * i
        if p.hurdle then
            table.insert(L.walls, { x = x, y = cur.y, z = cur.z, sx = p.thick or 1.6, sy = p.wallH or 3, sz = p.width })
        else
            local side = (i % 2 == 1) and 1 or -1                     -- the gap is on this side
            table.insert(L.walls, { x = x, y = cur.y, z = cur.z - side * open / 2, sx = p.thick or 1.6, sy = p.wallH or 9, sz = p.width - open, open = open })
        end
    end
    cur.x = x0 + p.len
end

-- A platform with bright yellow strips across it: touching one sends you back to the start of the level. Each strip is `strip` studs wide along the course and spans the whole
-- platform, so the only way over is to jump (the platform is `spacing` studs between strips).
function Modules.strips(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width)
    local strip, n = p.strip or 2.2, p.n
    local spacing = (p.len - n * strip) / (n + 1)
    for i = 1, n do
        local x = x0 + spacing * i + strip * (i - 0.5)
        table.insert(L.kills, { x = x, y = cur.y, z = cur.z, sx = strip, sz = p.width, style = "strip" })
    end
    cur.x = x0 + p.len
end

-- Climbing ledges that are not all plain: `pattern` has one letter per ledge, "p" a plain ledge, "n" a narrow plain one (width p.narrow), "c" a ledge that crumbles shortly
-- after you land on it. The last ledge must be plain (it is where the next level starts).
function Modules.climbmix(L, cur, p)
    for i = 1, #p.pattern do
        local kind = p.pattern:sub(i, i)
        local x0 = cur.x + p.gap
        cur.y += p.rise
        local width = (kind == "n") and (p.narrow or 5) or p.width
        if kind == "c" then
            table.insert(L.crumbles, { x = x0 + p.len / 2, y = cur.y - THICK / 2, z = cur.z, sx = p.len, sy = THICK, sz = width, delay = p.delay or 0.7, respawn = p.respawn or 3 })
        else
            Plat(L, x0, p.len, cur.y, cur.z, width)
        end
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

-- A windmill: `arms` arms of length `radius` turning round a small solid hub, `omega` radians a second (negative turns the other way). Jump onto an arm when its tip swings
-- up to the platform you stand on (it passes every 2 pi / (arms x omega) seconds), ride it in to the hub, wait for an arm to point at the landing, and jump off. The hub is a
-- real platform (flagged rotor = true); the arms are drawn and turned by the client on the shared clock (CourierLayout.RotorArm).
function Modules.rotor(L, cur, p)
    local R, hub = p.radius or 10, p.hub or 3
    local gap = p.gap or 3.5
    local hx = cur.x + gap + R
    Plat(L, hx - hub, 2 * hub, cur.y, cur.z, 2 * hub, { rotor = true })
    table.insert(L.rotors, { x = hx, y = cur.y, z = cur.z, radius = R, arms = p.arms or 2, width = p.armWidth or 5.5, omega = p.omega or 0.6, phase = p.phase or 0, hub = hub, gap = gap })
    local lx = hx + R + gap
    Plat(L, lx, p.landing or 10, cur.y, cur.z, p.landingWidth or 12)
    cur.x = lx + (p.landing or 10)
end

-- Platforms that vanish and come back: each is solid for `duty` of every `period` seconds, flickers in its last moments, then is gone until its turn comes round. They are staggered
-- along the row so each one is solid for a while after the next one appears (the overlap is p.overlap of a period, 0.3 by default), so there is always time to hop on.
function Modules.blink(L, cur, p)
    local period, duty = p.period or 4, p.duty or 0.65
    local stagger = period * (duty - (p.overlap or 0.3))
    for i = 1, p.n do
        local x0 = cur.x + p.gap
        table.insert(L.blinkers, { x = x0 + p.len / 2, y = cur.y - THICK / 2, z = cur.z, sx = p.len, sy = THICK, sz = p.width, period = period, duty = duty, phase = (p.phase or 0) + (i - 1) * stagger })
        cur.x = x0 + p.len
    end
end

-- A chimney: a shaft between two tall walls climbed by zig-zagging up small ledges, one on each side in turn, each higher than the last. A hard, vertical climb (not a staircase):
-- every hop is sideways and up. `ice` makes the ledges slippery. The way out is a landing at the top, and the walls are flagged shaft = true.
function Modules.chimney(L, cur, p)
    local len, width, off, gap = p.len or 4, p.width or 4, p.off or 3.6, p.gap or 1.2
    local x0 = cur.x + (p.gap0 or 3)
    local y0 = cur.y
    local x = x0
    for i = 1, p.n do
        cur.y += p.rise
        local side = (i % 2 == 1) and -1 or 1
        Plat(L, x, len, cur.y, cur.z + side * off, width, p.ice and { ice = true } or nil)
        x += len + gap
    end
    local top = x - gap
    local landing = p.landing or 9
    Plat(L, top + 1.2, landing, cur.y, cur.z, 2 * off + width + 1)
    local length = (top + 1.2 + landing) - x0
    for _, side in ipairs({ -1, 1 }) do
        table.insert(L.walls, { x = x0 + length / 2, y = y0, z = cur.z + side * (off + width / 2 + 0.7), sx = length + 2, sy = p.n * p.rise + 8, sz = 1.2, shaft = true })
    end
    cur.x = top + 1.2 + landing
end

-- A spiral: `n` square ledges (p.width on a side) winding round a hub of radius p.radius, each one `p.rise` higher than the last, so you climb a full level in a corkscrew
-- instead of a staircase. It sweeps p.sweep radians (an odd multiple of pi, default 1.5 turns), so the last ledge lies due east and the course carries on east from it.
-- `pattern` has a letter per ledge: "p" plain, "c" crumbles shortly after you land, "i" ice; the last must be "p". p.cw winds the other way.
-- Every ledge is flagged helix = true and the whole spiral is listed in L.helixes (the tests treat it as one piece you climb, like a ladder).
function Modules.helix(L, cur, p)
    local n, R, w = p.n or 8, p.radius or 9, p.width or 7
    local sweep = p.sweep or 3 * math.pi
    local pattern = p.pattern or string.rep("p", n)
    local dirn = p.cw and -1 or 1
    -- the first ledge is due west of the hub (so you step straight onto it from the platform before) and the last due east (so the course carries on east from it)
    local cx, cz = cur.x + (p.gap or 3) + R + w / 2, cur.z
    local y = cur.y
    for k = 1, n do
        y = cur.y + k * p.rise
        local th = math.pi + dirn * sweep * (k - 1) / (n - 1)
        local x, z = cx + R * math.cos(th), cz + R * math.sin(th)
        local kind = pattern:sub(k, k)
        if kind == "c" then
            table.insert(L.crumbles, { x = x, y = y - THICK / 2, z = z, sx = w, sy = THICK, sz = w, delay = p.delay or 0.7, respawn = p.respawn or 3, helix = true })
        else
            Plat(L, x - w / 2, w, y, z, w, { helix = true, ice = (kind == "i") or nil })
        end
    end
    table.insert(L.helixes, { x1 = cx - R - w / 2, x2 = cx + R + w / 2, top = y, bottom = cur.y, z = cz, w = 2 * R + w, ledges = n, radius = R, ledge = w, rise = p.rise })
    cur.x, cur.y = cx + R + w / 2, y
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

-- A lift: a platform that rides up and down between the start platform's height and a higher landing (sine-eased, on the shared clock). Step on at the bottom, off at the top.
function Modules.lift(L, cur, p)
    local len, rise = p.len or 8, p.rise or 12
    local x0 = cur.x + (p.gap or 2)
    table.insert(L.lifts, { x = x0 + len / 2, z = cur.z, y0 = cur.y - THICK / 2, y1 = cur.y + rise - THICK / 2, sx = len, sy = THICK, sz = p.width or 9,
        period = p.period or 7, phase = p.phase or 0 })
    local lx = x0 + len + (p.gap or 2)
    Plat(L, lx, p.landing or 10, cur.y + rise, cur.z, p.landingWidth or p.width or 10, { viaTruss = true })      -- (the lift carries the height)
    cur.y += rise
    cur.x = lx + (p.landing or 10)
end

-- A platform that slides toward you and away (along Z) across the gap: hop on when it comes near, off at the far side. The wide entry and landing platforms cover its whole sweep.
function Modules.zmover(L, cur, p)
    local len, width, amp = p.len or 8, p.width or 9, p.amp or 5
    local wide = width + 2 * amp + 2
    local e0 = cur.x + (p.gap or 2)
    Plat(L, e0, p.entry or 6, cur.y, cur.z, wide)
    local x0 = e0 + (p.entry or 6) + 2
    table.insert(L.zmovers, { x = x0 + len / 2, y = cur.y - THICK / 2, z0 = cur.z - amp, z1 = cur.z + amp, sx = len, sy = THICK, sz = width, period = p.period or 6, phase = p.phase or 0 })
    local lx = x0 + len + 2
    Plat(L, lx, p.landing or 10, cur.y, cur.z, wide)
    cur.x = lx + (p.landing or 10)
end

-- A platform that travels round in a circle across the gap: step on from the entry side, ride half a turn, step off to the landing
function Modules.orbit(L, cur, p)
    local r, len, width = p.radius or 9, p.len or 8, p.width or 8
    local wide = 2 * r + width + 2
    local e0 = cur.x + (p.gap or 2)
    Plat(L, e0, p.entry or 6, cur.y, cur.z, wide)
    local cx = e0 + (p.entry or 6) + 2 + r + len / 2
    table.insert(L.orbiters, { x = cx, y = cur.y - THICK / 2, z = cur.z, radius = r, sx = len, sy = THICK, sz = width, omega = p.omega or 0.55, phase = p.phase or math.pi })
    local lx = cx + r + len / 2 + 2
    Plat(L, lx, p.landing or 10, cur.y, cur.z, wide)
    cur.x = lx + (p.landing or 10)
end

-- A long platform with swinging blades hung over it: time the swing or jump the blade
function Modules.pendulum(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    Plat(L, x0, p.len, cur.y, cur.z, p.width or 9)
    local n, length = p.n or 3, p.length or 12
    for i = 1, n do
        table.insert(L.pendulums, { x = x0 + (p.len / (n + 1)) * i, z = cur.z, y = cur.y, length = length, pivotY = cur.y + length + 3.5, amp = p.amp or 0.95,
            period = p.period or 3.2, phase = (p.phase or 0) + (i - 1) * (p.stagger or 1.1), width = p.width or 9 })
    end
    cur.x = x0 + p.len
end

-- A big pad with glowing circles: every few seconds one circle charges (warning), then a beam of light shoots up out of it, killing anything standing in it
function Modules.beams(L, cur, p)
    local x0 = cur.x + (p.gap or 3)
    local len, width = p.len or 36, p.width or 24
    Plat(L, x0, len, cur.y, cur.z, width)
    -- small circles scattered at random (the same every time for a seed): sizes vary a little, none overlap, all stay on the pad
    local seed = p.seed or (#L.beamfields * 31 + math.floor(cur.y) % 97 + 7)
    local state = (seed * 2654435761 + 12345) % 4294967296
    local function rnd()
        state = (state * 1664525 + 1013904223) % 4294967296
        return (state // 256) / 16777216
    end
    local count, rmin, rmax = p.count or 9, p.rmin or 2.0, p.rmax or 3.0
    local circles = {}
    for _ = 1, count do
        for _ = 1, 60 do
            local r = rmin + (rmax - rmin) * rnd()
            local cx = x0 + r + 2 + (len - 2 * r - 4) * rnd()
            local cz = cur.z + (rnd() - 0.5) * (width - 2 * r - 3)
            local ok = true
            for _, o in ipairs(circles) do
                local dx, dz = cx - o.x, cz - o.z
                if dx * dx + dz * dz < (r + o.r + 2.5) * (r + o.r + 2.5) then ok = false break end
            end
            if ok then table.insert(circles, { x = cx, z = cz, r = r }) break end
        end
    end
    table.insert(L.beamfields, { x1 = x0, x2 = x0 + len, y = cur.y, circles = circles, period = p.period or 3, warn = p.warn or 1.2, fire = p.fire or 0.7,
        phase = p.phase or 0, seed = seed })
    cur.x = x0 + len
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
        platforms = {}, movers = {}, crumbles = {}, spinners = {}, crushers = {}, checkpoints = {}, trusses = {}, bounces = {}, sweepers = {}, walls = {}, kills = {}, grids = {},
        lifts = {}, zmovers = {}, orbiters = {}, pendulums = {}, beamfields = {}, helixes = {}, rotors = {}, blinkers = {},
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

-- ── Shared motion rules (server and clients both call these on the shared clock) ──
local function Ease(t, period, phase) return 0.5 - 0.5 * math.cos(2 * math.pi * (t + (phase or 0)) / period) end
function CourierLayout.LiftY(l, t) return l.y0 + (l.y1 - l.y0) * Ease(t, l.period, l.phase) end
function CourierLayout.ZMoverZ(m, t) return m.z0 + (m.z1 - m.z0) * Ease(t, m.period, m.phase) end
function CourierLayout.OrbitPos(o, t)
    local a = o.phase + o.omega * t
    return o.x + o.radius * math.cos(a), o.z + o.radius * math.sin(a)
end
-- The windmill's arm i (1-based) at time t: the angle it points at (counter-clockwise in the x-z plane: 0 is +x), and where its middle is. An arm is a box `radius` long.
function CourierLayout.RotorArm(r, i, t)
    local a = (r.phase + r.omega * t + (i - 1) * 2 * math.pi / r.arms) % (2 * math.pi)
    return a, r.x + math.cos(a) * r.radius / 2, r.z + math.sin(a) * r.radius / 2
end
-- Is the point (x, y, z) standing on arm i of the windmill at time t? (y is the player's feet or root; `top` is the arm's top)
function CourierLayout.OnRotorArm(r, i, t, x, y, z)
    local a = CourierLayout.RotorArm(r, i, t)
    local dx, dz = x - r.x, z - r.z
    local along = dx * math.cos(a) + dz * math.sin(a)                       -- along the arm from the hub
    local across = -dx * math.sin(a) + dz * math.cos(a)
    return along >= -0.6 and along <= r.radius + 0.6 and math.abs(across) <= r.width / 2 + 0.6 and y > r.y - 0.6 and y < r.y + 6
end
-- Turn the point (x, z) by `d` radians about (cx, cz), the same way the arms turn
function CourierLayout.RotateAbout(cx, cz, x, z, d)
    local dx, dz = x - cx, z - cz
    local c, s = math.cos(d), math.sin(d)
    return cx + dx * c - dz * s, cz + dx * s + dz * c
end
-- A vanishing platform at time t: "solid", "warn" (still solid, flickering: it is about to go) or "gone"
CourierLayout.BLINK_WARN = 0.8
function CourierLayout.BlinkState(b, t)
    local u = (t - b.phase) % b.period
    local on = b.duty * b.period
    if u < on - CourierLayout.BLINK_WARN then return "solid" end
    if u < on then return "warn" end
    return "gone"
end

-- The blade's centre (x, y) at time t: it hangs `length` below its pivot and swings through +-amp radians along the course
function CourierLayout.PendulumBlade(p, t)
    local a = p.amp * math.sin(2 * math.pi * (t + p.phase) / p.period)
    return p.x + p.length * math.sin(a), p.pivotY - p.length * math.cos(a), a
end
-- Which circles of a beam field are charging or firing at time t: a list of { idx, state = "warn" | "fire", k = how far through the charge 0..1 } (empty between shots).
-- Several independent "lanes" each shoot on their own irregular clock: a shot starts at a random moment inside its slot, some slots stay silent, and which circle is
-- chosen is random, so there is no pattern to learn. Every shot still warns for `warn` seconds before it fires, so it is always dodgeable.
local function H(seed, slot, salt)
    local h = ((slot % 100003) * 2654435 + seed * 7919 + salt * 104729) % 1000003
    return ((h * h) % 1000033) / 1000033
end
function CourierLayout.BeamState(f, t)
    local out = {}
    local lanes = f.lanes or 2
    for lane = 1, lanes do
        local period = f.period * (1 + 0.43 * (lane - 1))
        local salt = lane * 17
        local u = t + f.phase + lane * 1.37
        local slot = math.floor(u / period)
        local into = u - slot * period
        if H(f.seed, slot, salt + 1) > 0.22 then                                   -- (about one slot in five stays quiet)
            local slack = math.max(0, period - f.warn - f.fire)
            local start = H(f.seed, slot, salt + 2) * slack
            local idx = math.floor(H(f.seed, slot, salt + 3) * #f.circles) + 1
            local e = into - start
            if e >= 0 and e < f.warn then
                table.insert(out, { idx = idx, state = "warn", k = e / f.warn })
            elseif e >= f.warn and e < f.warn + f.fire then
                table.insert(out, { idx = idx, state = "fire", k = 1 })
            end
        end
    end
    return out
end

-- The solid pieces a player walks on, in course order (platforms, crumbles and the extremes of movers), as { x1, x2, y(top), z, w }
function CourierLayout.WalkOrder(L)
    local out = {}
    local function add(x1, x2, top, z, w, kind) table.insert(out, { x1 = x1, x2 = x2, top = top, z = z, w = w, kind = kind }) end
    for _, p in ipairs(L.platforms) do add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "platform") end
    for _, p in ipairs(L.crumbles) do add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "crumble") end
    for _, m in ipairs(L.movers) do                      -- a mover is one piece from its near extreme to its far one (you ride it across)
        add(m.x0 - m.sx / 2, m.x1 + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover")
    end
    for _, l in ipairs(L.lifts) do add(l.x - l.sx / 2, l.x + l.sx / 2, l.y0 + l.sy / 2, l.z, l.sz, "lift") end
    for _, b in ipairs(L.blinkers or {}) do add(b.x - b.sx / 2, b.x + b.sx / 2, b.y + b.sy / 2, b.z, b.sz, "blink") end
    for _, m in ipairs(L.zmovers) do add(m.x - m.sx / 2, m.x + m.sx / 2, m.y + m.sy / 2, (m.z0 + m.z1) / 2, m.sz + math.abs(m.z1 - m.z0), "zmover") end
    for _, o in ipairs(L.orbiters) do add(o.x - o.radius - o.sx / 2, o.x + o.radius + o.sx / 2, o.y + o.sy / 2, o.z, 2 * o.radius + o.sz, "orbit") end
    table.sort(out, function(a, b) return a.x1 < b.x1 end)
    return out
end

return CourierLayout
