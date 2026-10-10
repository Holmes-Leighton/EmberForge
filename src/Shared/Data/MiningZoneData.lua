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

    -- Build weighted list with luck boosting the entries rarer than the zone's everyday drop
    -- (in a zone where every drop is Rare or better, luck used to scale them all equally and did nothing)
    local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
    local baseRank, topWeight = 1, -1
    for _, entry in ipairs(zone.dropTable) do
        if entry.weight > topWeight then topWeight, baseRank = entry.weight, RANK[entry.rarity] or 1 end
    end
    local pool = {}
    local totalWeight = 0
    for _, entry in ipairs(zone.dropTable) do
        local w = entry.weight
        local rank = RANK[entry.rarity] or 1
        if rank >= 3 and rank > baseRank then
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
-- Server: remember every zone the player has reached, so trading or fusing away the Golem that opened it doesn't lock it again
function MiningZoneData.RememberUnlocked(playerData)
    playerData.UnlockedZones = playerData.UnlockedZones or {}
    for _, id in ipairs(MiningZoneData.GetUnlocked(playerData)) do
        playerData.UnlockedZones[id] = true
    end
end

function MiningZoneData.GetUnlocked(playerData)
    local unlocked = {}
    for id, zone in pairs(MiningZoneData.Zones) do
        local req = zone.unlockRequirement
        local met = playerData.UnlockedZones ~= nil and playerData.UnlockedZones[id] == true   -- earned once, kept for good

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
