-- Sky Tower settings: where it is, how long a round lasts, and what each level pays. See TOWER_DESIGN.md.
local TowerData = {}

TowerData.BASE          = { x = 8000, y = 1500, z = 0 }     -- the first level's start, far above the cavern (nothing else is up there)
TowerData.LEVELS        = 30
TowerData.PORTAL        = { x = -92, z = -22 }               -- the portal in the hub (near the spawn): the world builder keeps rocks off it
TowerData.PORTAL_CLEAR  = 34
TowerData.PRO_LEVELS    = 60
TowerData.PRO_TIME_MULT = 1.4          -- a Pro tower gives this much longer
TowerData.PRO_PAY_MULT  = 2.5

TowerData.ROUND_SECONDS     = 480      -- a round is 8 minutes, like Tower of Hell
TowerData.INTERMISSION      = 25       -- seconds between rounds
TowerData.SUMMIT_SPEEDUP    = 60       -- when someone reaches the top, everyone else has at most this long left
TowerData.MIN_PLAYERS_NOTE  = 1

TowerData.FALL_BELOW        = 30       -- studs below your level's start platform that count as a fall (a tower fall is a long way)
TowerData.LEVEL_MIN_MINIMUM = 4        -- a level can't be reached faster than this many seconds after the one below (cheat check)
TowerData.TOP_MIN_TIME      = 90       -- nobody summits a 30-level tower faster than this (cheat check); scaled by level count

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

-- A fresh seed for each round, the same on every server for the same clock time so friends in different servers can compare towers
function TowerData.SeedForRound(roundIndex)
    return (roundIndex * 7919 + 104729) % 1000003
end

return TowerData
