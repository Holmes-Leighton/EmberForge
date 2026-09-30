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

-- ── Special Golems ────────────────────────────────────────────────────────────
-- Extra Golem types, each with its own look and one unique passive SKILL. They are element-style
-- entries (so crafting, names, stats, colours and the picker all just work) flagged `special = true`.
-- They mine in any zone you have unlocked. `skill.params` is what IdleEngine reads; `skill.text` is
-- what the player sees, so keep the two in step.
--   tier   the tier its blueprint crafts at (rarity follows the tier)
--   mult   stat multipliers, like ElementMultipliers
GolemData.SpecialOrder = { "Patchwork", "Woven", "Coral", "Clockwork", "Alchemist", "Gargoyle", "StormJar", "Dragonbone" }

GolemData.Specials = {
    Patchwork = {
        displayName = "Patchwork", tier = 2, statBias = "Durability",
        description = "A cheerful stitched-together Golem that just keeps going.",
        skill = { name = "Sturdy Stitching", text = "Wears out 60% slower, so it works far longer between repairs.", params = { drain = 0.4 } },
        mult = { MiningRate = 0.90, CarryCapacity = 1.05, Efficiency = 1.00, Luck = 1.00 },
    },
    Woven = {
        displayName = "Woven", tier = 2, statBias = "Bonus hauls",
        description = "Knotted rope and reeds that snag extras from the rock.",
        skill = { name = "Net Haul", text = "20% of its hauls come back doubled.", params = { doubleChance = 0.20 } },
        mult = { MiningRate = 0.95, CarryCapacity = 1.10, Efficiency = 1.00, Luck = 1.05 },
    },
    Coral = {
        displayName = "Coral", tier = 3, statBias = "Luck aura",
        description = "A living reef that hums with the sea.",
        skill = { name = "Reef Bounty", text = "Every Coral Golem you deploy gives all your Golems +5% luck (up to +20%).",
            params = { luckPer = 0.05, luckCap = 0.20 } },
        mult = { MiningRate = 0.95, CarryCapacity = 1.15, Efficiency = 1.00, Luck = 1.20 },
    },
    Clockwork = {
        displayName = "Clockwork", tier = 3, statBias = "Speed",
        description = "Brass gears and a wind-up key: fast, precise, and a little reckless.",
        skill = { name = "Overclock", text = "+25% mining speed, but it wears out 25% faster.", params = { rate = 1.25, drain = 1.25 } },
        mult = { MiningRate = 1.10, CarryCapacity = 0.90, Efficiency = 1.10, Luck = 0.90 },
    },
    Alchemist = {
        displayName = "Alchemist", tier = 3, statBias = "Rare finds",
        description = "Bubbling vials and strange brews.",
        skill = { name = "Transmutation", text = "10% of its hauls are brewed into something rarer.", params = { chance = 0.10, luckMult = 3 } },
        mult = { MiningRate = 0.90, CarryCapacity = 0.90, Efficiency = 1.10, Luck = 1.40 },
    },
    Gargoyle = {
        displayName = "Gargoyle", tier = 3, statBias = "Offline mining",
        description = "A winged stone guardian that sleeps by day and works by night.",
        skill = { name = "Night Watch", text = "Works 60% harder while you are offline, but 10% slower while you play.",
            params = { offlineRate = 1.6, onlineRate = 0.9 } },
        mult = { MiningRate = 1.00, CarryCapacity = 1.25, Efficiency = 1.00, Luck = 1.00 },
    },
    StormJar = {
        displayName = "Storm in a Jar", tier = 4, statBias = "Team protection",
        description = "A thunderstorm trapped in a glass shell.",
        skill = { name = "Shelter from the Storm", text = "Every Jar you deploy slows wear on your other Golems by 10% (up to 30%).",
            params = { shelterPer = 0.10, shelterCap = 0.30 } },
        mult = { MiningRate = 1.00, CarryCapacity = 1.00, Efficiency = 1.15, Luck = 1.10 },
    },
    Dragonbone = {
        displayName = "Dragonbone", tier = 4, statBias = "Blueprint finds",
        description = "The skeleton of something enormous, still guarding its hoard.",
        skill = { name = "Hoarder's Instinct", text = "Each Dragonbone you deploy doubles your chance to discover new blueprints (up to 3x).",
            params = { blueprintPer = 1.0, blueprintCap = 2.0 } },
        mult = { MiningRate = 1.25, CarryCapacity = 1.10, Efficiency = 1.00, Luck = 1.15 },
    },
}

for id, def in pairs(GolemData.Specials) do
    GolemData.Elements[id] = {
        id = id, displayName = def.displayName, special = true, tier = def.tier,
        primaryMaterial = nil, biome = "Any zone", statBias = def.statBias,
        description = def.description, skill = def.skill,
    }
    GolemData.ElementMultipliers[id] = def.mult
end

function GolemData.IsSpecial(element)
    return GolemData.Specials[element] ~= nil
end

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
