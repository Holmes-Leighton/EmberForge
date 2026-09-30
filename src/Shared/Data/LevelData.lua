-- Player Level rewards (spec 6.1: levels unlock cosmetics and forge perks, never core content).
local LevelData = {}

LevelData.Rewards = {
    [2]  = { type = "coins", qty = 100 },
    [3]  = { type = "coins", qty = 150 },
    [5]  = { type = "cosmetic", id = "TitleBadge_Apprentice" },
    [8]  = { type = "cosmetic", id = "ForgeDecoration_Anvil" },
    [10] = { type = "cosmetic", id = "ForgeSkin_Bronze" },
    [12] = { type = "coins", qty = 400 },
    [15] = { type = "cosmetic", id = "TitleBadge_Journeyman" },
    [20] = { type = "cosmetic", id = "GolemAccessory_MinerHelm" },
    [25] = { type = "cosmetic", id = "ParticleEffect_Sparks" },
    [30] = { type = "cosmetic", id = "TitleBadge_Master" },
    [40] = { type = "cosmetic", id = "ForgeDecoration_Statue" },
    [50] = { type = "cosmetic", id = "TitleBadge_Legend" },
}

return LevelData
