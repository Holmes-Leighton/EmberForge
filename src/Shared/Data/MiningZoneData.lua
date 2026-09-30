-- Mining zone definitions: unlock requirements and drop tables.
local MiningZoneData = {}

MiningZoneData.Zones = {
    EmberDepths = {
        id = "EmberDepths", displayName = "Ember Depths",
        element = "Ember",
        unlockRequirement = { type = "craft_golem", element = "Ember", minTier = 1 },
        dropTable = {
            { materialId = "IgniteOre",  weight = 70, rarity = "Common"   },
            { materialId = "Coal",       weight = 20, rarity = "Common"   },
            { materialId = "MoltenCore", weight = 10, rarity = "Rare"     },
        },
    },
    GraniteCaverns = {
        id = "GraniteCaverns", displayName = "Granite Caverns",
        element = "Stone",
        unlockRequirement = { type = "craft_golem", element = "Stone", minTier = 1 },
        dropTable = {
            { materialId = "GraniteShard",  weight = 70, rarity = "Common"   },
            { materialId = "BasicOre",      weight = 20, rarity = "Common"   },
            { materialId = "ShadowDust", weight = 6, rarity = "Uncommon" },
            { materialId = "AncientBedrock", weight = 10, rarity = "Rare"   },
        },
    },
    GlacialPeaks = {
        id = "GlacialPeaks", displayName = "Glacial Peaks",
        element = "Frost",
        unlockRequirement = { type = "craft_golem", element = "Frost", minTier = 1 },
        dropTable = {
            { materialId = "GlacialCrystal", weight = 70, rarity = "Common" },
            { materialId = "BasicOre",       weight = 15, rarity = "Common" },
            { materialId = "ShadowDust", weight = 6, rarity = "Uncommon" },
            { materialId = "EternalIce",     weight = 15, rarity = "Rare"   },
        },
    },
    StormriftCliffs = {
        id = "StormriftCliffs", displayName = "Stormrift Cliffs",
        element = "Storm",
        unlockRequirement = { type = "craft_golem", element = "Storm", minTier = 1 },
        dropTable = {
            { materialId = "ChargedFlint", weight = 70, rarity = "Common" },
            { materialId = "BasicOre",     weight = 15, rarity = "Common" },
            { materialId = "ShadowDust", weight = 6, rarity = "Uncommon" },
            { materialId = "ThunderShard", weight = 15, rarity = "Rare"   },
        },
    },
    TheHollow = {
        id = "TheHollow", displayName = "The Hollow",
        element = "Void",
        unlockRequirement = { type = "craft_golem", element = "Void", minTier = 2 },
        dropTable = {
            { materialId = "ShadowDust",  weight = 55, rarity = "Uncommon" },
            { materialId = "BasicOre",    weight = 30, rarity = "Common"   },
            { materialId = "VoidEssence", weight = 15, rarity = "Epic"     },
        },
    },
    TheDeepForge = {
        id = "TheDeepForge", displayName = "The Deep Forge",
        element = nil,  -- all elements
        unlockRequirement = { type = "forge_level", level = 8 },
        dropTable = {
            { materialId = "PureIngot",     weight = 60, rarity = "Epic"      },
            { materialId = "EssenceShard",  weight = 25, rarity = "Rare"      },
            { materialId = "PrimordialOre", weight = 15, rarity = "Legendary" },
        },
    },
}

-- Sample a drop from a zone's drop table
function MiningZoneData.SampleDrop(zoneId, luckMultiplier)
    local zone = MiningZoneData.Zones[zoneId]
    if not zone then return nil end

    luckMultiplier = luckMultiplier or 1.0

    -- Build weighted list with luck boosting rare entries
    local pool = {}
    local totalWeight = 0
    for _, entry in ipairs(zone.dropTable) do
        local w = entry.weight
        if entry.rarity == "Rare" or entry.rarity == "Epic" or entry.rarity == "Legendary" then
            w = math.floor(w * luckMultiplier)
        end
        totalWeight = totalWeight + w
        table.insert(pool, { materialId = entry.materialId, cumulative = totalWeight })
    end

    local roll = math.random(1, totalWeight)
    for _, entry in ipairs(pool) do
        if roll <= entry.cumulative then
            return entry.materialId
        end
    end
    return pool[#pool].materialId  -- fallback
end

function MiningZoneData.Get(zoneId)
    return MiningZoneData.Zones[zoneId]
end

-- Returns list of zone IDs that a player has unlocked given their state
function MiningZoneData.GetUnlocked(playerData)
    local unlocked = {}
    for id, zone in pairs(MiningZoneData.Zones) do
        local req = zone.unlockRequirement
        local met = false

        if req.type == "craft_golem" then
            -- check if player has ever crafted a golem of this element at the required tier
            for _, golem in ipairs(playerData.Golems or {}) do
                if golem.element == req.element and golem.tier >= req.minTier then
                    met = true
                    break
                end
            end
        elseif req.type == "forge_level" then
            met = (playerData.ForgeLevel or 1) >= req.level
        end

        if met then
            table.insert(unlocked, id)
        end
    end
    return unlocked
end

return MiningZoneData
