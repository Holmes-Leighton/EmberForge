-- All Golem definitions: elements, tiers, stats, unlock conditions.
local GolemData = {}

GolemData.Elements = {
    Ember = {
        id          = "Ember",
        displayName = "Ember",
        primaryMaterial = "IgniteOre",
        biome       = "Volcano Depths",
        statBias    = "MiningRate",   -- element excels here
        description = "Molten rock constructs that mine with blazing speed.",
    },
    Stone = {
        id          = "Stone",
        displayName = "Stone",
        primaryMaterial = "GraniteShard",
        biome       = "Underground Caverns",
        statBias    = "CarryCapacity",
        description = "Heavy earthen golems that haul enormous loads.",
    },
    Frost = {
        id          = "Frost",
        displayName = "Frost",
        primaryMaterial = "GlacialCrystal",
        biome       = "Frozen Peaks",
        statBias    = "Luck",
        description = "Translucent ice golems with a talent for rare finds.",
    },
    Storm = {
        id          = "Storm",
        displayName = "Storm",
        primaryMaterial = "ChargedFlint",
        biome       = "Stormrift Cliffs",
        statBias    = "Efficiency",   -- powers / energises other golems
        description = "Crackling metallic golems that supercharge production.",
    },
    Void = {
        id          = "Void",
        displayName = "Void",
        primaryMaterial = "ShadowDust",
        biome       = "The Hollow",
        statBias    = "Luck",         -- stealth / hidden deposits
        description = "Shifting dark-matter constructs that find hidden veins.",
        unlockRequirement = "Tier2",  -- requires Tier 2+ to craft
    },
}

-- Base stat tables indexed [element][tier]
-- MiningRate = resources/hr base; CarryCapacity = resources before return
GolemData.Tiers = {
    {
        tier        = 1,
        name        = "Pebble Golem",
        resourcesPerHour = 50,
        carryCapacity    = 200,
        efficiency       = 1.0,
        luck             = 0.05,
        durabilityHours  = 72,
        materialsRequired = {
            { id = "BasicOre", qty = 10 },
            { id = "Coal",     qty = 5  },
        },
        unlockCondition = "available_from_start",
        craftXP = 50,
    },
    {
        tier        = 2,
        name        = "Shard Golem",
        resourcesPerHour = 180,
        carryCapacity    = 720,
        efficiency       = 1.05,
        luck             = 0.08,
        durabilityHours  = 96,
        materialsRequired = {
            { id = "RefinedOre",  qty = 30 },
            { id = "EmberDust",   qty = 15 },
        },
        unlockCondition = "craft_3x_tier1",
        craftXP = 150,
    },
    {
        tier        = 3,
        name        = "Core Golem",
        resourcesPerHour = 520,
        carryCapacity    = 2080,
        efficiency       = 1.10,
        luck             = 0.12,
        durabilityHours  = 120,
        materialsRequired = {
            { id = "ElementalIngot",   qty = 80 },
            { id = "CrystalFragment",  qty = 40 },
        },
        unlockCondition = "craft_2x_tier2",
        craftXP = 400,
    },
    {
        tier        = 4,
        name        = "Forged Golem",
        resourcesPerHour = 1400,
        carryCapacity    = 5600,
        efficiency       = 1.20,
        luck             = 0.18,
        durabilityHours  = 168,
        materialsRequired = {
            { id = "PureIngot",    qty = 200 },
            { id = "EssenceShard", qty = 100 },
        },
        unlockCondition = "unlock_tier4_forge",
        craftXP = 1000,
    },
    {
        tier        = 5,
        name        = "Ancient Golem",
        resourcesPerHour = 4000,
        carryCapacity    = 16000,
        efficiency       = 1.35,
        luck             = 0.30,
        durabilityHours  = 336,
        materialsRequired = {
            { id = "PrimordialOre",    qty = 50  },
            { id = "VoidEssence",      qty = 25  },
            { id = "EventCatalyst",    qty = 1   },
        },
        unlockCondition = "seasonal_event",
        craftXP = 3000,
    },
}

-- Element stat multipliers applied on top of tier base
GolemData.ElementMultipliers = {
    Ember = { MiningRate = 1.25, CarryCapacity = 0.90, Efficiency = 1.00, Luck = 1.00 },
    Stone = { MiningRate = 0.80, CarryCapacity = 1.40, Efficiency = 1.00, Luck = 1.00 },
    Frost = { MiningRate = 1.00, CarryCapacity = 1.00, Efficiency = 1.00, Luck = 1.35 },
    Storm = { MiningRate = 1.00, CarryCapacity = 1.00, Efficiency = 1.20, Luck = 1.00 },
    Void  = { MiningRate = 0.95, CarryCapacity = 0.95, Efficiency = 1.05, Luck = 1.50 },
    All   = { MiningRate = 1.10, CarryCapacity = 1.10, Efficiency = 1.10, Luck = 1.10 },   -- multi-element event Golems
}

-- ── Rarity & variants (Adopt Me style) ─────────────────────────────────────────
-- Rarity is fixed by the blueprint's tier - never a dice roll (the spec's core promise) - and gives
-- every Golem an instantly readable "how special is this?" label.
GolemData.Rarities = {
    { id = "Common",    order = 1 },
    { id = "Uncommon",  order = 2 },
    { id = "Rare",      order = 3 },
    { id = "Epic",      order = 4 },
    { id = "Legendary", order = 5 },
}
GolemData.RarityByTier = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

function GolemData.RarityForTier(tier)
    return GolemData.RarityByTier[math.clamp(tier or 1, 1, #GolemData.RarityByTier)]
end

function GolemData.RarityOrder(rarity)
    for _, r in ipairs(GolemData.Rarities) do
        if r.id == rarity then return r.order end
    end
    return 1
end

-- Variants: fuse 4 identical Golems -> Neon; fuse 4 identical Neons -> Mega Neon.
GolemData.Variants = {
    Neon     = { id = "Neon",     label = "Neon",      statMultiplier = 1.25, next = "MegaNeon" },
    MegaNeon = { id = "MegaNeon", label = "Mega Neon", statMultiplier = 1.60 },
}
GolemData.NEON_FUSION_COUNT = 4

-- Golem slot unlock milestones
GolemData.SlotMilestones = {
    { slots = 3,  condition = "start"              },
    { slots = 4,  condition = "craft_first_tier2"  },
    { slots = 5,  condition = "forge_level_5"      },
    { slots = 7,  condition = "forge_mastery_challenge" },
    { slots = 9,  condition = "craft_first_tier4"  },
}

-- Compute final stats for a golem given element + tier + optional fusion bonus
-- `quality` (0..0.15) is the bonus a Golem earned from the grade of materials it was crafted with
function GolemData.ComputeStats(elementId, tierIndex, fusionBonus, quality, variant)
    local tier = GolemData.Tiers[tierIndex]
    local mult = GolemData.ElementMultipliers[elementId]
    if not tier or not mult then return nil end

    fusionBonus = fusionBonus or {}
    local variantDef = variant and GolemData.Variants[variant]
    local q = (1 + (quality or 0)) * (variantDef and variantDef.statMultiplier or 1)
    return {
        miningRate    = math.floor(tier.resourcesPerHour * mult.MiningRate  * (1 + (fusionBonus.miningRate or 0)) * q),
        carryCapacity = math.floor(tier.carryCapacity    * mult.CarryCapacity * (1 + (fusionBonus.carryCapacity or 0)) * q),
        efficiency    = tier.efficiency * mult.Efficiency * (1 + (fusionBonus.efficiency or 0)) * q,
        luck          = tier.luck       * mult.Luck       * (1 + (fusionBonus.luck or 0)) * q,
        durabilityHours = tier.durabilityHours,
    }
end

return GolemData
