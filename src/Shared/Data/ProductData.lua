-- Robux products. Create each one as a *Developer Product* in the Creator Dashboard
-- (Monetization > Developer Products), then paste its numeric ID into `id` below.
-- Products with id = 0 are treated as "not for sale yet": the client shows a notice and
-- the server can never match a receipt to them.
local ProductData = {}

ProductData.Products = {
    -- Convenience
    SpeedUp_x1        = { id = 0, displayName = "Smelt Speed-Up",        robux = 25   },
    SpeedUp_x10       = { id = 0, displayName = "Smelt Speed-Up Pack",   robux = 200  },
    StorageExpansion  = { id = 0, displayName = "Storage Expansion",     robux = 299  },
    SlotBoost_7d      = { id = 0, displayName = "Forge Slot Boost (7d)", robux = 149  },
    MaterialMagnet    = { id = 0, displayName = "Material Magnet (24h)", robux = 199  },
    EventCatalyst     = { id = 0, displayName = "Event Catalyst",        robux = 400  },

    -- Season Pass
    SeasonPass_Standard = { id = 0, displayName = "Season Pass (Standard)", robux = 699  },
    SeasonPass_Premium  = { id = 0, displayName = "Season Pass (Premium)",  robux = 1299 },

    -- Forge skins (cosmetic)
    ForgeSkin_Basic = { id = 0, displayName = "Forge Skin: Basic", robux = 200, cosmeticId = "ForgeSkin_Basic" },
    ForgeSkin_Ember = { id = 0, displayName = "Forge Skin: Ember", robux = 300, cosmeticId = "ForgeSkin_Ember" },
    ForgeSkin_Frost = { id = 0, displayName = "Forge Skin: Frost", robux = 300, cosmeticId = "ForgeSkin_Frost" },
    ForgeSkin_Storm = { id = 0, displayName = "Forge Skin: Storm", robux = 300, cosmeticId = "ForgeSkin_Storm" },
    ForgeSkin_Void  = { id = 0, displayName = "Forge Skin: Void",  robux = 400, cosmeticId = "ForgeSkin_Void"  },
}

-- Permanent unlocks are sold as *Game Passes* (Creator Dashboard > Monetization > Passes): they appear
-- on the game page, are owned forever and can't be bought twice. Paste each pass id below;
-- id = 0 means "not for sale yet". A pass unlocks its mining pad regardless of player level.
ProductData.GamePasses = {
    Pad_Copper = { id = 0, padId = "Copper", displayName = "Copper Pad (3x)", robux = 149 },
    Pad_Iron   = { id = 0, padId = "Iron",   displayName = "Iron Pad (5x)",   robux = 299 },
    Pad_Gold   = { id = 0, padId = "Gold",   displayName = "Gold Pad (10x)",  robux = 599 },
}

-- The game pass that unlocks a pad: returns key, pass (nil for pads that can't be bought)
function ProductData.PassForPad(padId)
    for key, pass in pairs(ProductData.GamePasses) do
        if pass.padId == padId then return key, pass end
    end
    return nil
end

function ProductData.PassIsAvailable(key)
    local p = ProductData.GamePasses[key]
    return p ~= nil and p.id ~= 0
end

-- Returns the product key for a numeric Roblox product id (nil if unknown / unconfigured)
function ProductData.KeyForId(productId)
    if type(productId) ~= "number" or productId == 0 then return nil end
    for key, product in pairs(ProductData.Products) do
        if product.id == productId then return key end
    end
    return nil
end

function ProductData.IsAvailable(key)
    local p = ProductData.Products[key]
    return p ~= nil and p.id ~= 0
end

return ProductData
