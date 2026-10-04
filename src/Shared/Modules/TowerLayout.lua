-- Builds a Sky Tower from a seed: a stack of levels, each one of the hand-designed LEVEL DESIGNS below (a named idea with its own obstacles and its own look), joined by a
-- climb or a ladder to the next. Levels alternate direction and step sideways, so the tower zig-zags upward and no two levels overlap.
-- Pure maths with no Roblox types: tests prove every jump on every seed, and the server and clients build identical towers from the same seed.
local CourierLayout = require(script.Parent.CourierLayout)

local TowerLayout = {}

TowerLayout.CLIMB_LEDGES = 8
TowerLayout.CLIMB_RISE   = { 2.9, 3.4, 3.8 }      -- per ledge, by tier: each under that tier's limit (CourierData.Limits), so early climbs are gentle
TowerLayout.LEVEL_RISE   = TowerLayout.CLIMB_LEDGES * 3.4        -- about how far each level goes up (varies a little with the tier)
TowerLayout.LEVEL_Z_STEP = 18           -- each level sits this much further along Z than the one below
TowerLayout.CENTRE_OFFSET = 110       -- the middle of the tower, east of the first level's start
TowerLayout.DRIFT        = 70        -- a level that ends further than this from the middle turns the next one back
TowerLayout.Z_PATTERN    = { 0, 1, 2, 1 }    -- the sideways shift (in LEVEL_Z_STEPs) of levels 1, 2, 3, 4, then repeating: always one step from the level below

function TowerLayout.TierOf(level, total)
    local third = total / 3
    if level <= third then return 1 elseif level <= third * 2 then return 2 end
    return 3
end

-- ── The level designs ─────────────────────────────────────────────────────────
-- name: shown on the level's sign. theme: its look (TowerArt.Themes). tier: how hard (1 easy .. 3 hard); its jumps must fit CourierData.Limits[tier].
-- modules: the obstacles in order (CourierLayout modules; the level always starts with a rest platform, added here).
-- connector: how you get up to the next level: the default is ledges to climb; a design can use a ladder (the ladder carries the height).
local DESIGNS = {
    -- tier 1: learning the moves
    { name = "Ladder Shaft", theme = "wood", tier = 1,
      modules = { { "steps", { n = 3, gap = 3.5, len = 9, width = 10, rises = { 0, 1, 0 }, zigs = { 0, 3, -3 } } } },
      connector = { { "ladder", { gap = 3.5, height = 22, footLen = 8, landLen = 9, width = 12 } } } },
    { name = "Stepping Stones", theme = "sandstone", tier = 1,
      modules = { { "steps", { n = 7, gap = 4, len = 7, width = 8, rises = { 1, -1, 1, 0, 1, -1, 2 }, zigs = { 0, 4, -4, 3, -3, 4, -2 } } } } },
    { name = "Conveyor Run", theme = "metal", tier = 1,
      modules = { { "conveyor", { gap = 3, len = 30, width = 14, speed = 5 } },
                  { "conveyor", { gap = 3, len = 30, width = 14, speed = -4 } },
                  { "steps", { n = 2, gap = 4, len = 9, width = 10, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Crumble Bridge", theme = "wood", tier = 1,
      modules = { { "crumble", { n = 6, gap = 4, len = 8, width = 9, delay = 0.8 } },
                  { "steps", { n = 2, gap = 4, len = 9, width = 10, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Spinner Hall", theme = "neon", tier = 1,
      modules = { { "spinner", { gap = 3.5, len = 36, width = 24, radius = 10, omega = 1.1 } },
                  { "steps", { n = 2, gap = 4, len = 9, width = 10, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Bounce Pad", theme = "neon", tier = 1,
      modules = { { "bounce", { gap = 3.5, padLen = 10, width = 12, span = 8, rise = 10, power = 78, landLen = 14, landWidth = 14 } },
                  { "steps", { n = 3, gap = 4, len = 9, width = 10, rises = { 0, 1, 0 }, zigs = { 0, 3, -3 } } } } },

    -- tier 2: timing and control
    { name = "Ice Rink", theme = "ice", tier = 2,
      modules = { { "ice", { n = 6, gap = 4.5, len = 9, width = 9, zigs = { 0, 3, -3, 3, -3, 2 } } },
                  { "steps", { n = 2, gap = 4.5, len = 8, width = 9, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Sweeper Beam", theme = "metal", tier = 2,
      modules = { { "sweeper", { gap = 4, len = 42, width = 5, n = 3, amp = 4, period = 3.4, stagger = 1.7 } } } },
    { name = "Crusher Corridor", theme = "dark", tier = 2,
      modules = { { "crusher", { gap = 3, len = 46, width = 14, n = 4, open = 3.5, closed = 2.5, zone = 6, stagger = 1.6 } } } },
    { name = "Mover Gauntlet", theme = "glass", tier = 2,
      modules = { { "mover", { span = 26, len = 9, width = 10, period = 6, landing = 9, landingWidth = 10 } },
                  { "mover", { span = 28, len = 8, width = 9, period = 5, phase = 2.5, landing = 9, landingWidth = 10 } },
                  { "steps", { n = 2, gap = 4.5, len = 8, width = 9, rises = { 0, 1 }, zigs = { 0, 0 } } } },
      connector = { { "ladder", { gap = 3.5, height = 24, footLen = 8, landLen = 9, width = 12 } } } },

    -- tier 3: the hard ones
    { name = "Tiny Islands", theme = "slate", tier = 3,
      modules = { { "steps", { n = 9, gap = 5.5, len = 5, width = 5, rises = { 1, -2, 2, -1, 3, -2, 1, 2, -1 }, zigs = { 0, 5, -5, 5, -5, 4, -4, 3, -3 } } } },
      connector = { { "ladder", { gap = 4, height = 26, footLen = 7, landLen = 8, width = 10 } } } },
    { name = "The Gauntlet", theme = "lava", tier = 3,
      modules = { { "bounce", { gap = 4, padLen = 10, width = 12, span = 9, rise = 12, power = 82, landLen = 14, landWidth = 14 } },
                  { "sweeper", { gap = 4, len = 36, width = 5, n = 2, amp = 4, period = 3.0, stagger = 1.5 } },
                  { "spinner", { gap = 4, len = 38, width = 22, radius = 10, omega = 1.9 } } },
      connector = { { "ladder", { gap = 3.5, height = 26, footLen = 8, landLen = 9, width = 12 } } } },
    { name = "Ice Beam", theme = "ice", tier = 3,
      modules = { { "ice", { n = 5, gap = 5, len = 6, width = 6, zigs = { 0, 5, -5, 5, -4 } } },
                  { "beam", { gap = 4.5, len = 24, width = 3.2 } },
                  { "crumble", { n = 4, gap = 5, len = 6, width = 6.5, delay = 0.5 } } } },
    { name = "Conveyor Crush", theme = "metal", tier = 3,
      modules = { { "conveyor", { gap = 3, len = 36, width = 12, speed = -5 } },
                  { "crusher", { gap = 3, len = 44, width = 12, n = 3, open = 3.5, closed = 2.5, zone = 6, stagger = 1.4 } } } },

    -- more tier 1
    { name = "Belt & Bridge", theme = "metal", tier = 1,
      modules = { { "conveyor", { gap = 3, len = 26, width = 12, speed = 4 } },
                  { "crumble", { n = 4, gap = 4, len = 8, width = 9, delay = 0.9 } } } },
    { name = "Pad Hop", theme = "neon", tier = 1,
      modules = { { "bounce", { gap = 3.5, padLen = 10, width = 12, span = 7, rise = 8, power = 74, hspeed = 26, landLen = 14, landWidth = 14 } },
                  { "crumble", { n = 3, gap = 4, len = 8, width = 9, delay = 0.9 } } } },
    { name = "Stone Ladder", theme = "sandstone", tier = 1,
      modules = { { "steps", { n = 4, gap = 4, len = 8, width = 9, rises = { 1, -1, 1, 1 }, zigs = { 0, 4, -4, 3 } } } },
      connector = { { "ladder", { gap = 3.5, height = 20, footLen = 8, landLen = 9, width = 12 } } } },
    { name = "Spin & Climb", theme = "wood", tier = 1,
      modules = { { "spinner", { gap = 3.5, len = 32, width = 22, radius = 9, omega = 1.0 } } },
      connector = { { "ladder", { gap = 3.5, height = 22, footLen = 8, landLen = 9, width = 12 } } } },

    -- more tier 2
    { name = "Slick Crush", theme = "dark", tier = 2,
      modules = { { "ice", { n = 3, gap = 4.5, len = 9, width = 9, zigs = { 0, 3, -3 } } },
                  { "crusher", { gap = 4, len = 36, width = 13, n = 2, open = 3.5, closed = 2.5, zone = 6, stagger = 1.8 } } } },
    { name = "Ice & Sweep", theme = "ice", tier = 2,
      modules = { { "ice", { n = 3, gap = 4.5, len = 9, width = 9, zigs = { 0, 3, -3 } } },
                  { "sweeper", { gap = 4, len = 32, width = 5, n = 2, amp = 3.5, period = 3.6, stagger = 1.8 } } } },
    { name = "Mover & Spinner", theme = "glass", tier = 2,
      modules = { { "mover", { span = 26, len = 9, width = 10, period = 6, landing = 9, landingWidth = 11 } },
                  { "spinner", { gap = 4, len = 32, width = 22, radius = 9, omega = 1.5 } } } },
    { name = "Bounce & Crumble", theme = "neon", tier = 2,
      modules = { { "bounce", { gap = 4, padLen = 10, width = 12, span = 8, rise = 10, power = 78, landLen = 14, landWidth = 14 } },
                  { "crumble", { n = 4, gap = 4.5, len = 7, width = 8, delay = 0.7 } } } },
    { name = "Slide & Climb", theme = "ice", tier = 2,
      modules = { { "ice", { n = 4, gap = 4.5, len = 9, width = 9, zigs = { 0, 3, -3, 3 } } } },
      connector = { { "ladder", { gap = 4, height = 24, footLen = 8, landLen = 9, width = 12 } } } },

    -- more tier 3
    { name = "Narrow Sweep", theme = "slate", tier = 3,
      modules = { { "beam", { gap = 4, len = 18, width = 3.2 } },
                  { "sweeper", { gap = 4.5, len = 30, width = 4.6, n = 2, amp = 3.2, period = 3.2, stagger = 1.6 } } } },
    { name = "Spin Islands", theme = "lava", tier = 3,
      modules = { { "steps", { n = 5, gap = 5.5, len = 5, width = 5.5, rises = { 1, -2, 2, -1, 2 }, zigs = { 0, 4, -4, 4, -3 } } },
                  { "spinner", { gap = 4.5, len = 34, width = 20, radius = 9, omega = 2.0 } } } },
    { name = "Crusher Climb", theme = "dark", tier = 3,
      modules = { { "crusher", { gap = 3.5, len = 40, width = 12, n = 3, open = 3.5, closed = 2.5, zone = 6, stagger = 1.5 } } },
      connector = { { "ladder", { gap = 3.5, height = 28, footLen = 8, landLen = 9, width = 11 } } } },
    { name = "Triple Threat", theme = "metal", tier = 3,
      modules = { { "sweeper", { gap = 4, len = 30, width = 5, n = 2, amp = 3.5, period = 3.2, stagger = 1.6 } },
                  { "conveyor", { gap = 4, len = 26, width = 11, speed = -4 } },
                  { "crumble", { n = 3, gap = 5, len = 6.5, width = 7, delay = 0.55 } } } },
    { name = "Bounce Gauntlet", theme = "lava", tier = 3,
      modules = { { "bounce", { gap = 4, padLen = 10, width = 12, span = 9, rise = 13, power = 86, hspeed = 28, landLen = 14, landWidth = 14 } },
                  { "mover", { span = 28, len = 8, width = 9, period = 5, landing = 9, landingWidth = 10 } } },
      connector = { { "ladder", { gap = 3.5, height = 26, footLen = 8, landLen = 9, width = 12 } } } },
}
TowerLayout.Designs = DESIGNS

-- A tiny deterministic random number generator (so server and clients agree without sharing state)
local function Rng(seed)
    local s = (seed * 2654435761 + 12345) % 4294967296
    return function(n)
        s = (s * 1664525 + 1013904223) % 4294967296
        return (s // 65536) % n + 1
    end
end

-- The designs of a tier, in a shuffled deck: a tower deals from it, so no design repeats until all of that tier's have been used
local function Deck(tier, rng)
    local deck = {}
    for i, d in ipairs(DESIGNS) do if d.tier == tier then deck[#deck + 1] = i end end
    for k = #deck, 2, -1 do
        local j = rng(k)
        deck[k], deck[j] = deck[j], deck[k]
    end
    return deck
end

local function Copy(q) local c = {} for k, v in pairs(q) do c[k] = v end return c end

-- opts: { levels = 30, seed = 1, base = { x, y, z } }
function TowerLayout.Build(opts)
    local total, seed = opts.levels or 30, opts.seed or 1
    local base = opts.base or { x = 0, y = 100, z = 0 }
    local rng = Rng(seed)
    local T = { levels = {}, platforms = {}, movers = {}, crumbles = {}, spinners = {}, crushers = {}, checkpoints = {}, levelOfCheckpoint = {},
        trusses = {}, bounces = {}, sweepers = {}, base = base, seed = seed, total = total }

    local startX, y, z, dir = base.x, base.y, base.z, 1
    local lastDesign = 0
    local decks = {}
    for i = 1, total do
        local tier = TowerLayout.TierOf(i, total)
        decks[tier] = decks[tier] or {}
        local pick
        for _ = 1, 4 do                                                -- deal the next design of this tier's deck (reshuffling when it runs out); never the same twice in a row
            if #decks[tier] == 0 then decks[tier] = Deck(tier, rng) end
            pick = table.remove(decks[tier])
            if pick ~= lastDesign then break end
        end
        lastDesign = pick
        local design = DESIGNS[pick]

        local modules = { { "rest", { len = 26, width = 26 } } }
        for _, m in ipairs(design.modules) do modules[#modules + 1] = m end
        if i < total then
            if design.connector then
                for _, m in ipairs(design.connector) do modules[#modules + 1] = m end
            else
                modules[#modules + 1] = { "climb", { n = TowerLayout.CLIMB_LEDGES, gap = 3.2, rise = TowerLayout.CLIMB_RISE[design.tier], len = 7, width = 8, zigs = { 0 } } }
            end
        else
            modules[#modules + 1] = { "finish", { gap = 4, len = 32, width = 28 } }
        end
        local layout = CourierLayout.Build({ base = { x = 0, y = y, z = z }, modules = modules, zRange = 0 })

        local function wx(x) return startX + dir * x end
        local function put(list, src, fn)
            for _, item in ipairs(src) do
                local c = Copy(item)
                fn(c, item)
                c.level = i
                list[#list + 1] = c
            end
        end
        put(T.platforms, layout.platforms, function(c, q)
            c.x = wx(q.x)
            if q.conveyor then c.conveyor = q.conveyor * dir end        -- a belt runs with or against the way you climb, whichever way this level faces
        end)
        put(T.crumbles, layout.crumbles, function(c, q) c.x = wx(q.x) end)
        put(T.movers, layout.movers, function(c, q) c.x0, c.x1 = wx(q.x0), wx(q.x1) end)
        put(T.spinners, layout.spinners, function(c, q) c.x = wx(q.x) end)
        put(T.crushers, layout.crushers, function(c, q) c.x = wx(q.x) end)
        put(T.trusses, layout.trusses, function(c, q) c.x = wx(q.x) end)
        put(T.bounces, layout.bounces, function(c, q) c.x = wx(q.x) c.dir = dir end)         -- (it throws you the way the level runs)
        put(T.sweepers, layout.sweepers, function(c, q) c.x = wx(q.x) end)
        local firstCp = #T.checkpoints + 1
        for _, cp in ipairs(layout.checkpoints) do
            T.checkpoints[#T.checkpoints + 1] = { x = wx(cp.x), y = cp.y, z = cp.z, level = i }
            T.levelOfCheckpoint[#T.checkpoints] = i
        end
        T.levels[i] = { index = i, tier = tier, designTier = design.tier, design = design.name, theme = design.theme, y = y, dir = dir, z = z,
            firstCheckpoint = firstCp, startX = startX, endX = wx(layout.endX), lava = i > total / 3 }
        if layout.finish then T.finish = { x = wx(layout.finish.x), y = layout.finish.y, z = layout.finish.z, hx = layout.finish.hx, hz = layout.finish.hz } end

        startX = wx(layout.endX)
        local lastPlat = layout.platforms[#layout.platforms]
        y = lastPlat.y + lastPlat.sy / 2
        z = base.z + TowerLayout.Z_PATTERN[(i % #TowerLayout.Z_PATTERN) + 1] * TowerLayout.LEVEL_Z_STEP
        -- zig-zag, but if the tower has drifted sideways (levels differ in length) head back toward the middle, so it stays compact
        local centre = base.x + TowerLayout.CENTRE_OFFSET
        if startX > centre + TowerLayout.DRIFT then dir = -1
        elseif startX < centre - TowerLayout.DRIFT then dir = 1
        else dir = -dir end
    end
    T.top = T.finish
    T.height = (T.finish and T.finish.y or y) - base.y
    return T
end

-- The walk order of every piece in level i, for the tests: { x1, x2, top, z, w, kind, viaTruss, viaBounce }
function TowerLayout.WalkOrder(T, level)
    local out = {}
    local function add(x1, x2, top, z, w, kind, src)
        out[#out + 1] = { x1 = math.min(x1, x2), x2 = math.max(x1, x2), top = top, z = z, w = w, kind = kind, viaTruss = src and src.viaTruss, viaBounce = src and src.viaBounce }
    end
    for _, p in ipairs(T.platforms) do if p.level == level then add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "platform", p) end end
    for _, p in ipairs(T.crumbles) do if p.level == level then add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "crumble") end end
    for _, m in ipairs(T.movers) do if m.level == level then add(math.min(m.x0, m.x1) - m.sx / 2, math.max(m.x0, m.x1) + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover") end end
    return out
end

return TowerLayout
