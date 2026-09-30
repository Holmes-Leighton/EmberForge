-- Forge level definitions: unlocks, visual states, smelt slot counts.
local ForgeData = {}

ForgeData.Levels = {
    {
        level = 1,
        displayName = "Stone Forge",
        unlocks = {
            smeltSlots = 5,
            materialSlots = 2,
            maxCraftTier = 1,
            description = "Basic smelter, 2 material slots, Tier 1 crafting",
        },
        visual = "Small stone forge, one fire pit",
        smeltSpeedBonus = 0,         -- no reduction at level 1
        xpRequired = 0,
    },
    {
        level = 2,
        displayName = "Ember Forge",
        unlocks = {
            smeltSlots = 5,
            materialSlots = 3,
            maxCraftTier = 1,
            description = "Additional smelter slot, improved workflow",
        },
        visual = "Forge glow intensifies",
        smeltSpeedBonus = 0.05,
        xpRequired = 500,
    },
    {
        level = 3,
        displayName = "Workshop Forge",
        unlocks = {
            smeltSlots = 6,
            materialSlots = 4,
            maxCraftTier = 2,
            description = "Advanced smelter, 4 material slots, Tier 2 crafting",
        },
        visual = "Expanded workshop, forge glow effects",
        smeltSpeedBonus = 0.10,
        xpRequired = 1500,
    },
    {
        level = 4,
        displayName = "Artisan Forge",
        unlocks = {
            smeltSlots = 6,
            materialSlots = 5,
            maxCraftTier = 2,
            description = "Artisan smelting, 5 material slots",
        },
        visual = "Metal conduits added to walls",
        smeltSpeedBonus = 0.15,
        xpRequired = 3500,
    },
    {
        level = 5,
        displayName = "Elemental Forge",
        unlocks = {
            smeltSlots = 7,
            materialSlots = 6,
            maxCraftTier = 3,
            description = "Elemental furnace, 6 material slots, Tier 3 crafting",
        },
        visual = "Elemental flames, lava channels added",
        smeltSpeedBonus = 0.20,
        xpRequired = 7500,
        golemSlotUnlock = 5,  -- grants slot milestone
    },
    {
        level = 6,
        displayName = "Grand Forge",
        unlocks = {
            smeltSlots = 8,
            materialSlots = 7,
            maxCraftTier = 3,
            description = "Grand smelting hall, 7 material slots",
        },
        visual = "Multi-tier forge structure",
        smeltSpeedBonus = 0.25,
        xpRequired = 15000,
    },
    {
        level = 7,
        displayName = "Titan Forge",
        unlocks = {
            smeltSlots = 8,
            materialSlots = 8,
            maxCraftTier = 3,
            description = "Titan-class smelter, 8 material slots",
        },
        visual = "Animated conveyor systems added",
        smeltSpeedBonus = 0.30,
        xpRequired = 28000,
    },
    {
        level = 8,
        displayName = "Master Forge",
        unlocks = {
            smeltSlots = 9,
            materialSlots = 8,
            maxCraftTier = 4,
            description = "Master forge, 8 material slots, Tier 4 crafting, Deep Forge access",
        },
        visual = "Full forge complex, animated machinery",
        smeltSpeedBonus = 0.35,
        xpRequired = 50000,
        zonesUnlocked = { "TheDeepForge" },
        golemSlotUnlock = 9,
    },
    {
        level = 9,
        displayName = "Elder Forge",
        unlocks = {
            smeltSlots = 10,
            materialSlots = 9,
            maxCraftTier = 4,
            description = "Elder forge with runic inscriptions",
        },
        visual = "Runic glow on all surfaces",
        smeltSpeedBonus = 0.38,
        xpRequired = 80000,
    },
    {
        level = 10,
        displayName = "Ancient Forge",
        unlocks = {
            smeltSlots = 10,
            materialSlots = 10,
            maxCraftTier = 5,
            description = "Ancient kiln, 10 material slots, Tier 5 accessible",
        },
        visual = "Grand forge with elemental aura effects",
        smeltSpeedBonus = 0.40,
        xpRequired = 130000,
    },
}

-- Storage Vault: one-time upgrade taking the offline cap from 4h to 8h (spec 2.3). 24h is Robux/Season Pass.
ForgeData.StorageVault = {
    forgeLevelRequired = 4,
    materialsRequired = {
        { id = "RefinedOre",     qty = 200 },
        { id = "ElementalIngot", qty = 50  },
        { id = "Coal",           qty = 100 },
    },
}

-- ── Level advancements ───────────────────────────────────────────────────────
-- Each Forge level adds permanent boosts on top of its unlocks. They stack (cumulative).
--   mining: Golem mining rate   carry: Golem carry capacity   luck: Golem luck (rare drops)
--   coins:  daily Ember Coin reward
local PERKS = {
    [2]  = { mining = 0.03 },
    [3]  = { carry = 0.05 },
    [4]  = { luck = 0.03 },
    [5]  = { mining = 0.05, coins = 0.10 },
    [6]  = { carry = 0.05 },
    [7]  = { luck = 0.04, mining = 0.03 },
    [8]  = { mining = 0.05, carry = 0.05 },
    [9]  = { luck = 0.05, coins = 0.15 },
    [10] = { mining = 0.06, carry = 0.05, luck = 0.05, coins = 0.25 },
}

ForgeData.PerkLabels = { mining = "mining speed", carry = "carry capacity", luck = "luck", coins = "daily coins" }
ForgeData.PerkOrder  = { "mining", "carry", "luck", "coins" }

-- Perks gained at exactly this level
function ForgeData.PerkAt(level)
    local out = {}
    for k, v in pairs(PERKS[level] or {}) do out[k] = v end
    return out
end

-- Cumulative boosts at this level: { mining, carry, luck, coins } (0 = none)
function ForgeData.TotalPerks(level)
    local total = { mining = 0, carry = 0, luck = 0, coins = 0 }
    for l = 2, math.min(level or 1, #ForgeData.Levels) do
        for k, v in pairs(PERKS[l] or {}) do total[k] += v end
    end
    return total
end

-- "+3% mining speed, +5% carry capacity"
function ForgeData.PerkText(perks)
    local parts = {}
    for _, k in ipairs(ForgeData.PerkOrder) do
        local v = perks[k]
        if v and v > 0 then
            table.insert(parts, string.format("+%d%% %s", math.floor(v * 100 + 0.5), ForgeData.PerkLabels[k]))
        end
    end
    return table.concat(parts, ", ")
end

-- Build lookup by level number
ForgeData.ByLevel = {}
for _, fd in ipairs(ForgeData.Levels) do
    ForgeData.ByLevel[fd.level] = fd
end

function ForgeData.Get(level)
    return ForgeData.ByLevel[math.clamp(level, 1, #ForgeData.Levels)]
end

-- XP required to go from current level to next
function ForgeData.XPToNextLevel(currentLevel)
    local next = ForgeData.ByLevel[currentLevel + 1]
    if not next then return nil end  -- already max level
    local current = ForgeData.ByLevel[currentLevel]
    return next.xpRequired - current.xpRequired
end

return ForgeData
