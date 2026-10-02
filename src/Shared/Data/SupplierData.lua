-- The Forge Supplier: standard goods that are always in stock, bought with Ember Coins.
-- It keeps the Market useful when few players have listed anything, and gives coins something to buy.
-- Prices and daily limits are deliberately modest so the Supplier can't replace mining, and Rare or
-- better materials are never sold (those stay a reward for play and for the player market).
local SupplierData = {}

SupplierData.Items = {
    -- Everyday raw materials
    { id = "BasicOre",       kind = "material", price = 3,   dailyLimit = 600, note = "Needed for every Tier 1 Golem" },
    { id = "Coal",           kind = "material", price = 4,   dailyLimit = 300, note = "Fuel for Tier 1 crafting" },
    { id = "IgniteOre",      kind = "material", price = 5,   dailyLimit = 300 },
    { id = "GraniteShard",   kind = "material", price = 5,   dailyLimit = 300 },
    { id = "GlacialCrystal", kind = "material", price = 6,   dailyLimit = 300 },
    { id = "ChargedFlint",   kind = "material", price = 6,   dailyLimit = 300 },
    { id = "ShadowDust",     kind = "material", price = 18,  dailyLimit = 60,  note = "Opens the Void line" },
    -- Ready-made (saves smelting time, costs more)
    { id = "RefinedOre",     kind = "material", price = 14,  dailyLimit = 100 },
    { id = "EmberDust",      kind = "material", price = 30,  dailyLimit = 40  },
    -- Convenience
    { id = "SpeedUp",        kind = "speedup",  price = 600, dailyLimit = 2, displayName = "Smelt Speed-Up",
      note = "Instantly finish one smelt" },
}

-- ── Selling surplus to the Supplier ───────────────────────────────────────────
-- Coins per unit. Only Common/Uncommon materials are bought, and always for far less than the Supplier charges (about a third), so buying and re-selling
-- can never make a profit. Rare and better materials are never bought: they gate Golems and progression and belong to the player market.
SupplierData.SellPrices = {
    BasicOre = 1,  Coal = 1,  IgniteOre = 2,  GraniteShard = 2,  GlacialCrystal = 2,  ChargedFlint = 2,  ShadowDust = 6,
    RefinedOre = 4,  EmberDust = 10,  ElementalIngot = 8,  CrystalFragment = 8,
}

-- How many coins a player can earn from selling in one UTC day. It grows with how far they have got (the faster the game grows for a player, the more their
-- surplus is worth), and is hard-capped so selling stays a supplement to mining, quests and the market.
SupplierData.SELL_CAP_BASE, SupplierData.SELL_CAP_PER_LEVEL, SupplierData.SELL_CAP_PER_FORGE_LEVEL = 250, 20, 15
SupplierData.SELL_CAP_PER_ASCENSION, SupplierData.SELL_CAP_MAX = 250, 5000

function SupplierData.SellCap(data)
    local cap = SupplierData.SELL_CAP_BASE
        + SupplierData.SELL_CAP_PER_LEVEL * (data.PlayerLevel or 1)
        + SupplierData.SELL_CAP_PER_FORGE_LEVEL * (data.ForgeLevel or 1)
        + SupplierData.SELL_CAP_PER_ASCENSION * (data.Ascensions or 0)
    return math.min(SupplierData.SELL_CAP_MAX, cap)
end

function SupplierData.Get(id)
    for _, item in ipairs(SupplierData.Items) do
        if item.id == id then return item end
    end
    return nil
end

-- limits reset at UTC midnight
function SupplierData.Today()
    return math.floor(os.time() / 86400)
end

return SupplierData
