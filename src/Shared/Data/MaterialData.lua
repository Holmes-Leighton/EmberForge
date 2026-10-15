-- All material definitions: tiers, smelt times, associated elements.
local MaterialData = {}

-- Rarity tiers
MaterialData.Rarity = {
    Common    = "Common",
    Uncommon  = "Uncommon",
    Rare      = "Rare",
    Epic      = "Epic",
    Legendary = "Legendary",
}

-- Raw materials (mined by Golems, must be smelted before crafting)
MaterialData.Raw = {
    -- Universal basics
    BasicOre = {
        id = "BasicOre", displayName = "Basic Ore",
        rarity = "Common", element = nil,
        smeltTime = 300,           -- 5 minutes in seconds
        smeltOutput = "RefinedOre",
        smeltRatio = 1,            -- 1 BasicOre → 1 RefinedOre
    },
    Coal = {
        id = "Coal", displayName = "Coal",
        rarity = "Common", element = nil,
        smeltTime = 0,             -- coal is a fuel/catalyst, not smelted
        smeltOutput = nil,
    },

    -- Ember (Fire) materials
    IgniteOre = {
        id = "IgniteOre", displayName = "Ignite Ore",
        rarity = "Common", element = "Ember",
        smeltTime = 600,
        smeltOutput = "EmberDust",
        smeltRatio = 2,
    },
    MoltenCore = {
        id = "MoltenCore", displayName = "Molten Core",
        rarity = "Rare", element = "Ember",
        smeltTime = 3600,
        smeltOutput = "EssenceShard",
        smeltRatio = 1,
    },

    -- Stone (Earth) materials
    GraniteShard = {
        id = "GraniteShard", displayName = "Granite Shard",
        rarity = "Common", element = "Stone",
        smeltTime = 600,
        smeltOutput = "ElementalIngot",
        smeltRatio = 2,
    },
    AncientBedrock = {
        id = "AncientBedrock", displayName = "Ancient Bedrock",
        rarity = "Rare", element = "Stone",
        smeltTime = 5400,
        smeltOutput = "PureIngot",
        smeltRatio = 1,
    },

    -- Frost (Ice) materials
    GlacialCrystal = {
        id = "GlacialCrystal", displayName = "Glacial Crystal",
        rarity = "Common", element = "Frost",
        smeltTime = 900,
        smeltOutput = "CrystalFragment",
        smeltRatio = 3,
    },
    EternalIce = {
        id = "EternalIce", displayName = "Eternal Ice",
        rarity = "Rare", element = "Frost",
        smeltTime = 7200,
        smeltOutput = "EssenceShard",
        smeltRatio = 1,
    },

    -- Storm (Lightning) materials
    ChargedFlint = {
        id = "ChargedFlint", displayName = "Charged Flint",
        rarity = "Common", element = "Storm",
        smeltTime = 600,
        smeltOutput = "ElementalIngot",
        smeltRatio = 2,
    },
    ThunderShard = {
        id = "ThunderShard", displayName = "Thunder Shard",
        rarity = "Rare", element = "Storm",
        smeltTime = 5400,
        smeltOutput = "PureIngot",
        smeltRatio = 1,
    },

    -- Void (Dark) materials
    ShadowDust = {
        id = "ShadowDust", displayName = "Shadow Dust",
        rarity = "Uncommon", element = "Void",
        smeltTime = 1800,
        smeltOutput = "VoidEssence",
        smeltRatio = 5,
    },
    VoidEssence = {
        id = "VoidEssence", displayName = "Void Essence",
        rarity = "Epic", element = "Void",
        smeltTime = 0,  -- already refined
        smeltOutput = nil,
    },

    -- Deep Forge materials
    PrimordialOre = {
        id = "PrimordialOre", displayName = "Primordial Ore",
        rarity = "Legendary", element = nil,
        smeltTime = 14400,  -- 4 hours
        smeltOutput = "PrimordialIngot",
        smeltRatio = 1,
    },
}

-- Refined/processed materials (outputs of smelting)
MaterialData.Refined = {
    RefinedOre = {
        id = "RefinedOre", displayName = "Refined Ore",
        rarity = "Common", element = nil,
        tradeable = true,
    },
    EmberDust = {
        id = "EmberDust", displayName = "Ember Dust",
        rarity = "Uncommon", element = "Ember",
        tradeable = true,
    },
    ElementalIngot = {
        id = "ElementalIngot", displayName = "Elemental Ingot",
        rarity = "Uncommon", element = nil,
        tradeable = true,
    },
    CrystalFragment = {
        id = "CrystalFragment", displayName = "Crystal Fragment",
        rarity = "Uncommon", element = "Frost",
        tradeable = true,
    },
    EssenceShard = {
        id = "EssenceShard", displayName = "Essence Shard",
        rarity = "Rare", element = nil,
        tradeable = true,
    },
    PureIngot = {
        id = "PureIngot", displayName = "Pure Ingot",
        rarity = "Epic", element = nil,
        tradeable = true,
    },
    PrimordialIngot = {
        id = "PrimordialIngot", displayName = "Primordial Ingot",
        rarity = "Legendary", element = nil,
        tradeable = true,
    },
}

-- Event/special materials
MaterialData.Special = {
    EventCatalyst = {
        id = "EventCatalyst", displayName = "Event Catalyst",
        rarity = "Legendary", element = nil,
        tradeable = false,  -- earned in-event or purchased with Robux
    },
}

-- Quarry-exclusive materials: they can only be made by a player's own Quarry (see QuarryData), and are tradeable
MaterialData.Quarry = {
    TemperedEmber = { id = "TemperedEmber", displayName = "Tempered Ember", rarity = "Rare",      element = "Ember", tradeable = true },
    Stormglass    = { id = "Stormglass",    displayName = "Stormglass",     rarity = "Rare",      element = "Storm", tradeable = true },
    FrostfireGem  = { id = "FrostfireGem",  displayName = "Frostfire Gem",  rarity = "Epic",      element = nil,     tradeable = true },
    Voidstone     = { id = "Voidstone",     displayName = "Voidstone",      rarity = "Epic",      element = "Void",  tradeable = true },
    PrismaticShard = { id = "PrismaticShard", displayName = "Prismatic Shard", rarity = "Legendary", element = nil,   tradeable = true },
}

-- Flat lookup by id
MaterialData.All = {}
for _, tbl in pairs({ MaterialData.Raw, MaterialData.Refined, MaterialData.Special, MaterialData.Quarry }) do
    for id, mat in pairs(tbl) do
        MaterialData.All[id] = mat
    end
end

function MaterialData.Get(id)
    return MaterialData.All[id]
end

-- What each material looks like, for the "+N Basic Ore" pick-up text: ore is grey, coal is charcoal, ember things are orange, frost is icy blue...
local C = Color3.fromRGB
MaterialData.Colors = {
    BasicOre = C(176, 182, 194),    Coal = C(88, 90, 100),
    IgniteOre = C(255, 122, 52),    MoltenCore = C(255, 90, 30),
    GraniteShard = C(184, 158, 124), AncientBedrock = C(130, 108, 90),
    GlacialCrystal = C(130, 215, 255), EternalIce = C(196, 240, 255),
    ChargedFlint = C(255, 222, 80), ThunderShard = C(120, 180, 255),
    ShadowDust = C(150, 110, 210),  VoidEssence = C(176, 64, 235),
    PrimordialOre = C(255, 176, 60),
    RefinedOre = C(208, 218, 228),  EmberDust = C(255, 150, 82),
    ElementalIngot = C(218, 186, 120), CrystalFragment = C(150, 228, 250),
    EssenceShard = C(120, 232, 204), PureIngot = C(238, 240, 255),
    PrimordialIngot = C(255, 204, 72),
    EventCatalyst = C(255, 100, 180),
    TemperedEmber = C(255, 104, 56), Stormglass = C(110, 200, 255),
    FrostfireGem = C(112, 214, 232), Voidstone = C(154, 72, 214), PrismaticShard = C(255, 132, 222),
}

-- The material's own colour, or nil when it has none (callers fall back to the rarity colour)
function MaterialData.Color(id)
    return MaterialData.Colors[id]
end

return MaterialData
