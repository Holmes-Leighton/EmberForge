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
MazeData.WALL_H   = 26                                      -- studs: too tall to jump or see over (the camera is also held close while you are in the maze)
MazeData.WALL_T   = 2                                       -- studs thick
MazeData.ROOF_H   = 27                                      -- the roof (so nobody can look down on the maze or climb out)
-- the share of each section's dead ends that are opened into loops, so the maze has loops to run round (Stone has the most, Void the least)
MazeData.BRAID    = { 0.45, 0.38, 0.30, 0.22, 0.15 }

-- ── The round ─────────────────────────────────────────────────────────────────
MazeData.GATHER_SECONDS    = 20     -- players arrive; the gate is shut
MazeData.HEADSTART_SECONDS = 25     -- the gate opens; the Zombie Golem sleeps
MazeData.LATE_ENTRY_CUTOFF = 60     -- you can still walk in until this many seconds before the hunt ends (most players arrive mid-round, so a short entry window left the portal shut most of the time)
MazeData.HUNT_SECONDS      = 300    -- the longest a hunt lasts
MazeData.INTERMISSION      = 25
MazeData.ESCAPE_SPEEDUP    = 45     -- once someone escapes, the hunt has at most this long left

-- ── The Zombie Golem ──────────────────────────────────────────────────────────
MazeData.PLAYER_SPEED    = 16       -- studs/s: Roblox's default walk speed
MazeData.ZOMBIE_START    = 0.70     -- of PLAYER_SPEED when it wakes
MazeData.ZOMBIE_END      = 1.12     -- of PLAYER_SPEED by the end of a full-length hunt (a little faster than you, so a perfect runner is never safe for ever)
MazeData.CATCH_RADIUS    = 5        -- studs
MazeData.WARN_RADIUS     = 55       -- studs: the screen-edge warning starts this close

-- ── What the Zombie Golem can hear ───────────────────────────────────────────
-- It is no longer all-knowing. It hunts what it can HEAR: a running player is heard from far along the corridors, a walking one from half as far, and one standing still
-- (or hiding, or cloaked) only when it practically bumps into them. It remembers where it last heard someone for a few seconds, then goes back to patrolling the way to the exit.
MazeData.HEAR_RUN        = 170      -- studs along the corridors
MazeData.HEAR_WALK       = 80
MazeData.HEAR_STILL      = 16
MazeData.HIDE_FIND       = 9        -- a hiding player is found only this close (straight line)
MazeData.CLOAK_FIND      = 10       -- ... and so is a cloaked one
MazeData.RUN_FRACTION    = 0.6      -- moving faster than this share of walk speed counts as running
MazeData.WALK_FRACTION   = 0.15     -- ... slower than this is standing still
MazeData.MEMORY          = 7        -- seconds it keeps heading for the place it last heard someone
MazeData.SNIFF           = 1.2      -- seconds it stops to sniff at a decoy flare it has reached

-- ── Items: one in each section's colour, picked up from glowing orbs and used with a button ─────────────────────────────────
-- Each lets you do something about the Zombie Golem other than run. You carry one at a time; picking up another when your hands are full does nothing.
MazeData.ITEMS = {
    Stone = { id = "sprint", name = "Sprint Tonic",  desc = "Run 35% faster for 5 seconds.",                              seconds = 5,   speed = 1.35, color = { 190, 175, 150 } },
    Ember = { id = "flare",  name = "Decoy Flare",   desc = "Throws a flare: the Zombie Golem goes for it for 7 seconds.", seconds = 7,   color = { 255, 140, 60 } },
    Frost = { id = "freeze", name = "Frost Snap",    desc = "Slows the Zombie Golem to 40% for 6 seconds.",               seconds = 6,   slow = 0.4, color = { 140, 210, 255 } },
    Storm = { id = "stun",   name = "Storm Jolt",    desc = "Stuns the Zombie Golem for 3.5 seconds.",                    seconds = 3.5, color = { 200, 170, 255 } },
    Void  = { id = "cloak",  name = "Void Cloak",    desc = "The Zombie Golem can barely sense you for 6 seconds.",       seconds = 6,   color = { 150, 90, 230 } },
}
MazeData.ItemById = {}
for section, item in pairs(MazeData.ITEMS) do
    item.section = section
    MazeData.ItemById[item.id] = item
end
MazeData.PICKUPS_PER_SECTION = 2
MazeData.PICKUP_RADIUS       = 5        -- studs: walk into the orb
MazeData.PICKUP_RESPAWN      = 35       -- seconds until a taken orb comes back
MazeData.SPRINT_MAX_WALK     = 38       -- (held under the anti-cheat's limit, like the Tower's Turbo)

-- ── Hiding places: crates in dead ends. Press E to climb in; the Zombie Golem finds you only if it comes right up to the crate. ───────────────────
MazeData.HIDEOUTS_PER_SECTION = { 1, 1, 2, 2, 2 }
MazeData.HIDE_MAX      = 8              -- seconds you can stay in before being pushed out
MazeData.HIDE_COOLDOWN = 10             -- seconds before you can hide again

-- ── Rooms: each section has one open room (3 x 3 cells) with a pillar in the middle, so you can circle it and shake the Zombie Golem off ──────────
MazeData.ROOM_SIZE = 3

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
MazeData.ESCAPE_MIN_TIME = 20       -- nobody escapes faster than this: the shortest route of any maze is about 60 cells = 840 studs, which is 53 s at the default walk speed and 22 s at the top speed level on a Sprint Tonic (38)

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

-- ── The Maze Golem: the long-term goal ───────────────────────────────────────────
-- The maze is the only place the pieces of a Maze Golem are found, one kind per section. It takes PIECE_NEED of each of the five to craft one (Forge level for Tier 5), the pieces are
-- bound to the account (not tradable), and at most PIECE_CAP_PER_DAY can be found in a day, so even a player who runs the maze every day needs weeks. A section's piece drops from
-- clearing that section; the escape chest can drop any piece you still need. A "pity" counter guarantees a drop after PIECE_PITY section clears with none.
MazeData.PIECES = {                       -- index = the section it comes from
    { id = "MazeFoot",  name = "Maze Golem Foot",  section = "Stone" },
    { id = "MazeHeart", name = "Maze Golem Heart", section = "Ember" },
    { id = "MazePick",  name = "Maze Golem Pickaxe",  section = "Frost" },
    { id = "MazeEye",   name = "Maze Golem Eye",   section = "Storm" },
    { id = "MazeCrown", name = "Maze Golem Crown", section = "Void" },
}
MazeData.PIECE_NEED        = 6             -- of each piece (30 in all) per Maze Golem (it was 12 of each: weeks of nothing to show)
MazeData.PIECE_CAP_PER_DAY = 3
MazeData.PIECE_CHANCE      = { 0.015, 0.02, 0.025, 0.03, 0.04 }   -- per section clear (deeper is better)
MazeData.PIECE_ESCAPE      = 0.07          -- the escape chest
MazeData.PIECE_PITY        = 30            -- section clears with no piece before one is guaranteed
MazeData.PIECE_BLUEPRINT   = "BP_Maze_T5"  -- found with the first piece, so the recipe shows your progress
-- Early wins: the very first piece is guaranteed the first time you reach this section (or escape), and every few pieces along the way pay a cache, so the long chase is full of rewards.
MazeData.PIECE_FIRST_SECTION = 3
MazeData.PIECE_MILESTONES = {            -- pieces found in total -> what you are paid
    [3]  = { coins = 400,  items = { { id = "ElementalIngot", qty = 3 } } },
    [10] = { coins = 1500, items = { { id = "EssenceShard", qty = 4 } } },
    [20] = { coins = 4000, items = { { id = "EssenceShard", qty = 8 }, { id = "PrimordialIngot", qty = 3 } } },
    [30] = { coins = 10000, items = { { id = "PrimordialIngot", qty = 8 } } },
}

function MazeData.PieceIndex(id)
    for i, p in ipairs(MazeData.PIECES) do if p.id == id then return i end end
    return nil
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
