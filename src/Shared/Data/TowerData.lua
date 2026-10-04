-- Sky Tower settings: where it is, how long a round lasts, and what each level pays. See TOWER_DESIGN.md.
local TowerData = {}

TowerData.BASE          = { x = 8000, y = 1500, z = 0 }     -- the first level's start, far above the cavern (nothing else is up there)
TowerData.LEVELS        = 30
TowerData.PORTAL        = { x = -92, z = -22 }               -- the portal in the hub (near the spawn): the world builder keeps rocks off it
TowerData.PORTAL_CLEAR  = 34
TowerData.PRO_LEVELS    = 60
TowerData.PRO_TIME_MULT = 1.4          -- a Pro tower gives this much longer
TowerData.PRO_PAY_MULT  = 2.5

TowerData.ROUND_SECONDS     = 600      -- a round is 10 minutes (Tower of Hell has 8, but our levels have longer climbs)
TowerData.INTERMISSION      = 25       -- seconds between rounds
TowerData.SUMMIT_SPEEDUP    = 60       -- when someone reaches the top, everyone else has at most this long left
TowerData.MIN_PLAYERS_NOTE  = 1

TowerData.FALL_BELOW        = 30       -- studs below your level's start platform that count as a fall (a tower fall is a long way)
TowerData.LEVEL_MIN_MINIMUM = 4        -- a level can't be reached faster than this many seconds after the one below (cheat check)
TowerData.TOP_MIN_TIME      = 90       -- nobody summits a 30-level tower faster than this (cheat check); scaled by level count

-- Lava from level 11 up: a glowing sea that rises under you once you arrive at a level (a head start of LAVA_HEAD studs below the level's start platform), so you can't dawdle.
-- Rising speed by tier, in studs per second. A player at 6 studs/s (the tests' slow walker) stays ahead; a crawler does not.
TowerData.LAVA_HEAD   = 34
TowerData.LAVA_RISE   = { 0, 0.6, 0.85 }
TowerData.RESPAWN_PENALTY = 3          -- seconds added to your summit time for each fall or lava hit
TowerData.PAR_SECONDS_PER_LEVEL = 16   -- a summit under this x the number of levels is Gold (30 levels: 8:00, so only a quick climber gets it inside the round)
TowerData.GATE_LEVEL    = 3            -- the player level that unlocks the tower (FeatureGates)

-- ── Rewards ───────────────────────────────────────────────────────────────────
-- Each level pays more than the one below: coins(n) = (1 + 0.2 x playerLevel) x n^1.35. Level 1 is a handful of coins, level 30 about 100 times that
-- (Tower of Hell's curve). The daily allowance caps coins (XP and Courier Level are not capped), so the tower is not an unlimited faucet.
TowerData.COIN_EXPONENT = 1.35
TowerData.CAP_RUNS      = 70           -- the daily coin allowance is this many "base rewards" (see CourierRewards.DailyCap)
TowerData.TOP_CHEST_MULT = 3           -- the summit chest pays this many times the top level's coins
TowerData.FIRST_SUMMIT_MULT = 2        -- the first summit of the day pays double

function TowerData.LevelCoins(playerLevel, level)
    return math.floor((1 + 0.2 * (playerLevel or 1)) * level ^ TowerData.COIN_EXPONENT)
end

-- Materials a level pays, by height. Only every 5th level pays a bundle (so the inventory is not flooded), and the bundle gets better with height.
TowerData.Bundles = {
    { upTo = 10, items = { { id = "BasicOre", qty = 20 }, { id = "Coal", qty = 10 } } },
    { upTo = 20, items = { { id = "RefinedOre", qty = 8 }, { id = "EmberDust", qty = 5 } } },
    { upTo = 99, items = { { id = "ElementalIngot", qty = 3 }, { id = "CrystalFragment", qty = 2 } } },
}
TowerData.BUNDLE_EVERY = 5
TowerData.BUNDLES_PER_DAY = 12          -- material bundles are paid for this many levels a day (coins, XP and rare drops carry on); stops farming rounds for ore
TowerData.RareChanceBase, TowerData.RareChancePerLevel = 0.02, 0.004       -- per level reached, rising with height
TowerData.RareDrops = {
    { upTo = 10, id = "RefinedOre", qty = 4 },
    { upTo = 20, id = "ElementalIngot", qty = 2 },
    { upTo = 99, id = "EssenceShard", qty = 2 },
}

function TowerData.BundleFor(level)
    for _, b in ipairs(TowerData.Bundles) do if level <= b.upTo then return b.items end end
    return TowerData.Bundles[#TowerData.Bundles].items
end

function TowerData.RareFor(level)
    for _, r in ipairs(TowerData.RareDrops) do if level <= r.upTo then return r end end
    return TowerData.RareDrops[#TowerData.RareDrops]
end

-- Courier XP for reaching a level: more on the higher ones
function TowerData.LevelXp(level, total)
    local tier = math.min(3, 1 + math.floor((level - 1) / (total / 3)))
    return 4 * tier
end

-- Main player XP (the XP that levels you up and unlocks features) for reaching a tower level and for the summit. A level is worth about as much as a
-- Tier 1 craft at the bottom (50 XP for a craft; a level here is 10) and a good deal more near the top; a full climb is about 1,200 XP plus 300 for the summit.
function TowerData.PlayerXp(level)
    return 8 + 2 * level
end
TowerData.SUMMIT_PLAYER_XP = 300

-- The daily challenge: one target level a day, in a weekly rotation (a gentle early week, a hard weekend). Reaching it earns a bonus chest, once a day.
TowerData.DAILY_TARGETS = { 10, 14, 18, 22, 12, 26, 30 }
TowerData.DAILY_COIN_MULT = 4          -- the chest pays this many times the target level's coins
function TowerData.DailyTarget(day, total)
    return math.min(total or TowerData.LEVELS, TowerData.DAILY_TARGETS[(day % #TowerData.DAILY_TARGETS) + 1])
end

-- A fresh seed for each round, the same on every server for the same clock time so friends in different servers can compare towers
function TowerData.SeedForRound(roundIndex)
    return (roundIndex * 7919 + 104729) % 1000003
end

return TowerData
