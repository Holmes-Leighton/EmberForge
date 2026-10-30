-- Builds a Sky Tower from a seed: a stack of levels, each one of the hand-designed LEVEL DESIGNS below (a named idea with its own obstacles and its own look), joined by a
-- climb or a ladder to the next. Levels alternate direction and step sideways, so the tower zig-zags upward and no two levels overlap.
-- Pure maths with no Roblox types: tests prove every jump on every seed, and the server and clients build identical towers from the same seed.
local CourierLayout = require(script.Parent.CourierLayout)
local TowerData     = require(game.ReplicatedStorage.Shared.Data.TowerData)

local TowerLayout = {}

TowerLayout.CLIMB_LEDGES = 8
TowerLayout.CLIMB_RISE   = { 2.9, 3.4, 3.8 }      -- per ledge, by tier: each under that tier's limit (CourierData.Limits), so early climbs are gentle
TowerLayout.LEVEL_RISE   = TowerLayout.CLIMB_LEDGES * 3.4        -- about how far each level goes up (varies a little with the tier)
TowerLayout.LEVEL_Z_STEP = 18           -- each level sits this much further along Z than the one below
TowerLayout.CENTRE_OFFSET = 110       -- the middle of the tower, east of the first level's start
TowerLayout.DRIFT        = 70        -- a level that ends further than this from the middle turns the next one back
TowerLayout.Z_RANGE       = 9         -- how far a level may weave sideways from its middle (it was 0: every level was a dead-straight row)
TowerLayout.Z_PATTERN    = { 0, 1, 2, 1 }    -- the sideways shift (in LEVEL_Z_STEPs) of levels 1, 2, 3, 4, then repeating: always one step from the level below

-- How hard each level is (1 easy .. 3 hard): a sawtooth, not a ramp. Every zone starts a notch easier than the one before ended and builds to its boss level, so there is always a
-- breather and always a peak. A tower with more levels (Pro) stretches this pattern.
TowerLayout.TIER_PATTERN = {
    1, 1, 1, 1, 1, 2,        -- zone 1, Stone: the opener
    1, 2, 1, 2, 2, 3,        -- zone 2, Ember
    2, 1, 2, 2, 3, 3,        -- zone 3, Frost
    2, 2, 3, 2, 3, 3,        -- zone 4, Storm
    2, 3, 2, 3, 3, 3,        -- zone 5, Void
}
function TowerLayout.TierOf(level, total)
    local n = #TowerLayout.TIER_PATTERN
    return TowerLayout.TIER_PATTERN[math.clamp(math.ceil(level / total * n), 1, n)]
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
    -- windmills, vanishing platforms and wall chimneys: the pieces the big tower games are built on
    { name = "Windmill", theme = "metal", tier = 1,
      modules = { { "rotor", { gap = 3.5, radius = 10, arms = 2, omega = 0.45, armWidth = 6, landing = 12, landingWidth = 14 } },
                  { "steps", { n = 2, gap = 4, len = 9, width = 10, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Blink Steps", theme = "glass", tier = 1,
      modules = { { "blink", { n = 5, gap = 3.5, len = 8, width = 9, period = 4.4, duty = 0.72 } },
                  { "steps", { n = 2, gap = 4, len = 9, width = 10, rises = { 0, 1 }, zigs = { 0, 0 } } } } },
    { name = "Chimney Climb", theme = "sandstone", tier = 1,
      modules = { { "chimney", { n = 9, rise = 2.9, len = 4, width = 4, off = 3.6 } } }, connector = {} },
    { name = "Double Windmill", theme = "neon", tier = 2,
      modules = { { "rotor", { gap = 3.5, radius = 10, arms = 2, omega = 0.6, armWidth = 5.5, landing = 8, landingWidth = 14 } },
                  { "rotor", { gap = 4, radius = 10, arms = 3, omega = -0.7, armWidth = 5.5, landing = 10, landingWidth = 14 } } } },
    { name = "Blink Bridge", theme = "glass", tier = 2,
      modules = { { "blink", { n = 7, gap = 4, len = 6, width = 8, period = 3.8, duty = 0.66 } } } },
    { name = "Wall Chimney", theme = "slate", tier = 2,
      modules = { { "chimney", { n = 9, rise = 3.4, len = 4, width = 3.8, off = 3.6 } } }, connector = {} },
    { name = "Walls & Windmill", theme = "metal", tier = 2,
      modules = { { "slalom", { gap = 3, len = 36, width = 20, n = 4, open = 7, wallH = 9 } },
                  { "rotor", { gap = 4, radius = 10, arms = 3, omega = 0.65, armWidth = 5.5, landing = 10, landingWidth = 14 } } } },
    { name = "Vanishing Hurdles", theme = "dark", tier = 2,
      modules = { { "slalom", { gap = 3, len = 26, width = 16, n = 3, hurdle = true, wallH = 3.2 } },
                  { "blink", { n = 4, gap = 4, len = 7, width = 9, period = 3.8, duty = 0.66 } } } },
    { name = "Ice Chimney", theme = "ice", tier = 2,
      modules = { { "chimney", { n = 9, rise = 3.3, len = 4, width = 4, off = 3.6, ice = true } } }, connector = {} },
    { name = "Windmill Gauntlet", theme = "neon", tier = 3,
      modules = { { "rotor", { gap = 4, radius = 11, arms = 3, omega = 0.8, armWidth = 5.5, landing = 8, landingWidth = 14 } },
                  { "sweeper", { gap = 4, len = 32, width = 5, n = 2, amp = 3.5, period = 3.2, stagger = 1.6 } },
                  { "rotor", { gap = 4, radius = 11, arms = 2, omega = -0.8, armWidth = 5, landing = 10, landingWidth = 14 } } } },
    { name = "Blink Run", theme = "dark", tier = 3,
      modules = { { "blink", { n = 9, gap = 4.5, len = 6, width = 7, period = 3.6, duty = 0.62 } },
                  { "pendulum", { gap = 3, len = 28, width = 8, n = 3, period = 2.8, amp = 1.0, stagger = 0.9 } } } },
    { name = "Chimney Storm", theme = "neon", tier = 3,
      modules = { { "chimney", { n = 10, rise = 3.7, len = 3.6, width = 3.6, off = 3.4 } },
                  { "spinner", { gap = 4, len = 30, width = 20, radius = 9, omega = 1.6, bars = 2 } } }, connector = "helix" },
    { name = "Pillar Stairs", theme = "slate", tier = 3,
      modules = { { "steps", { n = 8, gap = 3.5, len = 3.2, width = 3.4, rises = { 3.8, 3.8, 3.8, 3.8, 3.8, 3.8, 3.8, 3.8 }, zigs = { 0, 0, 0, 0, 0, 0, 0, 0 } } } }, connector = {} },
    { name = "Wall Gauntlet", theme = "lava", tier = 3,
      modules = { { "slalom", { gap = 3, len = 46, width = 20, n = 6, open = 5.5, wallH = 10 } },
                  { "pendulum", { gap = 3, len = 30, width = 9, n = 3, period = 2.8, amp = 1.0, stagger = 0.9 } },
                  { "strips", { gap = 4, len = 30, width = 16, n = 3, strip = 2.0 } } } },
    { name = "Frozen Chimney", theme = "ice", tier = 3,
      modules = { { "chimney", { n = 8, rise = 3.8, len = 3.6, width = 3.6, off = 3.4, ice = true } },
                  { "sweeper", { gap = 4, len = 30, width = 5, n = 2, amp = 3.2, period = 3.2, stagger = 1.6 } } }, connector = "helix" },
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

-- ── Boss levels ───────────────────────────────────────────────────────────────
-- The last level of every zone is a hand-made set piece: bigger, with a mechanic that zone is known for, and the way up from it is part of the challenge (a spiral, never
-- a plain staircase). They are not in the shuffled decks: level 6, 12, 18, 24 and 30 always play their zone's boss.
local BOSSES = {
    Stone = { name = "Boulder Run", theme = "sandstone", tier = 2, boss = "Stone",
      modules = { { "slalom", { gap = 3, len = 50, width = 18, n = 6, hurdle = true, wallH = 3.0 } },
                  { "chimney", { n = 6, rise = 3.3, len = 4, width = 4, off = 3.6 } },
                  { "strips", { gap = 4, len = 40, width = 16, n = 5, strip = 2.2 } },
                  { "spinner", { gap = 4, len = 36, width = 24, radius = 10, omega = 1.3, bars = 2 } } },
      connector = "helix" },
    Ember = { name = "Magma Gauntlet", theme = "lava", tier = 3, boss = "Ember",
      modules = { { "bounce", { gap = 4, padLen = 10, width = 12, span = 9, rise = 12, power = 86, hspeed = 28, landLen = 14, landWidth = 14 } },
                  { "sweeper", { gap = 4, len = 40, width = 5, n = 3, amp = 4, period = 3.0, stagger = 1.5 } },
                  { "blink", { n = 6, gap = 4.5, len = 6, width = 8, period = 3.6, duty = 0.64 } },
                  { "killfloor", { gap = 3, pattern = { "..X.X.X..", ".X..X..X.", "X..X..X.." } } },
                  { "spinner", { gap = 4, len = 38, width = 24, radius = 11, omega = 1.8, bars = 2 } } },
      connector = "helix" },
    Frost = { name = "Frozen Spiral", theme = "ice", tier = 3, boss = "Frost",
      modules = { { "ice", { n = 4, gap = 5, len = 7, width = 7, zigs = { 0, 4, -4, 3 } } },
                  { "helix", { gap = 4.5, n = 12, radius = 11.5, width = 6, rise = 3.6, pattern = "iiiiiiiiiiip" } } },
      connector = "none" },
    Storm = { name = "Storm Core", theme = "neon", tier = 3, boss = "Storm",
      modules = { { "beams", { gap = 3, len = 46, width = 28, count = 12, rmin = 1.9, rmax = 2.7, period = 2.6, warn = 1.0, fire = 0.7 } },
                  { "rotor", { gap = 4, radius = 11, arms = 3, omega = 0.8, armWidth = 5.5, landing = 8, landingWidth = 14 } },
                  { "pendulum", { gap = 3, len = 40, width = 8, n = 4, period = 2.8, amp = 1.0, stagger = 0.9 } } },
      connector = "helix" },
    Void = { name = "The Hollow Crown", theme = "dark", tier = 3, boss = "Void",
      modules = { { "killfloor", { gap = 3, pattern = { "X.XX.X.XX", ".X..X..X.", "..X.X.X..", "X.X..XX.X" } } },
                  { "tilefall", { gap = 4, delay = 0.45, pattern = { ".o....", "......", "....o." } } },
                  { "pendulum", { gap = 3, len = 36, width = 8, n = 3, period = 2.8, amp = 1.0, stagger = 0.9 } },
                  { "helix", { gap = 4.5, n = 12, radius = 11.5, width = 6, rise = 3.6, pattern = "cpcpcpcpcppp" } } },
      connector = "none" },
}
TowerLayout.Bosses = BOSSES

-- ── How you get up to the next level ──────────────────────────────────────────
-- Not always a staircase: each level gets a way up of its own, drawn from the kinds below (a design can fix its own, like the ladder levels).
--   ledges: a staircase   helix: a corkscrew of ledges   ladder: a real climb   lifts: two lifts, one after the other
local CONNECTOR_WEIGHTS = {       -- percent, by tier
    [1] = { ledges = 30, helix = 30, ladder = 20, lifts = 20 },
    [2] = { ledges = 25, helix = 30, ladder = 20, lifts = 25 },
    [3] = { ledges = 20, helix = 35, ladder = 20, lifts = 25 },
}
local HELIX_STYLE = {             -- radius and ledge size by tier (searched so the ledges never overlap and every hop is inside that tier's jump limit)
    [1] = { radius = 9.0,  width = 7.0, patterns = { "pppppppp" } },
    [2] = { radius = 8.5,  width = 6.5, patterns = { "ppcppcpp", "pcppcppp", "ppppcppp" } },
    [3] = { radius = 8.5,  width = 6.0, patterns = { "pcpcpcpp", "ppcpcppp", "cpcpppcp" } },
}
local function HelixFor(tier, rng)
    local st = HELIX_STYLE[tier]
    return { "helix", { gap = 3.5, n = 8, radius = st.radius, width = st.width, rise = TowerLayout.CLIMB_RISE[tier], pattern = st.patterns[rng(#st.patterns)],
        delay = tier == 2 and 0.9 or 0.65, cw = rng(2) == 1 } }
end
local function LadderFor(tier)
    return { "ladder", { gap = 3.5, height = 22 + 2 * tier, footLen = 8, landLen = 9, width = 11 } }
end
local function LiftsFor(tier, rng)
    local rise = 11 + tier
    return { "lift", { gap = 2, len = 9, rise = rise, period = 7 - 0.4 * tier, phase = rng(4) * 0.5, landing = 8, width = 10 } },
           { "lift", { gap = 2, len = 9, rise = rise, period = 6.4 - 0.4 * tier, phase = 3 + rng(4) * 0.5, landing = 9, width = 10 } }
end

-- The connector modules for a level, and its kind. `want` forces a kind ("helix" for a boss, "none" when the level's own obstacle is the way up).
local function ConnectorModules(design, tier, rng, want)
    if not want and type(design.connector) == "string" then want = design.connector end         -- (a design can name its way up: "helix", "none")
    if want == "none" then return {}, "none" end
    local kind = want
    if not kind then
        if design.connector then
            local c = design.connector[1] and design.connector[1][1]
            return design.connector, c == "ladder" and "ladder" or "custom"
        end
        local w = CONNECTOR_WEIGHTS[tier]
        local roll, acc = rng(100), 0
        for _, k in ipairs({ "ledges", "helix", "ladder", "lifts" }) do
            acc += w[k]
            if roll <= acc then kind = k break end
        end
    end
    if kind == "helix" then return { HelixFor(tier, rng) }, "helix" end
    if kind == "ladder" then return { LadderFor(tier) }, "ladder" end
    if kind == "lifts" then
        local a, b = LiftsFor(tier, rng)
        return { a, b }, "lifts"
    end
    return { ClimbFor(tier, rng) }, "ledges"
end

-- Which zone a design suits (by its look); metal designs suit any. A zone prefers its own designs and borrows the rest only if it would otherwise run short.
local AFFINITY = { sandstone = "Stone", wood = "Stone", slate = "Stone", lava = "Ember", ice = "Frost", neon = "Storm", glass = "Storm", dark = "Void" }
TowerLayout.MIN_CANDIDATES = 3

local function Candidates(tier, zoneId)
    local mine, all = {}, {}
    for i, d in ipairs(DESIGNS) do
        if d.tier == tier then
            all[#all + 1] = i
            local a = AFFINITY[d.theme]
            if a == nil or a == zoneId then mine[#mine + 1] = i end
        end
    end
    if #mine >= TowerLayout.MIN_CANDIDATES then return mine end
    return all
end
TowerLayout.Candidates = Candidates

-- The designs a (tier, zone) can use, in a shuffled deck: a tower deals from it, so no design repeats until all of them have been used
local function Deck(tier, zoneId, rng)
    local deck = Candidates(tier, zoneId)
    for k = #deck, 2, -1 do
        local j = rng(k)
        deck[k], deck[j] = deck[j], deck[k]
    end
    return deck
end

local function Copy(q) local c = {} for k, v in pairs(q) do c[k] = v end return c end

-- Modules whose `len` can be stretched or shortened without breaking a jump (it only changes how far apart their obstacles are along a long platform)
local SCALABLE = { slalom = true, strips = true, spinner = true, crusher = true, sweeper = true, conveyor = true, beam = true, pendulum = true }
local WEAVES = { steps = true, ice = true }
local function Varied(m, scale, flip, weave)
    local p = Copy(m[2])
    if SCALABLE[m[1]] and p.len then p.len = math.floor(p.len * scale * 2 + 0.5) / 2 end
    local zigs = p.zigs
    local flat = true
    for _, v in ipairs(zigs or {}) do if v ~= 0 then flat = false end end
    if WEAVES[m[1]] and not p.noWeave and weave and (zigs == nil or flat) and (p.width or 8) >= 6 then
        -- a straight row of stepping stones weaves from side to side: positions alternate -a, +a, -a ... (each zig is the move from the last one)
        zigs = { -weave }
        for k = 2, math.max(2, p.n or 4) do zigs[k] = (k % 2 == 0) and 2 * weave or -2 * weave end
    end
    if flip and zigs then
        local z = {}
        for k, v in ipairs(zigs) do z[k] = -v end
        zigs = z
    end
    p.zigs = zigs
    return { m[1], p }
end

-- The kinds of piece a design is made of (its module names), and whether two designs are made of exactly the same kinds
local function KindsOf(design)
    local set = {}
    for _, m in ipairs(design.modules) do set[m[1]] = true end
    return set
end
local function SameKinds(a, b)
    if not (a and b) then return false end
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end
TowerLayout.RECENT = 3         -- a design is not dealt again until this many levels have gone by

-- How big the start platform of a level is: a wide gateway plaza when a new zone begins, a roomy one before a boss, a plain one otherwise
local function RestSize(level, total, rng)
    if level == 1 or TowerData.IsZoneStart(level, total) then return 40, 34 end
    if TowerData.IsBoss(level, total) then return 32, 30 end
    return 22 + 2 * rng(3), 30       -- (wide enough that the previous level's exit, even a small spiral ledge, is always within a step of it sideways)
end

-- opts: { levels = 30, seed = 1, base = { x, y, z } }
function TowerLayout.Build(opts)
    local total, seed = opts.levels or 30, opts.seed or 1
    local base = opts.base or { x = 0, y = 100, z = 0 }
    local rng = Rng(seed)
    local T = { levels = {}, platforms = {}, movers = {}, crumbles = {}, spinners = {}, crushers = {}, checkpoints = {}, levelOfCheckpoint = {},
        trusses = {}, bounces = {}, sweepers = {}, walls = {}, kills = {}, grids = {}, lifts = {}, zmovers = {}, orbiters = {}, pendulums = {}, beamfields = {}, helixes = {}, rotors = {}, blinkers = {},
        base = base, seed = seed, total = total }

    local startX, y, z, dir = base.x, base.y, base.z, 1
    local recent = {}                  -- the last few designs dealt (never dealt again straight away)
    local lastKinds = nil              -- the kinds of piece on the level before (the next one must not be made of the very same)
    local lastModified = false
    local decks = {}
    for i = 1, total do
        local tier = TowerLayout.TierOf(i, total)
        local zoneIndex = TowerData.ZoneOf(i, total)
        local zoneId = TowerData.ZONES[zoneIndex].id
        local boss = TowerData.IsBoss(i, total)
        local design, designKey
        if boss then
            design = BOSSES[zoneId]
            designKey = "boss" .. zoneId
            lastKinds = KindsOf(design)
        else
            local key = tier .. zoneId
            decks[key] = decks[key] or {}
            local pick
            -- deal the next design of this deck (reshuffling when it runs out), but not one seen in the last few levels, and not one made of exactly the same kinds of piece as the
            -- level before; one that does not suit goes back under the pile and comes up again later (after a dozen tries the next one is taken, so a small deck can never stall)
            for attempt = 1, 12 do
                if #decks[key] == 0 then decks[key] = Deck(tier, zoneId, rng) end
                pick = table.remove(decks[key])
                local bad = SameKinds(KindsOf(DESIGNS[pick]), lastKinds)
                for _, r in ipairs(recent) do if r == pick then bad = true end end
                if not bad or attempt == 12 then break end
                table.insert(decks[key], 1, pick)
            end
            table.insert(recent, pick)
            if #recent > TowerLayout.RECENT then table.remove(recent, 1) end
            design = DESIGNS[pick]
            designKey = pick
            lastKinds = KindsOf(design)
        end

        local restLen, restWidth = RestSize(i, total, rng)
        -- the same design looks different from tower to tower and level to level: its long pieces are stretched or shortened, and its sideways weave is mirrored half the time
        local scale = boss and 1 or (0.9 + 0.35 * ((rng(101) - 1) / 100))
        local flip = (not boss) and rng(2) == 1
        local weave = (not boss) and rng(100) <= 70 and (2 + rng(3)) or nil                  -- (a sideways weave for stepping stones, most levels: 3, 4 or 5 studs each way)
        local modules = { { "rest", { len = restLen, width = restWidth } } }
        for _, m in ipairs(design.modules) do modules[#modules + 1] = boss and m or Varied(m, scale, flip, weave) end
        -- a rule twist for this level? (never early, never a boss, never two in a row)
        local modifier
        if not boss and i >= TowerData.LEVEL_MOD_FIRST and i < total and not lastModified and rng(100) <= TowerData.LEVEL_MOD_CHANCE then
            local r = rng(10)
            modifier = (r <= 3 and "moon") or (r <= 6 and "dash") or (r <= 8 and "dark") or "heavy"
        end
        lastModified = modifier ~= nil
        local connectorKind = "top"
        if i < total then
            local want = boss and design.connector or nil
            local conn, kind = ConnectorModules(design, design.tier, rng, want)
            for _, m in ipairs(conn) do modules[#modules + 1] = m end
            connectorKind = kind
        else
            modules[#modules + 1] = { "finish", { gap = 4, len = 32, width = 28 } }
        end
        local layout = CourierLayout.Build({ base = { x = 0, y = y, z = z }, modules = modules, zRange = TowerLayout.Z_RANGE })

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
        put(T.rotors, layout.rotors, function(c, q) c.x = wx(q.x) end)
        put(T.blinkers, layout.blinkers, function(c, q) c.x = wx(q.x) end)
        put(T.helixes, layout.helixes, function(c, q)
            local a, b = wx(q.x1), wx(q.x2)
            c.x1, c.x2 = math.min(a, b), math.max(a, b)
        end)
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
            firstCheckpoint = firstCp, startX = startX, endX = wx(layout.endX), lava = i > total / 3,
            zone = zoneIndex, zoneId = zoneId, boss = boss, modifier = modifier, zoneStart = TowerData.IsZoneStart(i, total), connector = connectorKind, designKey = designKey }
        if layout.finish then T.finish = { x = wx(layout.finish.x), y = layout.finish.y, z = layout.finish.z, hx = layout.finish.hx, hz = layout.finish.hz } end

        startX = wx(layout.endX)
        local lastPlat = layout.platforms[#layout.platforms]
        y = lastPlat.y + lastPlat.sy / 2
        -- the next level starts one step sideways from where this one ended (so the way up always lands on its wide start pad), heading back toward the middle if it has wandered
        local drift = lastPlat.z - base.z
        local sign = (drift > TowerLayout.Z_RANGE) and -1 or ((drift < -TowerLayout.Z_RANGE) and 1 or ((i % 2 == 0) and 1 or -1))
        z = lastPlat.z + sign * TowerLayout.LEVEL_Z_STEP
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

-- The walk order of every piece in level i, for the tests: { x1, x2, top, z, w, kind, viaTruss, viaBounce }. A spiral counts as one piece you climb, like a ladder.
function TowerLayout.WalkOrder(T, level)
    local out = {}
    local function add(x1, x2, top, z, w, kind, src)
        out[#out + 1] = { x1 = math.min(x1, x2), x2 = math.max(x1, x2), top = top, z = z, w = w, kind = kind, viaTruss = src and src.viaTruss, viaBounce = src and src.viaBounce }
    end
    for _, p in ipairs(T.platforms) do if p.level == level and not p.helix and not p.rotor then add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "platform", p) end end
    for _, r in ipairs(T.rotors) do if r.level == level then add(r.x - r.radius, r.x + r.radius, r.y, r.z, 2 * r.radius, "rotor") end end       -- (a windmill is one piece you ride; its hub is not a stepping stone)
    for _, b in ipairs(T.blinkers) do if b.level == level then add(b.x - b.sx / 2, b.x + b.sx / 2, b.y + b.sy / 2, b.z, b.sz, "blink") end end
    for _, p in ipairs(T.crumbles) do if p.level == level and not p.grid and not p.helix then add(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz, "crumble") end end
    for _, h in ipairs(T.helixes) do if h.level == level then add(h.x1, h.x2, h.top, h.z, h.w, "helix", { viaTruss = true }) end end
    for _, g in ipairs(T.grids) do if g.level == level then add(g.x1, g.x2, g.top, g.z, g.w, "grid") end end        -- (a floor of falling tiles counts as one piece)
    for _, m in ipairs(T.movers) do if m.level == level then add(math.min(m.x0, m.x1) - m.sx / 2, math.max(m.x0, m.x1) + m.sx / 2, m.y + m.sy / 2, m.z, m.sz, "mover") end end
    for _, l in ipairs(T.lifts) do if l.level == level then add(l.x - l.sx / 2, l.x + l.sx / 2, l.y0 + l.sy / 2, l.z, l.sz, "lift") end end
    for _, m in ipairs(T.zmovers) do if m.level == level then add(m.x - m.sx / 2, m.x + m.sx / 2, m.y + m.sy / 2, (m.z0 + m.z1) / 2, m.sz + math.abs(m.z1 - m.z0), "zmover") end end
    for _, o in ipairs(T.orbiters) do if o.level == level then add(o.x - o.radius - o.sx / 2, o.x + o.radius + o.sx / 2, o.y + o.sy / 2, o.z, 2 * o.radius + o.sz, "orbit") end end
    return out
end

return TowerLayout
