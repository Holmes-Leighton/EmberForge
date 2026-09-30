-- Daily, weekly and lifetime challenge definitions.
local ChallengeData = {}

ChallengeData.Type = {
    Daily    = "daily",
    Weekly   = "weekly",
    Lifetime = "lifetime",
}

-- ── Daily Challenges (rotate from pool) ────────────────────────────────────
ChallengeData.Daily = {
    {
        id = "daily_smelt_20", displayName = "Smelt 20 Ore",
        description = "Smelt any 20 raw material items.",
        type = ChallengeData.Type.Daily,
        trackEvent = "SmeltComplete",
        target = 20,
        rewards = { coins = 50, xp = 100, materials = { { id = "RefinedOre", qty = 10 } } },
    },
    {
        id = "daily_collect_3golems", displayName = "Collect from 3 Golems",
        description = "Collect resources from at least 3 deployed Golems.",
        type = ChallengeData.Type.Daily,
        trackEvent = "GolemCollect",
        target = 3,
        rewards = { coins = 50, xp = 100, materials = { { id = "EmberDust", qty = 5 } } },
    },
    {
        id = "daily_trade_1item", displayName = "Trade 1 Item",
        description = "Complete one trade with another player.",
        type = ChallengeData.Type.Daily,
        trackEvent = "TradeComplete",
        target = 1,
        rewards = { coins = 75, xp = 150, materials = { { id = "CrystalFragment", qty = 5 } } },
    },
    {
        id = "daily_smelt_rare", displayName = "Smelt a Rare Material",
        description = "Smelt at least 1 rare-tier raw material.",
        type = ChallengeData.Type.Daily,
        trackEvent = "SmeltRare",
        target = 1,
        rewards = { coins = 100, xp = 200, materials = { { id = "EssenceShard", qty = 2 } } },
    },
    {
        id = "daily_deploy_golem", displayName = "Deploy a Golem",
        description = "Deploy any Golem to a mining zone.",
        type = ChallengeData.Type.Daily,
        trackEvent = "GolemDeploy",
        target = 1,
        rewards = { coins = 30, xp = 60 },
    },
    {
        id = "daily_visit_forge", displayName = "Visit Another Forge",
        description = "Visit any other player's forge.",
        type = ChallengeData.Type.Daily,
        trackEvent = "ForgeVisit",
        target = 1,
        rewards = { coins = 40, xp = 80 },
    },
    {
        id = "daily_craft_golem", displayName = "Craft a Golem",
        description = "Craft any Golem at your forge.",
        type = ChallengeData.Type.Daily,
        trackEvent = "GolemCrafted",
        target = 1,
        rewards = { coins = 60, xp = 120, materials = { { id = "RefinedOre", qty = 15 } } },
    },
}

-- ── Weekly Challenges ───────────────────────────────────────────────────────
ChallengeData.Weekly = {
    {
        id = "weekly_craft_tier3", displayName = "Craft a Tier 3 Golem",
        description = "Craft any Tier 3 Core Golem.",
        type = ChallengeData.Type.Weekly,
        trackEvent = "GolemCrafted",
        trackFilter = { minTier = 3 },
        target = 1,
        rewards = {
            coins = 500, xp = 1000,
            blueprints = { "BP_Frost_T3" },
            materials = { { id = "EssenceShard", qty = 5 } },
        },
    },
    {
        id = "weekly_new_forge_level", displayName = "Reach a New Forge Level",
        description = "Level up your Forge.",
        type = ChallengeData.Type.Weekly,
        trackEvent = "ForgeLevelUp",
        target = 1,
        rewards = { coins = 300, xp = 600, blueprints = { "BP_Storm_T3" },
                    materials = { { id = "ElementalIngot", qty = 20 } } },
    },
    {
        id = "weekly_discover_zone", displayName = "Discover a New Mining Zone",
        description = "Unlock a new mining zone by crafting the required Golem.",
        type = ChallengeData.Type.Weekly,
        trackEvent = "ZoneUnlocked",
        target = 1,
        rewards = { coins = 400, xp = 800, blueprints = { "BP_Frost_T2" },
                    materials = { { id = "CrystalFragment", qty = 15 } } },
    },
    {
        id = "weekly_smelt_100", displayName = "Smelt 100 Items",
        description = "Smelt 100 raw materials throughout the week.",
        type = ChallengeData.Type.Weekly,
        trackEvent = "SmeltComplete",
        target = 100,
        rewards = { coins = 600, xp = 1200, blueprints = { "BP_Storm_T2" } },
    },
    {
        id = "weekly_trade_5", displayName = "Complete 5 Trades",
        description = "Trade with other players 5 times this week.",
        type = ChallengeData.Type.Weekly,
        trackEvent = "TradeComplete",
        target = 5,
        rewards = { coins = 500, xp = 1000, blueprints = { "BP_Void_T4" },
                    materials = { { id = "PureIngot", qty = 2 } } },
    },
    -- Event grind (spec 8.1: Event Catalysts must be earnable through play)
    {
        id = "weekly_mine_20000", displayName = "Mine 20,000 Resources",
        description = "Have your Golems mine 20,000 resources this week.",
        type = ChallengeData.Type.Weekly,
        trackEvent = "ResourcesMined",
        target = 20000,
        rewards = { coins = 400, xp = 800, materials = { { id = "EventCatalyst", qty = 1 } } },
    },
    {
        id = "weekly_craft_10", displayName = "Craft 10 Golems",
        description = "Craft 10 Golems of any kind this week.",
        type = ChallengeData.Type.Weekly,
        trackEvent = "GolemCrafted",
        target = 10,
        rewards = { coins = 500, xp = 1000, materials = { { id = "EventCatalyst", qty = 1 } } },
    },
}

-- ── Lifetime Achievements ───────────────────────────────────────────────────
ChallengeData.Lifetime = {
    {
        id = "ach_first_golem", displayName = "Forge Born",
        description = "Craft your first Golem.",
        type = ChallengeData.Type.Lifetime,
        trackEvent = "GolemCrafted",
        target = 1,
        rewards = { title = "Forge Initiate", xp = 500 },
    },
    {
        id = "ach_first_tier2", displayName = "Rising Ember",
        description = "Craft your first Tier 2 Golem.",
        type = ChallengeData.Type.Lifetime,
        trackEvent = "GolemCrafted",
        trackFilter = { minTier = 2 },
        target = 1,
        rewards = { title = "Ember Crafter", xp = 1000, golemSlotUnlock = true },
    },
    {
        id = "ach_first_tier4", displayName = "Forgemaster",
        description = "Craft your first Tier 4 Golem.",
        type = ChallengeData.Type.Lifetime,
        trackEvent = "GolemCrafted",
        trackFilter = { minTier = 4 },
        target = 1,
        rewards = { title = "Forgemaster", xp = 5000, golemSlotUnlock = true },
    },
    {
        id = "ach_all_elements", displayName = "Elemental Master",
        description = "Craft at least one Golem of every element.",
        type = ChallengeData.Type.Lifetime,
        trackEvent = "AllElementsCrafted",
        target = 1,
        rewards = { title = "Elemental Master", xp = 3000, blueprints = { "BP_Storm_T4" },
                    accessories = { "AccessoryAllElement" } },
    },
    {
        id = "ach_forge_mastery", displayName = "Forge Mastery",
        description = "Reach Forge Level 5.",
        type = ChallengeData.Type.Lifetime,
        trackEvent = "ForgeLevelUp",
        trackFilter = { minLevel = 5 },
        target = 1,
        rewards = { title = "Forge Artisan", xp = 4000, golemSlotUnlock = true },
    },
    {
        id = "ach_100_trades", displayName = "Market Baron",
        description = "Complete 100 trades.",
        type = ChallengeData.Type.Lifetime,
        trackEvent = "TradeComplete",
        target = 100,
        rewards = { title = "Market Baron", xp = 8000 },
    },
    {
        id = "ach_max_mastery", displayName = "Elemental Sage",
        description = "Reach Mastery Level 20 in any element.",
        type = ChallengeData.Type.Lifetime,
        trackEvent = "MasteryLevel20",
        target = 1,
        rewards = { title = "Elemental Sage", xp = 15000, accessories = { "AccessoryElementalAura" } },
    },
}

-- Flat lookup by id for server tracking
ChallengeData.All = {}
for _, c in ipairs(ChallengeData.Daily) do   ChallengeData.All[c.id] = c end
for _, c in ipairs(ChallengeData.Weekly) do  ChallengeData.All[c.id] = c end
for _, c in ipairs(ChallengeData.Lifetime) do ChallengeData.All[c.id] = c end

function ChallengeData.Get(id)
    return ChallengeData.All[id]
end

return ChallengeData
