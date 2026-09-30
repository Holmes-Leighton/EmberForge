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
