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
        name        = "Primordial Golem",   -- (not "Ancient": that is the oldest life stage)
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
GolemData.SpecialOrder = { "Patchwork", "Woven", "Coral", "Clockwork", "Alchemist", "Gargoyle", "StormJar", "Dragonbone", "Maze" }

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
    Maze = {
        displayName = "Maze", tier = 5, statBias = "Everything",
        description = "Built from the pieces of the Hollow Maze, which only gives them up very rarely. It remembers every way out.",
        skill = { name = "Labyrinth Mind", text = "Each Maze Golem you deploy adds 10% to the coins and XP the Hollow Maze pays you (up to 30%).",
            params = { mazePer = 0.10, mazeCap = 0.30 } },
        mult = { MiningRate = 1.35, CarryCapacity = 1.20, Efficiency = 1.15, Luck = 1.20 },
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
    Neon     = { id = "Neon",     label = "Elite",     statMultiplier = 1.25, next = "MegaNeon" },
    MegaNeon = { id = "MegaNeon", label = "Supreme",   statMultiplier = 1.60 },
}
GolemData.NEON_FUSION_COUNT = 4

-- ── Growth (life stages) ───────────────────────────────────────────────────────
-- Tier is what a Golem was crafted as (fixed, and it sets the rarity). Stage is how long it has worked: a Golem grows while it is
-- deployed and mining, from a small weak Infant to a huge Ancient. The two multiply, so a grown Tier 2 never beats a Tier 3.
--   at     hours of work to reach the stage
--   mult   share of its stats the Golem has at this stage (Adult = 1.0, so everything crafted before growth existed is unchanged)
--   scale  how big it is drawn
--   head   how big its head is next to its body (a big head reads as young)
--   body   how wide its torso is, and  limb  how thick its arms and legs are: a young Golem is chubby, an old one broad and heavy.
--          Together these reshape the mesh a little at every stage (Adult = 1.0 is the model as made).
--   tone   how vivid its colours are: a young Golem is duller and deepens to the model's full colour by Adult (a texture can only be
--          darkened, so Adult is the brightest the body gets; Elder and Ancient get brighter through glow instead)
--   glow   how much its accent glows (runes, crown, a faint light): none until Elder, strongest at Ancient
--   color  the stage's badge colour in the menus and over its head
-- Golems from before growth existed have no `grown` record and count as Adult.
GolemData.Stages = {
    { id = "Infant",  at = 0,   mult = 0.70, scale = 0.62, head = 1.30, body = 1.10, limb = 1.16, tone = 0.68, glow = 0.0, color = Color3.fromRGB(170, 215, 170) },
    { id = "Young",   at = 1,   mult = 0.85, scale = 0.82, head = 1.14, body = 1.05, limb = 1.08, tone = 0.84, glow = 0.0, color = Color3.fromRGB(120, 205, 200) },
    { id = "Adult",   at = 8,   mult = 1.00, scale = 1.00, head = 1.00, body = 1.00, limb = 1.00, tone = 1.00, glow = 0.0, color = Color3.fromRGB(235, 235, 235) },
    { id = "Elder",   at = 48,  mult = 1.15, scale = 1.08, head = 1.00, body = 1.07, limb = 1.08, tone = 1.00, glow = 0.5, color = Color3.fromRGB(225, 160, 90) },
    { id = "Ancient", at = 240, mult = 1.30, scale = 1.16, head = 1.00, body = 1.14, limb = 1.16, tone = 1.00, glow = 1.0, color = Color3.fromRGB(255, 205, 70) },
}
GolemData.ADULT_INDEX = 3
GolemData.GROW_OFFLINE_RATE = 0.5   -- a Golem works at half growth speed while its owner is away
GolemData.GROW_FUSE_KEEP = 0.25     -- an Elite / Supreme fusion keeps this share of the combined growth (so it restarts young but not from zero)

function GolemData.GrownSeconds(golem)
    if golem.grown == nil then return GolemData.Stages[GolemData.ADULT_INDEX].at * 3600 end
    return golem.grown
end

-- stage table, its index, progress 0..1 toward the next stage (1 at Ancient), and hours left (nil at Ancient)
function GolemData.StageOf(golem)
    local hours = GolemData.GrownSeconds(golem) / 3600
    local index = 1
    for i, s in ipairs(GolemData.Stages) do if hours >= s.at then index = i end end
    local nextStage = GolemData.Stages[index + 1]
    if not nextStage then return GolemData.Stages[index], index, 1, nil end
    local cur = GolemData.Stages[index]
    return GolemData.Stages[index], index, (hours - cur.at) / (nextStage.at - cur.at), nextStage.at - hours
end

function GolemData.StageById(id)
    for i, s in ipairs(GolemData.Stages) do if s.id == id then return s, i end end
    return GolemData.Stages[GolemData.ADULT_INDEX], GolemData.ADULT_INDEX
end

-- Adds working time to a Golem. Returns the new stage if it just reached one, otherwise nil.
function GolemData.AddGrowth(golem, seconds)
    if not seconds or seconds <= 0 then return nil end
    local before = select(2, GolemData.StageOf(golem))
    golem.grown = GolemData.GrownSeconds(golem) + seconds
    local stage, after = GolemData.StageOf(golem)
    if after > before then return stage end
    return nil
end

-- ── Collection (the Golem index) ───────────────────────────────────────────────
-- data.GolemsSeen remembers every Golem type at every life stage the player has ever owned, even after trading it away
-- (like the pet index). Keys are "Ember:Infant", "Frost:Ancient" ... A Golem that has reached a stage has been through the stages before
-- it; a Golem from before growth existed has only been seen as an Adult.
GolemData.CollectionOrder = { "Ember", "Stone", "Frost", "Storm", "Void", "All" }
for _, id in ipairs(GolemData.SpecialOrder) do table.insert(GolemData.CollectionOrder, id) end

function GolemData.SeenKey(element, stageId) return element .. ":" .. stageId end

local function SeenStages(golem)
    local _, index = GolemData.StageOf(golem)
    local first = golem.grown == nil and GolemData.ADULT_INDEX or 1
    local out = {}
    for i = first, index do table.insert(out, GolemData.Stages[i].id) end
    return out
end

function GolemData.NoteSeen(data, golem)
    if not data or not golem or not golem.element then return end
    data.GolemsSeen = data.GolemsSeen or {}
    for _, id in ipairs(SeenStages(golem)) do data.GolemsSeen[GolemData.SeenKey(golem.element, id)] = true end
end

-- Everything ever seen, including the Golems owned right now (so saves from before the index existed are filled in)
function GolemData.SeenSet(data)
    local seen = {}
    for k in pairs(data and data.GolemsSeen or {}) do seen[k] = true end
    for _, golem in ipairs(data and data.Golems or {}) do
        for _, id in ipairs(SeenStages(golem)) do seen[GolemData.SeenKey(golem.element, id)] = true end
    end
    return seen
end

-- found, total forms (every type x every stage)
function GolemData.CollectionTotals(data)
    local seen, found = GolemData.SeenSet(data), 0
    for _, element in ipairs(GolemData.CollectionOrder) do
        for _, st in ipairs(GolemData.Stages) do
            if seen[GolemData.SeenKey(element, st.id)] then found += 1 end
        end
    end
    return found, #GolemData.CollectionOrder * #GolemData.Stages
end

-- The growth a Golem starts with after an Elite / Supreme fusion of `golems`
function GolemData.FusedGrowth(golems)
    local total = 0
    for _, g in ipairs(golems) do total += GolemData.GrownSeconds(g) end
    return total * GolemData.GROW_FUSE_KEEP
end

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
-- `stageId` is its life stage (GolemData.StageOf(golem).id); left out it counts as Adult, the full stats
function GolemData.ComputeStats(elementId, tierIndex, fusionBonus, quality, variant, stageId)
    local tier = GolemData.Tiers[tierIndex]
    local mult = GolemData.ElementMultipliers[elementId]
    if not tier or not mult then return nil end

    fusionBonus = fusionBonus or {}
    local variantDef = variant and GolemData.Variants[variant]
    local stage = stageId and GolemData.StageById(stageId)
    local q = (1 + (quality or 0)) * (variantDef and variantDef.statMultiplier or 1) * (stage and stage.mult or 1)
    return {
        miningRate    = math.floor(tier.resourcesPerHour * mult.MiningRate  * (1 + (fusionBonus.miningRate or 0)) * q),
        carryCapacity = math.floor(tier.carryCapacity    * mult.CarryCapacity * (1 + (fusionBonus.carryCapacity or 0)) * q),
        efficiency    = tier.efficiency * mult.Efficiency * (1 + (fusionBonus.efficiency or 0)) * q,
        luck          = tier.luck       * mult.Luck       * (1 + (fusionBonus.luck or 0)) * q,
        durabilityHours = tier.durabilityHours,
    }
end

return GolemData
