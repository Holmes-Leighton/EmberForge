-- Builds a Sky Tower from a seed: a stack of levels, each a short run of obstacle sections (the same modules the Courier courses use, see CourierLayout)
-- followed by a climb up to the next level. Levels alternate direction (east, then west ...) and step sideways, so the tower zig-zags upward and no two levels overlap.
-- Pure maths with no Roblox types: tests prove every jump on every seed, and the server and clients build identical towers from the same seed.
local CourierLayout = require(script.Parent.CourierLayout)

local TowerLayout = {}

TowerLayout.CLIMB_LEDGES = 8
TowerLayout.CLIMB_RISE   = { 2.9, 3.4, 3.8 }      -- per ledge, by tier: each under that tier's limit (CourierData.Limits), so early climbs are gentle
TowerLayout.LEVEL_RISE   = TowerLayout.CLIMB_LEDGES * 3.4        -- about how far each level goes up (varies a little with the tier)
TowerLayout.LEVEL_Z_STEP = 18           -- each level sits this much further along Z than the one below
TowerLayout.Z_PATTERN    = { 0, 1, 2, 1 }    -- the sideways shift (in LEVEL_Z_STEPs) of levels 1, 2, 3, 4, then repeating: always one step from the level below

-- Tier of a level by its height in the tower
function TowerLayout.TierOf(level, total)
    local third = total / 3
    if level <= third then return 1 elseif level <= third * 2 then return 2 end
    return 3
end

-- Sections: each is a list of CourierLayout modules, by tier. Widths and gaps stay inside CourierData.Limits for the tier (the tests check it).
local SECTIONS = {
    [1] = {
        { { "steps",   { n = 4, gap = 3.5, len = 9, width = 10, rises = { 1, 0, 1, 0 }, zigs = { 0, 3, -3, 2 } } } },
        { { "mover",   { span = 24, len = 10, width = 12, period = 7, landing = 10, landingWidth = 12 } } },
        { { "crumble", { n = 4, gap = 4, len = 8, width = 9, delay = 0.8 } } },
        { { "spinner", { gap = 3.5, len = 34, width = 24, radius = 10, omega = 1.1 } } },
        { { "steps",   { n = 5, gap = 4, len = 8, width = 9, rises = { 0, 1, 0, -1, 0 }, zigs = { 2, -2, 2, -2, 0 } } } },
    },
    [2] = {
        { { "steps",   { n = 5, gap = 4.5, len = 7, width = 8, rises = { 1, 0, 1, 0, 1 }, zigs = { 0, 4, -4, 3, -3 } } } },
        { { "mover",   { span = 26, len = 9, width = 10, period = 6, landing = 9, landingWidth = 10 } } },
        { { "crusher", { gap = 3, len = 40, width = 14, n = 3, open = 4, closed = 2.5, zone = 6, stagger = 1.8 } } },
        { { "beam",    { gap = 4, len = 22, width = 4 } } },
        { { "spinner", { gap = 4, len = 38, width = 24, radius = 11, omega = 1.6 } } },
        { { "crumble", { n = 5, gap = 4.5, len = 7, width = 8, delay = 0.6 } } },
    },
    [3] = {
        { { "crumble", { n = 5, gap = 5, len = 7, width = 7, delay = 0.5 } } },
        { { "spinner", { gap = 4, len = 40, width = 22, radius = 10, omega = 2.0 } } },
        { { "steps",   { n = 5, gap = 5.5, len = 6, width = 6.5, rises = { 1, 0, 1, 0, -1 }, zigs = { 0, 4, -4, 4, -4 } } } },
        { { "mover",   { span = 28, len = 8, width = 8, period = 5, landing = 8, landingWidth = 8 } } },
        { { "crusher", { gap = 4, len = 46, width = 12, n = 4, open = 3.5, closed = 2.5, zone = 6, stagger = 1.4 } } },
        { { "beam",    { gap = 4.5, len = 26, width = 3.2 } } },
    },
}
TowerLayout.Sections = SECTIONS

-- A tiny deterministic random number generator (so server and clients agree without sharing state)
local function Rng(seed)
    local s = (seed * 2654435761 + 12345) % 4294967296
    return function(n)
        s = (s * 1664525 + 1013904223) % 4294967296
        return (s // 65536) % n + 1
    end
end

-- opts: { levels = 30, seed = 1, base = { x, y, z }, sectionsPerLevel = 2 }
-- Returns { levels = { { index, tier, y, dir, layout, checkpointStart, lava } ... }, base, top = { x, y, z }, finish, platforms, movers, crumbles, spinners, crushers, checkpoints, levelOfCheckpoint }
function TowerLayout.Build(opts)
    local total, seed = opts.levels or 30, opts.seed or 1
    local base = opts.base or { x = 0, y = 100, z = 0 }
    local perLevel = opts.sectionsPerLevel or 2
    local rng = Rng(seed)
    local T = { levels = {}, platforms = {}, movers = {}, crumbles = {}, spinners = {}, crushers = {}, checkpoints = {}, levelOfCheckpoint = {}, base = base, seed = seed, total = total }

    local startX, y, z, dir = base.x, base.y, base.z, 1
    local zStep = TowerLayout.LEVEL_Z_STEP
    for i = 1, total do
        local tier = TowerLayout.TierOf(i, total)
        local modules = { { "rest", { len = 26, width = 26 } } }
        local pool = SECTIONS[tier]
        local last = 0
        for _ = 1, perLevel do                                         -- no section twice in a row
            local pick = rng(#pool)
            if pick == last then pick = pick % #pool + 1 end
            last = pick
            for _, m in ipairs(pool[pick]) do table.insert(modules, m) end
        end
        if i < total then
            table.insert(modules, { "climb", { n = TowerLayout.CLIMB_LEDGES, gap = 3.5, rise = TowerLayout.CLIMB_RISE[tier], len = 8, width = 8, zigs = { 0 } } })
        else
            table.insert(modules, { "finish", { gap = 4, len = 32, width = 28 } })
        end
        local layout = CourierLayout.Build({ base = { x = 0, y = y, z = z }, modules = modules, zRange = 0 })

        -- place the level: its local +X becomes `dir` in the world, starting at startX
        local function wx(x) return startX + dir * x end
        local function addTo(list, item, f) list[#list + 1] = f(item) end
        for _, p in ipairs(layout.platforms) do addTo(T.platforms, p, function(q) local c = {} for k, v in pairs(q) do c[k] = v end c.x = wx(q.x) c.level = i return c end) end
        for _, p in ipairs(layout.crumbles) do addTo(T.crumbles, p, function(q) local c = {} for k, v in pairs(q) do c[k] = v end c.x = wx(q.x) c.level = i return c end) end
        for _, m in ipairs(layout.movers) do addTo(T.movers, m, function(q) local c = {} for k, v in pairs(q) do c[k] = v end c.x0, c.x1 = wx(q.x0), wx(q.x1) c.level = i return c end) end
        for _, s in ipairs(layout.spinners) do addTo(T.spinners, s, function(q) local c = {} for k, v in pairs(q) do c[k] = v end c.x = wx(q.x) c.level = i return c end) end
        for _, c0 in ipairs(layout.crushers) do addTo(T.crushers, c0, function(q) local c = {} for k, v in pairs(q) do c[k] = v end c.x = wx(q.x) c.level = i return c end) end
        local firstCp = #T.checkpoints + 1
        for k, cp in ipairs(layout.checkpoints) do
            T.checkpoints[#T.checkpoints + 1] = { x = wx(cp.x), y = cp.y, z = cp.z, level = i }
            T.levelOfCheckpoint[#T.checkpoints] = i
        end
        T.levels[i] = { index = i, tier = tier, y = y, dir = dir, z = z, firstCheckpoint = firstCp, startX = startX, endX = wx(layout.endX), lava = i > total / 3 }
        if layout.finish then T.finish = { x = wx(layout.finish.x), y = layout.finish.y, z = layout.finish.z, hx = layout.finish.hx, hz = layout.finish.hz } end

        -- the next level starts where this one ended, one step along Z (wrapping), a climb higher
        startX = wx(layout.endX) + dir * 0                              -- (the climb's last ledge is the end)
        y = layout.platforms[#layout.platforms].y + layout.platforms[#layout.platforms].sy / 2         -- top of the last ledge
        z = base.z + TowerLayout.Z_PATTERN[(i % #TowerLayout.Z_PATTERN) + 1] * zStep
        dir = -dir
    end
    T.top = T.finish
    T.height = (T.finish and T.finish.y or y) - base.y
    return T
end

-- The walk order of every piece in level i, for the tests: { x1, x2, top, z, w, kind }
function TowerLayout.WalkOrder(T, level)
    local out = {}
    local function add(x1, x2, top, z, w, kind) out[#out + 1] = { x1 = math.min(x1, x2), x2 = math.max(x1, x2), top = top, z = z, w = w, kind = kind } end
    for _, p in ipairs(T.platforms) do if p.level == level then add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "platform") end end
    for _, p in ipairs(T.crumbles) do if p.level == level then add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "crumble") end end
    for _, m in ipairs(T.movers) do if m.level == level then add(math.min(m.x0, m.x1) - m.sx / 2, math.max(m.x0, m.x1) + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover") end end
    return out
end

return TowerLayout
