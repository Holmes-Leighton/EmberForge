-- Mining pads: stand on one to gather materials every second.
-- Higher pads multiply the yield and unlock with player level.
local PadData = {}

-- position is relative to the world origin (Y is the ground). Row 1 is right by spawn.
-- The 1x / 3x / 9x / 25x / 100x ladder follows +1 Speed Keyboard Escape's treadmills (free,
-- then 59 / 259 / 749 / 1,599 R$). Here a level also unlocks each pad for free.
PadData.Pads = {
    -- speedCap: the highest movement-speed level this pad can train you to (see SpeedData)
    { id = "Starter", displayName = "Starter Pad", multiplier = 1,   minLevel = 1,  speedCap = 40,
      color = Color3.fromRGB(200, 160, 110), x = 0,    z = -140 },
    { id = "Copper",  displayName = "Copper Pad",  multiplier = 3,   minLevel = 5,  speedCap = 80,
      color = Color3.fromRGB(205, 127, 80),  x = -120, z = -190 },
    { id = "Iron",    displayName = "Iron Pad",    multiplier = 9,   minLevel = 10, speedCap = 120,
      color = Color3.fromRGB(160, 170, 185), x = -60,  z = -190 },
    { id = "Gold",    displayName = "Gold Pad",    multiplier = 25,  minLevel = 20, speedCap = 160,
      color = Color3.fromRGB(255, 200, 60),  x = 0,    z = -190 },
    { id = "Legend",  displayName = "Legend Pad",  multiplier = 100, minLevel = 35, speedCap = 200,
      color = Color3.fromRGB(255, 90, 200),  x = 60,   z = -190 },
    { id = "Admin",   displayName = "Admin Pad",   multiplier = 250, adminOnly = true, speedCap = 200,
      color = Color3.fromRGB(255, 60, 60),   x = 120,  z = -190 },
}

PadData.SIZE = Vector3.new(22, 1, 22)

-- Pads only top your stock up to a cap (they're a starter/convenience source, not an unlimited
-- faucet). The cap is "seconds of standing" worth of that pad's yield, so every pad takes about the
-- same time to fill but a higher pad fills a much bigger stock: x1 = 100 Ore / 50 Coal, x9 = 900 / 450,
-- x100 = 10,000 / 5,000. Spend materials to keep mining.
PadData.FILL_SECONDS = 100

function PadData.StockCap(def, matId)
    local perTick = (matId == "Coal") and def.multiplier / PadData.COAL_EVERY_N or def.multiplier
    return math.floor(perTick * PadData.FILL_SECONDS * PadData.ORE_PER_TICK + 0.5)
end

-- Pads pay out every TICK_SECONDS. Coal comes every COAL_EVERY_N ticks so Ore:Coal is
-- 2:1, matching the Tier 1 recipes (10 Basic Ore + 5 Coal). At 1x that is 1 Ore/s: a Tier 1 Golem is
-- about 10 seconds of standing, and a full top-up (100 Ore / 50 Coal) about 100 seconds. Higher pads fill it faster.
PadData.TICK_SECONDS    = 1
PadData.ORE_PER_TICK    = 1
PadData.COAL_EVERY_N    = 2

return PadData
