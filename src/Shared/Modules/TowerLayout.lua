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
                  { "beam", { gap = 4.5, len = 24, width = 3.2, pipe = true } },
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
      modules = { { "beam", { gap = 4, len = 18, width = 3.2, pipe = true } },
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

    -- pipes: balance on round steel pipes
    { name = "Pipe Walk", theme = "metal", tier = 2,
      modules = { { "beam", { gap = 3.5, len = 30, width = 4, pipe = true } },
                  { "steps", { n = 2, gap = 4.5, len = 8, width = 9, rises = { 0, 1 }, zigs = { 0, 0 } } },
                  { "beam", { gap = 4.5, len = 22, width = 4, pipe = true } } } },
    { name = "Pipe Run", theme = "dark", tier = 3,
      modules = { { "beam", { gap = 4, len = 26, width = 3.4, pipe = true } },
                  { "crumble", { n = 3, gap = 5, len = 6.5, width = 7, delay = 0.55 } },
                  { "beam", { gap = 5, len = 22, width = 3.2, pipe = true } } },
      connector = { { "ladder", { gap = 3.5, height = 26, footLen = 8, landLen = 9, width = 11 } } } },

    -- the floor fights you: death tiles, falling floors, multi-bar spinners
    { name = "Red Tiles", theme = "dark", tier = 1,
      modules = { { "killfloor", { gap = 3, pattern = { ".X.X..", "..X..X", "X..X.." } } } } },
    { name = "Tile Maze", theme = "lava", tier = 2,
      modules = { { "killfloor", { gap = 3, pattern = { "..XX.X.X", ".X..X.X.", "X.X..X..", ".X.X...X" } } } } },
    { name = "Falling Floor", theme = "wood", tier = 2,
      modules = { { "tilefall", { gap = 3.5, delay = 0.55, pattern = { "......", "......", "......" } } } } },
    { name = "Double Spinner", theme = "neon", tier = 2,
      modules = { { "spinner", { gap = 3.5, len = 36, width = 24, radius = 10, omega = 1.3, bars = 2 } } } },
    { name = "Kill & Fall", theme = "dark", tier = 2,
      modules = { { "killfloor", { gap = 3, pattern = { ".X..X.", "..X..X", "X..X.." } } },
                  { "tilefall", { gap = 3.5, delay = 0.5, pattern = { ".....", ".....", "....." } } } } },
    { name = "Death Floor", theme = "lava", tier = 3,
      modules = { { "killfloor", { gap = 3, pattern = { "X.XX.X.XX", ".X..X..X.", "..X.X.X..", "X.X..XX.X" } } } } },
    { name = "Fall & Spin", theme = "slate", tier = 3,
      modules = { { "tilefall", { gap = 4, delay = 0.45, pattern = { ".o....", "......", "....o." } } },
                  { "spinner", { gap = 4, len = 34, width = 22, radius = 9, omega = 1.7, bars = 2 } } } },
    { name = "Triple Spinner", theme = "neon", tier = 3,
      modules = { { "spinner", { gap = 4, len = 38, width = 26, radius = 11, omega = 1.5, bars = 3 } } } },
    -- moving platforms in every direction, swinging blades and beam pads
    { name = "Lift Shaft", theme = "metal", tier = 2,
      modules = { { "lift", { gap = 2, len = 9, rise = 10, period = 7, landing = 9, width = 10 } },
                  { "steps", { n = 2, gap = 4.5, len = 8, width = 9, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Elevator Hop", theme = "neon", tier = 3,
      modules = { { "lift", { gap = 2, len = 8, rise = 12, period = 6, landing = 7, width = 9 } },
                  { "lift", { gap = 2, len = 8, rise = 12, period = 5.4, phase = 2.7, landing = 8, width = 9 } } } },
    { name = "Side Swipe", theme = "wood", tier = 2,
      modules = { { "zmover", { len = 8, width = 8, amp = 5, period = 6, landing = 8 } },
                  { "steps", { n = 2, gap = 4.5, len = 8, width = 9, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Back & Forth", theme = "slate", tier = 3,
      modules = { { "zmover", { len = 7, width = 7, amp = 6, period = 5, landing = 6 } },
                  { "zmover", { len = 7, width = 7, amp = 6, period = 4.6, phase = 2.3, landing = 8 } } } },
    { name = "Carousel", theme = "neon", tier = 2,
      modules = { { "orbit", { radius = 8, len = 8, width = 8, omega = 0.5, landing = 9 } },
                  { "steps", { n = 2, gap = 4.5, len = 8, width = 9, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Orbit Ring", theme = "lava", tier = 3,
      modules = { { "orbit", { radius = 10, len = 7, width = 7, omega = 0.75, landing = 8 } },
                  { "orbit", { radius = 8, len = 7, width = 7, omega = -0.85, landing = 8 } } } },
    { name = "Blade Swing", theme = "metal", tier = 2,
      modules = { { "pendulum", { gap = 3, len = 34, width = 9, n = 3, period = 3.4, amp = 0.9 } } } },
    { name = "Axe Alley", theme = "dark", tier = 3,
      modules = { { "pendulum", { gap = 3, len = 40, width = 8, n = 4, period = 2.8, amp = 1.0, stagger = 0.9 } },
                  { "mover", { span = 26, len = 8, width = 9, period = 5, landing = 9, landingWidth = 10 } } } },
    { name = "Beam Pads", theme = "neon", tier = 2,
      modules = { { "beams", { gap = 3, len = 36, width = 24, count = 8, rmin = 2.2, rmax = 3.0, period = 3.2, warn = 1.4, fire = 0.7 } } } },
    { name = "Laser Grid", theme = "dark", tier = 3,
      modules = { { "beams", { gap = 3, len = 44, width = 26, count = 11, rmin = 1.9, rmax = 2.7, period = 2.6, warn = 1.0, fire = 0.7 } },
                  { "steps", { n = 2, gap = 4.5, len = 8, width = 9, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Kill Sweep", theme = "metal", tier = 3,
      modules = { { "killfloor", { gap = 3, pattern = { ".X.X.X", "X.X..X", ".X..X." } } },
                  { "sweeper", { gap = 4, len = 32, width = 5, n = 2, amp = 3.5, period = 3.0, stagger = 1.5 } } } },

    -- walls to hurdle or weave round, and bright yellow strips that kill on touch
    { name = "Hurdle Run", theme = "sandstone", tier = 1,
      modules = { { "slalom", { gap = 3, len = 34, width = 14, n = 5, hurdle = true, wallH = 2.4 } } } },
    { name = "Yellow Strips", theme = "metal", tier = 1,
      modules = { { "strips", { gap = 3, len = 36, width = 16, n = 4, strip = 2.4 } },
                  { "steps", { n = 2, gap = 4, len = 9, width = 10, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Wall Weave", theme = "slate", tier = 2,
      modules = { { "slalom", { gap = 3, len = 40, width = 22, n = 4, open = 7, wallH = 9 } } } },
    { name = "Hazard Strips", theme = "dark", tier = 2,
      modules = { { "strips", { gap = 3, len = 44, width = 18, n = 6, strip = 2.2 } } } },
    { name = "Hurdles & Strips", theme = "wood", tier = 2,
      modules = { { "slalom", { gap = 3, len = 28, width = 16, n = 3, hurdle = true, wallH = 3.2 } },
                  { "strips", { gap = 4, len = 30, width = 16, n = 3, strip = 2.2 } } } },
    { name = "Wall Maze", theme = "lava", tier = 3,
      modules = { { "slalom", { gap = 3, len = 50, width = 20, n = 6, open = 5.5, wallH = 10 } },
                  { "sweeper", { gap = 4, len = 26, width = 8, n = 2, amp = 2.5, period = 3.0, stagger = 1.5 } } } },
    { name = "Strip Gauntlet", theme = "neon", tier = 3,
      modules = { { "strips", { gap = 3, len = 54, width = 14, n = 8, strip = 2.0 } } } },
    { name = "Weave & Hurdle", theme = "glass", tier = 3,
      modules = { { "slalom", { gap = 3, len = 40, width = 20, n = 4, open = 6, wallH = 10 } },
                  { "slalom", { gap = 4, len = 34, width = 18, n = 4, hurdle = true, wallH = 3.5 } } } },
}
TowerLayout.Designs = DESIGNS

-- How you climb up to the next level (when a design has no ladder of its own). Tier 1 is plain ledges; higher tiers mix in narrow ledges and ledges that crumble under you
-- ("p" plain, "n" narrow, "c" crumbling; the last is always plain). Every ledge stays inside that tier's jump limits (CourierData.Limits).
local CLIMBS = {
    [1] = { { pattern = "pppppppp", gap = 3.2, len = 7, width = 8 } },
    [2] = { { pattern = "pcpcpcpp", gap = 4.2, len = 6, width = 8, delay = 1.0 },
            { pattern = "nnpnnpnp", gap = 4.4, len = 5.5, width = 8, narrow = 5 },
            { pattern = "pcnpcnpp", gap = 4.2, len = 6, width = 8, narrow = 5, delay = 1.0 } },
    [3] = { { pattern = "ccnccnpp", gap = 5.0, len = 5, width = 7, narrow = 4, delay = 0.65 },
            { pattern = "ncncncnp", gap = 5.0, len = 5, width = 7, narrow = 4, delay = 0.65 },
            { pattern = "cnccnccp", gap = 5.2, len = 4.6, width = 7, narrow = 4, delay = 0.6 } },
}
local function ClimbFor(tier, rng)
    local styles = CLIMBS[tier]
    local s = styles[rng(#styles)]
    return { "climbmix", { pattern = s.pattern, gap = s.gap, rise = TowerLayout.CLIMB_RISE[tier], len = s.len, width = s.width, narrow = s.narrow, delay = s.delay } }
end

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
        trusses = {}, bounces = {}, sweepers = {}, walls = {}, kills = {}, grids = {}, lifts = {}, zmovers = {}, orbiters = {}, pendulums = {}, beamfields = {}, base = base, seed = seed, total = total }

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
                modules[#modules + 1] = ClimbFor(design.tier, rng)
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
        put(T.walls, layout.walls, function(c, q) c.x = wx(q.x) end)
        put(T.kills, layout.kills, function(c, q) c.x = wx(q.x) end)
        put(T.lifts, layout.lifts, function(c, q) c.x = wx(q.x) end)
        put(T.zmovers, layout.zmovers, function(c, q) c.x = wx(q.x) end)
        put(T.orbiters, layout.orbiters, function(c, q) c.x = wx(q.x) end)
        put(T.pendulums, layout.pendulums, function(c, q) c.x = wx(q.x) end)
        put(T.beamfields, layout.beamfields, function(c, q)
            c.x1, c.x2 = wx(q.x1), wx(q.x2)
            c.circles = {}
            for k, ci in ipairs(q.circles) do c.circles[k] = { x = wx(ci.x), z = ci.z, r = ci.r } end
        end)
        put(T.grids, layout.grids, function(c, q) c.x1, c.x2 = wx(q.x1), wx(q.x2) end)
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
    for _, p in ipairs(T.crumbles) do if p.level == level and not p.grid then add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "crumble") end end
    for _, g in ipairs(T.grids) do if g.level == level then add(g.x1, g.x2, g.top, g.z, g.w, "grid") end end        -- (a floor of falling tiles counts as one piece)
    for _, m in ipairs(T.movers) do if m.level == level then add(math.min(m.x0, m.x1) - m.sx / 2, math.max(m.x0, m.x1) + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover") end end
    for _, l in ipairs(T.lifts) do if l.level == level then add(l.x - l.sx / 2, l.x + l.sx / 2, l.y0 + l.sy / 2, l.z, l.sz, "lift") end end
    for _, m in ipairs(T.zmovers) do if m.level == level then add(m.x - m.sx / 2, m.x + m.sx / 2, m.y + m.sy / 2, (m.z0 + m.z1) / 2, m.sz + math.abs(m.z1 - m.z0), "zmover") end end
    for _, o in ipairs(T.orbiters) do if o.level == level then add(o.x - o.radius - o.sx / 2, o.x + o.radius + o.sx / 2, o.y + o.sy / 2, o.z, 2 * o.radius + o.sz, "orbit") end end
    return out
end

return TowerLayout
