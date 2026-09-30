-- Mining pads: stand on one to gather materials every second.
-- Higher pads multiply the yield and unlock with player level.
local PadData = {}

-- position is relative to the world origin (Y is the ground). Row 1 is right by spawn.
-- The 1x / 3x / 9x / 25x / 100x ladder follows +1 Speed Keyboard Escape's treadmills (free,
-- then 59 / 259 / 749 / 1,599 R$). Here a level also unlocks each pad for free.
PadData.Pads = {
    { id = "Starter", displayName = "Starter Pad", multiplier = 1,   minLevel = 1,
      color = Color3.fromRGB(200, 160, 110), x = 0,    z = -140 },
    { id = "Copper",  displayName = "Copper Pad",  multiplier = 3,   minLevel = 5,
      color = Color3.fromRGB(205, 127, 80),  x = -120, z = -190 },
    { id = "Iron",    displayName = "Iron Pad",    multiplier = 9,   minLevel = 10,
      color = Color3.fromRGB(160, 170, 185), x = -60,  z = -190 },
    { id = "Gold",    displayName = "Gold Pad",    multiplier = 25,  minLevel = 20,
      color = Color3.fromRGB(255, 200, 60),  x = 0,    z = -190 },
    { id = "Legend",  displayName = "Legend Pad",  multiplier = 100, minLevel = 35,
      color = Color3.fromRGB(255, 90, 200),  x = 60,   z = -190 },
    { id = "Admin",   displayName = "Admin Pad",   multiplier = 250, adminOnly = true,
      color = Color3.fromRGB(255, 60, 60),   x = 120,  z = -190 },
}

PadData.SIZE = Vector3.new(22, 1, 22)

-- Pads only top your stock up to these amounts (they're a starter/convenience source, not
-- an unlimited faucet). Higher pads fill the same cap faster. Spend materials to keep mining.
PadData.STOCK_CAP = { BasicOre = 300, Coal = 150 }

-- Pads pay out every TICK_SECONDS. Coal comes every COAL_EVERY_N ticks so Ore:Coal is
-- 2:1, matching the Tier 1 recipes (10 Basic Ore + 5 Coal). At 1x that is 4 Ore/s.
PadData.TICK_SECONDS    = 0.25
PadData.ORE_PER_TICK    = 1
PadData.COAL_EVERY_N    = 2

return PadData
