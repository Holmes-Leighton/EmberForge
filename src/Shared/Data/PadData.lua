-- Mining pads: stand on one to gather materials every second.
-- Higher pads multiply the yield and unlock with player level.
local PadData = {}

-- position is relative to the world origin (Y is the ground). Row 1 is right by spawn.
PadData.Pads = {
    { id = "Starter", displayName = "Starter Pad", multiplier = 1,   minLevel = 1,
      color = Color3.fromRGB(200, 160, 110), x = 0,   z = -140 },
    { id = "Copper",  displayName = "Copper Pad",  multiplier = 3,   minLevel = 5,
      color = Color3.fromRGB(205, 127, 80),  x = -90, z = -185 },
    { id = "Iron",    displayName = "Iron Pad",    multiplier = 5,   minLevel = 10,
      color = Color3.fromRGB(160, 170, 185), x = -30, z = -185 },
    { id = "Gold",    displayName = "Gold Pad",    multiplier = 10,  minLevel = 20,
      color = Color3.fromRGB(255, 200, 60),  x = 30,  z = -185 },
    { id = "Admin",   displayName = "Admin Pad",   multiplier = 100, adminOnly = true,
      color = Color3.fromRGB(255, 60, 90),   x = 90,  z = -185 },
}

PadData.SIZE = Vector3.new(22, 1, 22)

-- Per-second yield at 1x. Coal is produced every other second so Ore:Coal is 2:1,
-- matching the Tier 1 recipes (10 Basic Ore + 5 Coal).
PadData.ORE_PER_SECOND  = 1
PadData.COAL_EVERY_N    = 2

return PadData
