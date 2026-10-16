-- The Hollow Maze settings: where it is, how it is shaped, how a round runs, how the Zombie Golem hunts, and what it pays. See MAZE_DESIGN.md.
local MazeData = {}

MazeData.BASE         = { x = -8000, y = 1500, z = 0 }     -- the west end of the maze, far from the cavern (the Sky Tower is at x = +8000)
MazeData.PORTAL       = { x = -92, z = 22 }                 -- the portal in the hub (opposite the Sky Tower's): the world builder keeps rocks off it
MazeData.PORTAL_CLEAR = 34
MazeData.GATE_LEVEL   = 4                                   -- the player level that opens the maze

-- ── Shape ─────────────────────────────────────────────────────────────────────
MazeData.SECTIONS = { "Stone", "Ember", "Frost", "Storm", "Void" }     -- west to east, gentle to fierce; each is one Golem element
MazeData.COLS     = 8                                       -- cells across one section
MazeData.ROWS     = 10                                      -- cells down the maze
MazeData.CELL     = 14                                      -- studs
MazeData.WALL_H   = 16                                      -- studs: too tall to jump or see over
MazeData.WALL_T   = 2                                       -- studs thick
MazeData.ROOF_H   = 19                                      -- the roof (so nobody can look down on the maze or climb out)
-- the share of each section's dead ends that are opened into loops, so the maze has loops to run round (Stone has the most, Void the least)
MazeData.BRAID    = { 0.45, 0.38, 0.30, 0.22, 0.15 }

-- ── The round ─────────────────────────────────────────────────────────────────
MazeData.GATHER_SECONDS    = 20     -- players arrive; the gate is shut
MazeData.HEADSTART_SECONDS = 25     -- the gate opens; the Zombie Golem sleeps
MazeData.HUNT_SECONDS      = 300    -- the longest a hunt lasts
MazeData.INTERMISSION      = 25
MazeData.ESCAPE_SPEEDUP    = 45     -- once someone escapes, the hunt has at most this long left

-- ── The Zombie Golem ──────────────────────────────────────────────────────────
MazeData.PLAYER_SPEED    = 16       -- studs/s: Roblox's default walk speed
MazeData.ZOMBIE_START    = 0.70     -- of PLAYER_SPEED when it wakes
MazeData.ZOMBIE_END      = 1.05     -- of PLAYER_SPEED by the end of a full-length hunt
MazeData.CATCH_RADIUS    = 5        -- studs
MazeData.WARN_RADIUS     = 55       -- studs: the screen-edge warning starts this close

function MazeData.ZombieSpeed(huntElapsed)
    local f = math.clamp(huntElapsed / MazeData.HUNT_SECONDS, 0, 1)
    return MazeData.PLAYER_SPEED * (MazeData.ZOMBIE_START + (MazeData.ZOMBIE_END - MazeData.ZOMBIE_START) * f)
end

-- A player trained up their movement speed (SpeedData): the Zombie Golem keeps pace with the player it is hunting, but only for part of the extra, so speed
-- still helps. With ZOMBIE_FOLLOW 0.6 a player 50% faster than normal is hunted by a Zombie 30% faster than normal.
MazeData.ZOMBIE_FOLLOW = 0.6
function MazeData.ZombieScale(walkSpeed)
    return math.max(0.5, 1 + MazeData.ZOMBIE_FOLLOW * ((walkSpeed or MazeData.PLAYER_SPEED) / MazeData.PLAYER_SPEED - 1))
end

-- ── Anti-cheat ────────────────────────────────────────────────────────────────
MazeData.MAX_SPEED       = 70       -- studs/s a player may move before it counts as a teleport (generous: the top speed level walks at 36, plus jumping, slopes and lag)
MazeData.ESCAPE_MIN_TIME = 24       -- nobody escapes faster than this: the shortest route of any maze is 70 cells = 980 studs, which is 61 s at the default walk speed and 27 s at the top speed level (36)

-- ── Rewards ───────────────────────────────────────────────────────────────────
-- Reaching section n pays coins(n) = (1.5 + 0.3 x playerLevel) x n^1.5 (at least 1). Section 5 pays about 11 x section 1. At player level 10 a full first run of the
-- day pays about 430 coins (about six of them reach the daily allowance); XP and the leaderboard are not capped, so the maze is not an unlimited faucet.
MazeData.COIN_EXPONENT   = 1.5
MazeData.CAP_RUNS        = 30       -- the daily coin allowance, in "base rewards" (see CourierRewards.DailyCap)
MazeData.ESCAPE_CHEST_MULT = 3      -- the escape chest pays this many times the last section's coins
MazeData.FIRST_ESCAPE_MULT = 2      -- the first escape of the day pays double

function MazeData.SectionCoins(playerLevel, section)
    return math.max(1, math.floor((1.5 + 0.3 * (playerLevel or 1)) * section ^ MazeData.COIN_EXPONENT))
end

-- Each section's own material (the element's primary material, GolemData.Elements): a small bundle for reaching it, paid for a limited number of sections a day
MazeData.Bundles = {
    Stone = { id = "GraniteShard",   qty = 12 },
    Ember = { id = "IgniteOre",      qty = 10 },
    Frost = { id = "GlacialCrystal", qty = 8 },
    Storm = { id = "ChargedFlint",   qty = 6 },
    Void  = { id = "ShadowDust",     qty = 5 },
}
MazeData.BUNDLES_PER_DAY = 15
MazeData.RareChance = 0.06                 -- per section reached, rising a little with depth
MazeData.RareDrops = { { upTo = 2, id = "RefinedOre", qty = 4 }, { upTo = 4, id = "ElementalIngot", qty = 2 }, { upTo = 5, id = "EssenceShard", qty = 2 } }

function MazeData.RareFor(section)
    for _, r in ipairs(MazeData.RareDrops) do if section <= r.upTo then return r end end
    return MazeData.RareDrops[#MazeData.RareDrops]
end

-- Main player XP (the XP that levels you up) for reaching a section and for escaping
function MazeData.PlayerXp(section) return 12 + 6 * section end
MazeData.ESCAPE_PLAYER_XP = 250

-- Escape medals by time (seconds from the gate opening): a quick run is Gold
MazeData.MEDALS = { gold = 125, silver = 170, bronze = 230 }       -- routes are 70 to 180 cells (60 to 160 s of perfect running)
function MazeData.Medal(seconds)
    if seconds <= MazeData.MEDALS.gold then return "Gold" end
    if seconds <= MazeData.MEDALS.silver then return "Silver" end
    if seconds <= MazeData.MEDALS.bronze then return "Bronze" end
    return nil
end

-- The daily challenge: one section to reach a day (a weekly rotation); reaching it pays a bonus chest once a day
MazeData.DAILY_TARGETS = { 2, 3, 3, 4, 2, 5, 5 }
MazeData.DAILY_COIN_MULT = 3
function MazeData.DailyTarget(day)
    return MazeData.DAILY_TARGETS[(day % #MazeData.DAILY_TARGETS) + 1]
end

-- A fresh seed for each round, the same on every server for the same clock time
function MazeData.SeedForRound(roundIndex)
    return (roundIndex * 6007 + 90001) % 1000003
end

return MazeData
