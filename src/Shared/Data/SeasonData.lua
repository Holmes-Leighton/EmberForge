-- Season pass definitions and seasonal event data.
local SeasonData = {}

SeasonData.PassTier = {
    None     = 0,
    Standard = 1,
    Premium  = 2,
}

SeasonData.PassPricing = {
    Standard = 699,   -- Robux
    Premium  = 1299,  -- Robux
}

-- Season definitions
-- Season start timestamps (UTC Unix). Each season runs durationWeeks*7 days.
-- Season1 = 2026-05-19, subsequent seasons chain end-to-end.
SeasonData.Seasons = {
    Season1 = {
        id = "Season1", displayName = "The First Forge",
        startTimestamp = 1747612800,  -- 2026-05-19 00:00:00 UTC
        featuredElement = "Ember",
        eventGolem = "MagmaTitan",
        eventGolemBlueprintId = "BP_Season1_MagmaTitan",
        eventMaterial = "EventCatalyst",
        eventMaterialProductId = "EF_EventCatalyst_S1",  -- Robux product ID
        durationWeeks = 7,
        freeTrackRewards = {
            { week = 1, reward = { type = "cosmetic", id = "ForgeSkin_Ember_Basic" } },
            { week = 2, reward = { type = "material", id = "EmberDust", qty = 20 } },
            { week = 3, reward = { type = "material", id = "MoltenCore", qty = 3 } },
            { week = 4, reward = { type = "cosmetic", id = "TitleBadge_Ember_Initiate" } },
            { week = 5, reward = { type = "coins", qty = 200 } },
            { week = 6, reward = { type = "material", id = "EssenceShard", qty = 5 } },
            { week = 7, reward = { type = "cosmetic", id = "GolemAccessory_EmberHelm" } },
        },
        standardTrackRewards = {
            { week = 1, reward = { type = "cosmetic", id = "ForgeSkin_Ember_Standard" } },
            { week = 2, reward = { type = "speedup", qty = 5 } },
            { week = 3, reward = { type = "cosmetic", id = "GolemAccessory_LavaCrown" } },
            { week = 4, reward = { type = "material", id = "EssenceShard", qty = 10 } },
            { week = 5, reward = { type = "cosmetic", id = "ParticleEffect_Ember_Trail" } },
            { week = 6, reward = { type = "storageSlot", hours = 8 } },
            { week = 7, reward = { type = "cosmetic", id = "ForgeDecoration_EmberStatue" } },
        },
        premiumTrackRewards = {
            { week = 1, reward = { type = "cosmetic", id = "GolemSkin_MagmaTitan_Premium" } },
            { week = 2, reward = { type = "material", id = "PureIngot", qty = 5 } },
            { week = 3, reward = { type = "cosmetic", id = "ForgeDecoration_LavaRiver" } },
            { week = 4, reward = { type = "speedup", qty = 10 } },
            { week = 5, reward = { type = "cosmetic", id = "ParticleEffect_LavaBurst" } },
            { week = 6, reward = { type = "cosmetic", id = "AnimatedForgeEffect_MagmaFlow" } },
            { week = 7, reward = { type = "cosmetic", id = "TitleBadge_Forge_Titan" } },
        },
        communityMilestone = {
            target = 500000,  -- total event materials crafted by all players
            reward = { type = "dropRateBoost", multiplier = 2.0, durationHours = 48 },
        },
    },
    Season2 = {
        id = "Season2", displayName = "The Frozen Veil",
        startTimestamp = 1751846400,  -- 2026-07-07 00:00:00 UTC
        featuredElement = "Frost",
        eventGolem = "CrystalWraith",
        eventGolemBlueprintId = "BP_Season2_CrystalWraith",
        eventMaterial = "EventCatalyst",
        durationWeeks = 7,
        freeTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Frost_Basic" } },
            { week = 2, reward = { type = "material",  id = "GlacialCrystal", qty = 25 } },
            { week = 3, reward = { type = "material",  id = "EternalIce", qty = 3 } },
            { week = 4, reward = { type = "cosmetic",  id = "TitleBadge_Frost_Initiate" } },
            { week = 5, reward = { type = "coins",     qty = 200 } },
            { week = 6, reward = { type = "material",  id = "CrystalFragment", qty = 10 } },
            { week = 7, reward = { type = "cosmetic",  id = "GolemAccessory_IceHelm" } },
        },
        standardTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Frost_Standard" } },
            { week = 2, reward = { type = "speedup",   qty = 5 } },
            { week = 3, reward = { type = "cosmetic",  id = "GolemAccessory_BlizzardCrown" } },
            { week = 4, reward = { type = "material",  id = "EssenceShard", qty = 10 } },
            { week = 5, reward = { type = "cosmetic",  id = "ParticleEffect_Frost_Trail" } },
            { week = 6, reward = { type = "storageSlot", hours = 8 } },
            { week = 7, reward = { type = "cosmetic",  id = "ForgeDecoration_IceStatue" } },
        },
        premiumTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "GolemSkin_CrystalWraith_Premium" } },
            { week = 2, reward = { type = "material",  id = "PureIngot", qty = 5 } },
            { week = 3, reward = { type = "cosmetic",  id = "ForgeDecoration_GlacialPillar" } },
            { week = 4, reward = { type = "speedup",   qty = 10 } },
            { week = 5, reward = { type = "cosmetic",  id = "ParticleEffect_BlizzardBurst" } },
            { week = 6, reward = { type = "cosmetic",  id = "AnimatedForgeEffect_IceFlow" } },
            { week = 7, reward = { type = "cosmetic",  id = "TitleBadge_Frost_Sovereign" } },
        },
        communityMilestone = {
            target = 600000,
            reward = { type = "dropRateBoost", multiplier = 2.0, durationHours = 48 },
        },
    },
    Season3 = {
        id = "Season3", displayName = "Stormrise",
        startTimestamp = 1756080000,  -- 2026-08-25 00:00:00 UTC
        featuredElement = "Storm",
        eventGolem = "ThunderColossus",
        eventGolemBlueprintId = "BP_Season3_ThunderColossus",
        eventMaterial = "EventCatalyst",
        durationWeeks = 7,
        freeTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Storm_Basic" } },
            { week = 2, reward = { type = "material",  id = "ChargedFlint", qty = 30 } },
            { week = 3, reward = { type = "material",  id = "ThunderShard", qty = 5 } },
            { week = 4, reward = { type = "cosmetic",  id = "TitleBadge_Storm_Initiate" } },
            { week = 5, reward = { type = "coins",     qty = 250 } },
            { week = 6, reward = { type = "material",  id = "ElementalIngot", qty = 8 } },
            { week = 7, reward = { type = "cosmetic",  id = "GolemAccessory_ThunderHelm" } },
        },
        standardTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Storm_Standard" } },
            { week = 2, reward = { type = "speedup",   qty = 6 } },
            { week = 3, reward = { type = "cosmetic",  id = "GolemAccessory_StormCrown" } },
            { week = 4, reward = { type = "material",  id = "EssenceShard", qty = 12 } },
            { week = 5, reward = { type = "cosmetic",  id = "ParticleEffect_Storm_Trail" } },
            { week = 6, reward = { type = "storageSlot", hours = 8 } },
            { week = 7, reward = { type = "cosmetic",  id = "ForgeDecoration_LightningRod" } },
        },
        premiumTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "GolemSkin_ThunderColossus_Premium" } },
            { week = 2, reward = { type = "material",  id = "PureIngot", qty = 6 } },
            { week = 3, reward = { type = "cosmetic",  id = "ForgeDecoration_StormPillar" } },
            { week = 4, reward = { type = "speedup",   qty = 12 } },
            { week = 5, reward = { type = "cosmetic",  id = "ParticleEffect_ThunderBurst" } },
            { week = 6, reward = { type = "cosmetic",  id = "AnimatedForgeEffect_ArcLightning" } },
            { week = 7, reward = { type = "cosmetic",  id = "TitleBadge_Storm_Sovereign" } },
        },
        communityMilestone = {
            target = 750000,
            reward = { type = "dropRateBoost", multiplier = 2.5, durationHours = 48 },
        },
    },
    Season4 = {
        id = "Season4", displayName = "The Deep Hollow",
        startTimestamp = 1760313600,  -- 2026-10-13 00:00:00 UTC
        featuredElement = "Void",
        eventGolem = "VoidWalker",
        eventGolemBlueprintId = "BP_Season4_VoidWalker",
        eventMaterial = "EventCatalyst",
        durationWeeks = 7,
        freeTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Void_Basic" } },
            { week = 2, reward = { type = "material",  id = "ShadowDust", qty = 20 } },
            { week = 3, reward = { type = "material",  id = "VoidEssence", qty = 3 } },
            { week = 4, reward = { type = "cosmetic",  id = "TitleBadge_Void_Initiate" } },
            { week = 5, reward = { type = "coins",     qty = 300 } },
            { week = 6, reward = { type = "material",  id = "EssenceShard", qty = 8 } },
            { week = 7, reward = { type = "cosmetic",  id = "GolemAccessory_VoidHelm" } },
        },
        standardTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Void_Standard" } },
            { week = 2, reward = { type = "speedup",   qty = 7 } },
            { week = 3, reward = { type = "cosmetic",  id = "GolemAccessory_VoidCrown" } },
            { week = 4, reward = { type = "material",  id = "EssenceShard", qty = 15 } },
            { week = 5, reward = { type = "cosmetic",  id = "ParticleEffect_Void_Trail" } },
            { week = 6, reward = { type = "storageSlot", hours = 8 } },
            { week = 7, reward = { type = "cosmetic",  id = "ForgeDecoration_VoidObelisk" } },
        },
        premiumTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "GolemSkin_VoidWalker_Premium" } },
            { week = 2, reward = { type = "material",  id = "PureIngot", qty = 8 } },
            { week = 3, reward = { type = "cosmetic",  id = "ForgeDecoration_VoidPortal" } },
            { week = 4, reward = { type = "speedup",   qty = 15 } },
            { week = 5, reward = { type = "cosmetic",  id = "ParticleEffect_VoidBurst" } },
            { week = 6, reward = { type = "cosmetic",  id = "AnimatedForgeEffect_VoidRift" } },
            { week = 7, reward = { type = "cosmetic",  id = "TitleBadge_Void_Sovereign" } },
        },
        communityMilestone = {
            target = 1000000,
            reward = { type = "dropRateBoost", multiplier = 3.0, durationHours = 72 },
        },
    },
    Season5 = {
        id = "Season5", displayName = "The Ancient Forge",
        startTimestamp = 1764547200,  -- 2026-12-01 00:00:00 UTC
        featuredElement = "All",
        eventGolem = "PrimordialGolem",
        eventGolemBlueprintId = "BP_Season5_PrimordialGolem",
        eventMaterial = "EventCatalyst",
        durationWeeks = 8,
        freeTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Ancient_Basic" } },
            { week = 2, reward = { type = "material",  id = "EssenceShard", qty = 10 } },
            { week = 3, reward = { type = "material",  id = "PureIngot", qty = 3 } },
            { week = 4, reward = { type = "cosmetic",  id = "TitleBadge_Ancient_Initiate" } },
            { week = 5, reward = { type = "coins",     qty = 400 } },
            { week = 6, reward = { type = "material",  id = "VoidEssence", qty = 5 } },
            { week = 7, reward = { type = "cosmetic",  id = "GolemAccessory_PrimordialHelm" } },
            { week = 8, reward = { type = "cosmetic",  id = "TitleBadge_ForgeVeteran" } },
        },
        standardTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "ForgeSkin_Ancient_Standard" } },
            { week = 2, reward = { type = "speedup",   qty = 8 } },
            { week = 3, reward = { type = "material",  id = "PrimordialOre", qty = 3 } },
            { week = 4, reward = { type = "material",  id = "EssenceShard", qty = 20 } },
            { week = 5, reward = { type = "cosmetic",  id = "ParticleEffect_Ancient_Trail" } },
            { week = 6, reward = { type = "storageSlot", hours = 8 } },
            { week = 7, reward = { type = "speedup",   qty = 10 } },
            { week = 8, reward = { type = "cosmetic",  id = "ForgeDecoration_AncientAltar" } },
        },
        premiumTrackRewards = {
            { week = 1, reward = { type = "cosmetic",  id = "GolemSkin_PrimordialGolem_Premium" } },
            { week = 2, reward = { type = "material",  id = "PureIngot", qty = 10 } },
            { week = 3, reward = { type = "cosmetic",  id = "ForgeDecoration_PrimordialPillar" } },
            { week = 4, reward = { type = "speedup",   qty = 20 } },
            { week = 5, reward = { type = "material",  id = "PrimordialOre", qty = 5 } },
            { week = 6, reward = { type = "cosmetic",  id = "AnimatedForgeEffect_AncientFlame" } },
            { week = 7, reward = { type = "cosmetic",  id = "ParticleEffect_PrimordialBurst" } },
            { week = 8, reward = { type = "cosmetic",  id = "TitleBadge_ForgeLegend" } },
        },
        communityMilestone = {
            target = 2000000,
            reward = { type = "dropRateBoost", multiplier = 4.0, durationHours = 96 },
        },
    },
}

-- Robux product IDs for Season Pass purchases
SeasonData.ProductIds = {
    StandardPass = "EF_SeasonPass_Standard",
    PremiumPass  = "EF_SeasonPass_Premium",
}

function SeasonData.Get(seasonId)
    return SeasonData.Seasons[seasonId]
end

local SEASON_ORDER = { "Season1", "Season2", "Season3", "Season4", "Season5" }

function SeasonData.GetCurrentSeason()
    local now = os.time()
    for _, id in ipairs(SEASON_ORDER) do
        local s = SeasonData.Seasons[id]
        local start = s.startTimestamp or 0
        local finish = start + s.durationWeeks * 7 * 86400
        if now >= start and now < finish then
            return s
        end
    end
    -- Before first season starts, return Season1; after all end, return Season5
    if now < (SeasonData.Seasons["Season1"].startTimestamp or 0) then
        return SeasonData.Seasons["Season1"]
    end
    return SeasonData.Seasons["Season5"]
end

return SeasonData
