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
-- Each level pays more than the one below: coins(n) = (0.4 + 0.08 x playerLevel) x n^1.35, at least 1. Level 1 is a handful of coins, level 30 about 100 times that
-- (Tower of Hell's curve). The daily allowance caps coins (XP and Courier Level are not capped), so the tower is not an unlimited faucet.
TowerData.COIN_EXPONENT = 1.35
TowerData.CAP_RUNS      = 30           -- the daily coin allowance is this many "base rewards" (see CourierRewards.DailyCap)
TowerData.TOP_CHEST_MULT = 3           -- the summit chest pays this many times the top level's coins
TowerData.FIRST_SUMMIT_MULT = 2        -- the first summit of the day pays double

function TowerData.LevelCoins(playerLevel, level)
    return math.max(1, math.floor((0.4 + 0.08 * (playerLevel or 1)) * level ^ TowerData.COIN_EXPONENT))
end

-- Materials a level pays, by height. Only every 5th level pays a bundle (so the inventory is not flooded), and the bundle gets better with height.
TowerData.Bundles = {
    { upTo = 10, items = { { id = "BasicOre", qty = 20 }, { id = "Coal", qty = 10 } } },
    { upTo = 20, items = { { id = "RefinedOre", qty = 8 }, { id = "EmberDust", qty = 5 } } },
    { upTo = 99, items = { { id = "ElementalIngot", qty = 3 }, { id = "CrystalFragment", qty = 2 } } },
}
TowerData.BUNDLE_EVERY = 5            -- (clearing a zone pays its own chest on top of this: see TowerData.ZONES)
TowerData.BUNDLES_PER_DAY = 12          -- material bundles are paid for this many levels a day (coins, XP and rare drops carry on); stops farming rounds for ore
-- ── Zones ─────────────────────────────────────────────────────────────────────
-- The tower is five zones, one per Golem element, each a fifth of the climb (six levels of 30). Each has its own colours and sky (MoodData); the last level of a zone is a
-- BOSS level (a hand-made set piece), and clearing a zone pays a chest of that element's material.
TowerData.ZONES = {
    { id = "Stone", name = "Granite Steps",     hue = 0.09, sat = 0.50, val = 0.84, material = { id = "GraniteShard",   qty = 14 } },
    { id = "Ember", name = "Ember Ascent",      hue = 0.03, sat = 0.88, val = 1.00, material = { id = "IgniteOre",      qty = 12 } },
    { id = "Frost", name = "Frostspire",        hue = 0.55, sat = 0.60, val = 0.88, material = { id = "GlacialCrystal", qty = 10 } },
    { id = "Storm", name = "Stormrift Heights", hue = 0.74, sat = 0.62, val = 0.92, material = { id = "ChargedFlint",   qty = 8 } },
    { id = "Void",  name = "The Hollow Crown",  hue = 0.84, sat = 0.78, val = 0.88, material = { id = "ShadowDust",     qty = 6 } },
}
TowerData.ZONE_COUNT = #TowerData.ZONES

-- The zone (1-5) a level is in, for a tower of `total` levels; and the level in its zone (1..size)
function TowerData.ZoneOf(level, total)
    total = total or TowerData.LEVELS
    return math.clamp(math.ceil(level / (total / TowerData.ZONE_COUNT)), 1, TowerData.ZONE_COUNT)
end
function TowerData.ZoneSize(total) return (total or TowerData.LEVELS) / TowerData.ZONE_COUNT end
TowerData.MIN_ZONE_LEVELS = 3          -- a tower too short to give each zone this many levels (the tests' tiny towers) has no boss levels
function TowerData.IsBoss(level, total)
    total = total or TowerData.LEVELS
    if TowerData.ZoneSize(total) < TowerData.MIN_ZONE_LEVELS then return false end
    return level == total or TowerData.ZoneOf(level, total) ~= TowerData.ZoneOf(level + 1, total)
end
function TowerData.IsZoneStart(level, total)
    total = total or TowerData.LEVELS
    return level == 1 or TowerData.ZoneOf(level, total) ~= TowerData.ZoneOf(level - 1, total)
end
-- The zone you have just cleared by reaching `level` (the first level of the next zone), or nil. (The top zone is cleared by the summit.)
function TowerData.ZoneClearedAt(level, total)
    if level > 1 and TowerData.IsZoneStart(level, total) then return TowerData.ZoneOf(level - 1, total) end
    return nil
end
-- A colour for a level: the zone's hue drifts a little across its six levels so you can see yourself climbing
function TowerData.ZoneColor(level, total)
    local z = TowerData.ZONES[TowerData.ZoneOf(level, total)]
    local size = TowerData.ZoneSize(total)
    local k = ((level - 1) % size) / math.max(1, size - 1)
    local h = (z.hue + 0.05 * (k - 0.5)) % 1
    return (Color3 and Color3.fromHSV) and Color3.fromHSV(h, z.sat, z.val) or { h = h, s = z.sat, v = z.val }, h
end
TowerData.ZONE_CHEST_MULT = 3          -- clearing a zone pays this many times the coins of the level you reach
TowerData.ZONE_CHESTS_PER_DAY = 10

-- ── Mutators: one rule twist per round, the same for everyone (picked from the round number) ───────────────────────
-- walk / jump: multipliers on how you move. lava: how much faster the lava rises; lavaFrom: the lava starts chasing from this level. pay: coin multiplier. penalty: seconds
-- added per fall. fog: thick haze (client). Every one is still makeable: faster or higher only helps the jumps, and a faster lava is held to a pace a steady climber beats.
TowerData.Mutators = {
    { id = "classic", name = "Classic Climb",  desc = "No twist. Just you and the tower." },
    { id = "moon",    name = "Moon Jump",      desc = "Everyone jumps 35% higher.",                           jump = 1.35 },
    { id = "turbo",   name = "Turbo",          desc = "Everyone runs 30% faster. Brake in time!",            walk = 1.3 },
    { id = "tide",    name = "Rising Tide",    desc = "The lava chases from level 4 and rises 40% faster.", lava = 1.4, lavaFrom = 4, lavaMin = 0.5 },
    { id = "fog",     name = "Foggy Peaks",    desc = "Thick fog hides what is ahead.",                       fog = true },
    { id = "gold",    name = "Golden Hour",    desc = "Coins pay x1.5, but every fall costs 6 seconds.",      pay = 1.5, penalty = 6 },
}
TowerData.MutatorById = {}
for _, m in ipairs(TowerData.Mutators) do TowerData.MutatorById[m.id] = m end
-- Round n's mutator. Stepping by 5 through six mutators visits every one before repeating and never gives the same one twice in a row.
function TowerData.MutatorForRound(roundIndex)
    return TowerData.Mutators[(roundIndex * 5 + 2) % #TowerData.Mutators + 1]
end

-- What a mutator does to how a climber moves. Walk speed is held below the anti-cheat's limit (CourierData.MIN_SPEED, 40) so a Turbo round never trips it, whatever speed level the
-- player has trained. A jump multiplier is a height multiplier: a humanoid on JumpPower needs its square root (height goes with the square of the power).
TowerData.MAX_WALK = 38
function TowerData.MovementFor(mut, walkSpeed, useJumpPower, jumpPower, jumpHeight)
    mut = mut or {}
    local walk = walkSpeed
    if mut.walk then walk = math.min(walkSpeed * mut.walk, math.max(walkSpeed, TowerData.MAX_WALK)) end
    local power, height = jumpPower, jumpHeight
    if mut.jump then
        if useJumpPower then power = jumpPower * math.sqrt(mut.jump) else height = jumpHeight * mut.jump end
    end
    return walk, power, height
end

-- ── Level twists: about one level in four plays by its own rule, so levels differ in how they FEEL, not only in what is on them ────────────
-- Never on levels 1-2, a boss or the summit, and never two in a row. Each only changes how you move or see (all still makeable: a lower jump is checked against the tier limits).
TowerData.LevelMods = {
    moon  = { id = "moon",  name = "Low Gravity", desc = "Jumps are 40% higher on this level.",              jump = 1.4 },
    dash  = { id = "dash",  name = "Dash Level",  desc = "You run 30% faster on this level.",                walk = 1.3 },
    dark  = { id = "dark",  name = "Lights Out",  desc = "It is dark here. Follow the glow.",                dark = true },
    heavy = { id = "heavy", name = "Heavy Boots", desc = "Jumps are 15% lower on this level. Plan each hop.", jump = 0.85 },
}
TowerData.LEVEL_MOD_CHANCE = 30            -- percent, per eligible level
TowerData.LEVEL_MOD_FIRST  = 3             -- the first level that can have one

-- A level twist and the round's mutator together: speeds and jump heights multiply. Returns a table MovementFor understands, plus fog / dark flags.
function TowerData.CombineMods(a, b)
    local out = {}
    for _, m in ipairs({ a or {}, b or {} }) do
        if m.walk then out.walk = (out.walk or 1) * m.walk end
        if m.jump then out.jump = (out.jump or 1) * m.jump end
        if m.fog then out.fog = true end
        if m.dark then out.dark = true end
    end
    return out
end

-- Skipping a level (a Robux Developer Product, see ProductData): at most this many a round, never from the last level
TowerData.SKIPS_PER_ROUND = 3

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
