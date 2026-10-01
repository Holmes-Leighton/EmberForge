-- The Forge Builder: pieces you buy with Ember Coins and place on your own forge plot.
-- Perks are small and capped (BUILD_CAP per stat) so a forge is mostly about looking good; nothing here costs Robux.
-- `model` is the child of AssetData.BuildPack; `height` is the size in studs the piece is shown at (the generated
-- meshes come out a little off-scale, so the loader's size is not trusted).
local ForgeBuildData = {}

ForgeBuildData.BUILD_CAP     = 0.20     -- most any one stat can gain from all pieces together
ForgeBuildData.MAX_PLACED    = 30      -- pieces on one plot
ForgeBuildData.PLOT_HALF     = 26       -- pieces stay within this many studs of the plot centre
ForgeBuildData.CLEAR_HALF    = 10       -- keep the middle (the forge itself) free
ForgeBuildData.SPACING       = 2.5      -- minimum distance between two pieces
ForgeBuildData.GRID          = 1        -- placement snaps to this many studs
ForgeBuildData.RESTOCK_SECONDS = 300    -- the shop restocks every 5 minutes
ForgeBuildData.BUY_PER_RESTOCK = 3      -- how many of one piece a player can buy per restock
ForgeBuildData.SELL_BACK     = 0.5      -- fraction of the price refunded when a piece is removed for good

-- rarity -> chance a piece is in stock in a given restock
ForgeBuildData.StockChance = { Common = 0.9, Uncommon = 0.6, Rare = 0.3, Epic = 0.15 }

-- category "fire" pieces do not stack: only your best one counts
ForgeBuildData.Items = {
    { id = "Hearth",      name = "Stone Hearth",     category = "fire",  rarity = "Common",   price = 600,   height = 4.5, maxOwned = 1, perk = { rate = 0.03 }, blurb = "A humble hearth. +3% mining speed", color = Color3.fromRGB(150, 120, 100) },
    { id = "IronFurnace", name = "Iron Furnace",     category = "fire",  rarity = "Uncommon", price = 6000,  height = 7,   maxOwned = 1, perk = { rate = 0.06 }, blurb = "Hotter and steadier. +6% mining speed", color = Color3.fromRGB(180, 180, 195) },
    { id = "MoltenForge", name = "Molten Forge",     category = "fire",  rarity = "Rare",     price = 40000, height = 8,   maxOwned = 1, perk = { rate = 0.10 }, blurb = "Runs on lava. +10% mining speed", color = Color3.fromRGB(255, 140, 50) },

    { id = "MineCart",    name = "Mine Cart",        category = "tools", rarity = "Common",   price = 350,   height = 3.5, maxOwned = 3, perk = { carry = 0.03 }, blurb = "+3% carry capacity each", color = Color3.fromRGB(170, 120, 70) },
    { id = "OreCrates",   name = "Ore Crates",       category = "tools", rarity = "Common",   price = 450,   height = 3,   maxOwned = 3, perk = { carry = 0.03 }, blurb = "+3% carry capacity each", color = Color3.fromRGB(190, 150, 90) },
    { id = "PickaxeRack", name = "Pickaxe Rack",     category = "tools", rarity = "Common",   price = 500,   height = 5,   maxOwned = 2, perk = { rate = 0.02 }, blurb = "+2% mining speed each", color = Color3.fromRGB(150, 110, 70) },
    { id = "HammerRack",  name = "Hammer Rack",      category = "tools", rarity = "Common",   price = 500,   height = 3.8, maxOwned = 2, perk = { eff = 0.02 }, blurb = "+2% efficiency each", color = Color3.fromRGB(140, 140, 150) },
    { id = "Grindstone",  name = "Grindstone",       category = "tools", rarity = "Uncommon", price = 1500,  height = 4,   maxOwned = 2, perk = { wear = 0.03 }, blurb = "Golems wear 3% slower each", color = Color3.fromRGB(150, 150, 160) },
    { id = "QuenchBarrel", name = "Quench Barrel",   category = "tools", rarity = "Uncommon", price = 1200,  height = 3.5, maxOwned = 2, perk = { wear = 0.02 }, blurb = "Golems wear 2% slower each", color = Color3.fromRGB(110, 150, 190) },
    { id = "Bellows",     name = "Forge Bellows",    category = "tools", rarity = "Uncommon", price = 2000,  height = 3,   maxOwned = 2, perk = { rate = 0.03 }, blurb = "+3% mining speed each", color = Color3.fromRGB(200, 90, 60) },
    { id = "Workbench",   name = "Golem Workbench",  category = "tools", rarity = "Uncommon", price = 2500,  height = 3.5, maxOwned = 1, perk = { eff = 0.04 }, blurb = "+4% efficiency", color = Color3.fromRGB(160, 120, 80) },
    { id = "StorageShed", name = "Storage Shed",     category = "tools", rarity = "Rare",     price = 9000,  height = 8,   maxOwned = 1, perk = { carry = 0.06 }, blurb = "+6% carry capacity", color = Color3.fromRGB(170, 130, 90) },
    { id = "Waterwheel",  name = "Waterwheel",       category = "tools", rarity = "Rare",     price = 12000, height = 9,   maxOwned = 1, perk = { rate = 0.04 }, blurb = "+4% mining speed", color = Color3.fromRGB(150, 110, 70) },
    { id = "CrystalPedestal", name = "Crystal Pedestal", category = "tools", rarity = "Epic", price = 20000, height = 5,  maxOwned = 1, perk = { luck = 0.03 }, blurb = "+3% luck", color = Color3.fromRGB(150, 210, 255) },

    { id = "LanternPost", name = "Lantern Post",     category = "decor", rarity = "Common",   price = 120,   height = 7,   maxOwned = 6, blurb = "Warm light for your plot", color = Color3.fromRGB(255, 200, 100) },
    { id = "BannerFlag",  name = "Ember Banner",     category = "decor", rarity = "Common",   price = 200,   height = 9,   maxOwned = 4, blurb = "Fly your colours", color = Color3.fromRGB(220, 80, 50) },
    { id = "ChimneyStack", name = "Chimney Stack",   category = "decor", rarity = "Uncommon", price = 700,   height = 12,  maxOwned = 2, blurb = "Smoke on the skyline", color = Color3.fromRGB(160, 90, 70) },
    -- second batch
    { id = "BarrelStack", name = "Barrel Stack",     category = "tools", rarity = "Common",   price = 600,   height = 4,   maxOwned = 2, perk = { wear = 0.02 }, blurb = "Golems wear 2% slower each", color = Color3.fromRGB(150, 110, 70) },
    { id = "OrePile",     name = "Ore Pile",         category = "tools", rarity = "Uncommon", price = 1000,  height = 3,   maxOwned = 2, perk = { carry = 0.02 }, blurb = "+2% carry capacity each", color = Color3.fromRGB(200, 120, 200) },
    { id = "MineEntrance", name = "Mine Entrance",   category = "tools", rarity = "Rare",     price = 8000,  height = 8,   maxOwned = 1, perk = { rate = 0.03 }, blurb = "+3% mining speed", color = Color3.fromRGB(130, 100, 70) },
    { id = "CrystalCluster", name = "Crystal Cluster", category = "tools", rarity = "Epic",   price = 15000, height = 7,   maxOwned = 1, perk = { luck = 0.02 }, blurb = "+2% luck", color = Color3.fromRGB(170, 130, 255) },
    { id = "Fence",       name = "Wooden Fence",     category = "decor", rarity = "Common",   price = 150,   height = 3,   maxOwned = 12, blurb = "Mark out your plot", color = Color3.fromRGB(160, 120, 80) },
    { id = "Signpost",    name = "Signpost",         category = "decor", rarity = "Common",   price = 180,   height = 6,   maxOwned = 3, blurb = "Which way to the forge?", color = Color3.fromRGB(160, 120, 80) },
    { id = "Campfire",    name = "Campfire",         category = "decor", rarity = "Common",   price = 400,   height = 2.5, maxOwned = 2, blurb = "A cosy fire with log seats", color = Color3.fromRGB(255, 150, 60) },
    { id = "Well",        name = "Stone Well",       category = "decor", rarity = "Uncommon", price = 1800,  height = 6,   maxOwned = 1, blurb = "Fresh water for the smiths", color = Color3.fromRGB(150, 150, 160) },
    { id = "DisplayStand", name = "Display Stand",   category = "decor", rarity = "Uncommon", price = 2200,  height = 4,   maxOwned = 3, blurb = "Show off a trophy", color = Color3.fromRGB(180, 200, 220) },
    { id = "Fountain",    name = "Anvil Fountain",   category = "decor", rarity = "Rare",     price = 7000,  height = 6,   maxOwned = 1, blurb = "A fountain fit for a forgemaster", color = Color3.fromRGB(230, 200, 100) },
    { id = "Throne",      name = "Forgemaster's Throne", category = "decor", rarity = "Epic", price = 25000, height = 6,   maxOwned = 1, blurb = "Sit like a king of the forge", color = Color3.fromRGB(240, 200, 90) },
    { id = "GemLamp",    name = "Gem Lamp",         category = "decor", rarity = "Uncommon", price = 900,   height = 5,   maxOwned = 4, blurb = "A glowing gemstone lamp", color = Color3.fromRGB(100, 170, 255) },
    { id = "TrophyStatue", name = "Trophy Statue",   category = "decor", rarity = "Rare",     price = 5000,  height = 8,   maxOwned = 1, blurb = "A hero of the forge", color = Color3.fromRGB(240, 200, 90) },
}

local byId = {}
for _, it in ipairs(ForgeBuildData.Items) do byId[it.id] = it end

function ForgeBuildData.Get(id) return byId[id] end

-- A cheap deterministic hash so every server agrees on the stock without any storage
local function Hash(slot, id)
    local h = (slot % 1000003) * 2654435761
    for i = 1, #id do h = (h * 31 + string.byte(id, i)) % 4294967296 end
    return (h % 10000) / 10000
end

function ForgeBuildData.SlotOf(now) return math.floor(now / ForgeBuildData.RESTOCK_SECONDS) end

-- Is this piece in the shop in this restock? The starter fire and the cheapest decor are always there so a new
-- player is never left with an empty shop.
function ForgeBuildData.InStock(id, slot)
    local it = byId[id]
    if not it then return false end
    if it.id == "Hearth" or it.id == "LanternPost" or it.id == "MineCart" then return true end
    return Hash(slot, id) < (ForgeBuildData.StockChance[it.rarity] or 0.5)
end

function ForgeBuildData.Stock(now)
    local slot = ForgeBuildData.SlotOf(now)
    local list = {}
    for _, it in ipairs(ForgeBuildData.Items) do
        if ForgeBuildData.InStock(it.id, slot) then table.insert(list, it.id) end
    end
    return list, (slot + 1) * ForgeBuildData.RESTOCK_SECONDS     -- the pieces, and when the shop restocks
end

-- Total stat bonuses from the placed pieces: { rate, carry, eff, wear, luck }, each capped at BUILD_CAP.
-- Only the best "fire" counts; every other piece stacks.
function ForgeBuildData.Perks(placed)
    local total = { rate = 0, carry = 0, eff = 0, wear = 0, luck = 0 }
    local bestFire
    for _, p in ipairs(placed or {}) do
        local it = byId[p.id]
        if it and it.perk then
            if it.category == "fire" then
                if not bestFire or (it.perk.rate or 0) > (bestFire.perk.rate or 0) then bestFire = it end
            else
                for stat, v in pairs(it.perk) do total[stat] = total[stat] + v end
            end
        end
    end
    if bestFire then
        for stat, v in pairs(bestFire.perk) do total[stat] = total[stat] + v end
    end
    for stat, v in pairs(total) do total[stat] = math.min(ForgeBuildData.BUILD_CAP, v) end
    return total
end

return ForgeBuildData
