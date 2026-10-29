-- Robux products. Create each one as a *Developer Product* in the Creator Dashboard
-- (Monetization > Developer Products), then paste its numeric ID into `id` below.
-- Products with id = 0 are treated as "not for sale yet": the client shows a notice and
-- the server can never match a receipt to them.
local ProductData = {}

ProductData.Products = {
    -- Convenience
    SpeedUp_x1        = { id = 3716236066, displayName = "Smelt Speed-Up",        robux = 25   },
    SpeedUp_x10       = { id = 3716236262, displayName = "Smelt Speed-Up Pack",   robux = 200  },
    SlotPack_5        = { id = 3716236498, displayName = "+5 Golem Slots (permanent)", robux = 249, stackable = true },
    SlotBoost_7d      = { id = 3716236752, displayName = "Forge Slot Boost (7d)", robux = 149  },
    MaterialMagnet    = { id = 3716236924, displayName = "Material Magnet (24h)", robux = 199  },
    EventCatalyst     = { id = 3716237130, displayName = "Event Catalyst",        robux = 400  },
    LuckBoost_1h      = { id = 3716237869, displayName = "Lucky Boost (1h)",      robux = 49   },
    GrowthTonic_1h    = { id = 3718927703, displayName = "Growth Tonic (1h)",     robux = 49   },
    TowerSkip         = { id = 0,          displayName = "Sky Tower Level Skip",  robux = 29, stackable = true },   -- create the Developer Product, then paste its id (0 = not for sale yet)

    -- Pet eggs (paid random items: odds are shown in the Pets menu; hidden where Roblox restricts them).
    -- `eggId` / `count` tell ShopService how many pets to hatch from PetData.Eggs[eggId].
    RoyalEgg_x1       = { id = 3716238063, displayName = "Royal Egg",        robux = 99,  eggId = "Royal", count = 1  },
    RoyalEgg_x5       = { id = 3716238264, displayName = "Royal Egg x5",     robux = 449, eggId = "Royal", count = 5  },
    RoyalEgg_x10      = { id = 3716238492, displayName = "Royal Egg x10",    robux = 849, eggId = "Royal", count = 10 },

    -- Season Pass
    SeasonPass_Standard = { id = 3716238721, displayName = "Season Pass (Standard)", robux = 699  },
    SeasonPass_Premium  = { id = 3716238846, displayName = "Season Pass (Premium)",  robux = 1299 },

}

-- Permanent unlocks are sold as *Game Passes* (Creator Dashboard > Monetization > Passes): they appear
-- on the game page, are owned forever and can't be bought twice. Paste each pass id below;
-- id = 0 means "not for sale yet". A pass unlocks its mining pad regardless of player level.
ProductData.GamePasses = {
    -- Mining pads (unlock regardless of player level)
    Pad_Copper = { id = 2005088802, padId = "Copper", displayName = "Copper Pad (3x)", robux = 59 },
    Pad_Iron   = { id = 2007026812, padId = "Iron",   displayName = "Iron Pad (9x)",   robux = 259 },
    Pad_Gold   = { id = 2006636813, padId = "Gold",   displayName = "Gold Pad (25x)",  robux = 749 },
    Pad_Legend = { id = 2004944822, padId = "Legend", displayName = "Legend Pad (100x)", robux = 1599 },

    -- Offline storage: 24 hours instead of 8
    Storage24h = { id = 2006894835, storageTier = 2, displayName = "Offline Storage (24h)", robux = 299 },

    -- Forge skins (cosmetic)
    Skin_Basic = { id = 2006990815, cosmeticId = "ForgeSkin_Basic", displayName = "Forge Skin: Basic", robux = 200 },
    Skin_Ember = { id = 2006174780, cosmeticId = "ForgeSkin_Ember", displayName = "Forge Skin: Ember", robux = 300 },
    Skin_Frost = { id = 2006024824, cosmeticId = "ForgeSkin_Frost", displayName = "Forge Skin: Frost", robux = 300 },
    Skin_Storm = { id = 2004932800, cosmeticId = "ForgeSkin_Storm", displayName = "Forge Skin: Storm", robux = 300 },
    Skin_Void  = { id = 2006894840, cosmeticId = "ForgeSkin_Void",  displayName = "Forge Skin: Void",  robux = 400 },
}

-- True if this player's saved data already includes what the pass gives
function ProductData.PassOwned(pass, data)
    if not pass or not data then return false end
    if pass.padId then return (data.UnlockedPads or {})[pass.padId] == true end
    if pass.storageTier then return (data.StorageTier or 0) >= pass.storageTier end
    if pass.cosmeticId then
        for _, id in ipairs(data.OwnedCosmetics or {}) do if id == pass.cosmeticId then return true end end
    end
    return false
end

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
