-- Sells the standard goods in SupplierData. Server-authoritative: quantity, price, daily limit and
-- the player's coins are all checked here; the client only asks.
local SupplierData      = require(game.ReplicatedStorage.Shared.Data.SupplierData)
local MaterialData      = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SupplierService = {}

-- Today's purchase counters (they reset themselves when the UTC day changes)
local function Counters(data)
    local today = SupplierData.Today()
    local c = data.SupplierPurchases
    if type(c) ~= "table" or c.day ~= today then
        c = { day = today, bought = {} }
        data.SupplierPurchases = c
    end
    return c
end

function SupplierService.GetCatalog(player)
    local data = PlayerDataService.Get(player)
    if not data then return {} end
    local bought = Counters(data).bought
    local list = {}
    for _, item in ipairs(SupplierData.Items) do
        local mat = item.kind == "material" and MaterialData.Get(item.id)
        table.insert(list, {
            id = item.id, kind = item.kind, price = item.price, dailyLimit = item.dailyLimit,
            bought = bought[item.id] or 0,
            name = item.displayName or (mat and mat.displayName) or item.id,
            rarity = mat and mat.rarity or "Common", element = mat and mat.element or nil,
            note = item.note,
        })
    end
    return list
end

-- Returns ok, message
function SupplierService.Buy(player, itemId, quantity)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    if type(itemId) ~= "string" then return false, "Unknown item" end
    if type(quantity) ~= "number" or quantity ~= quantity or quantity < 1 or math.floor(quantity) ~= quantity then
        return false, "Invalid quantity"
    end
    local item = SupplierData.Get(itemId)
    if not item then return false, "The Supplier doesn't sell that" end

    local counters = Counters(data)
    local already = counters.bought[itemId] or 0
    local left = item.dailyLimit - already
    if left <= 0 then return false, "Sold out for today. Stock returns at midnight UTC." end
    if quantity > left then return false, string.format("Only %d left today", left) end

    local cost = item.price * quantity
    if (data.EmberCoins or 0) < cost then
        return false, string.format("You need %d coins (you have %d)", cost, data.EmberCoins or 0)
    end

    data.EmberCoins = data.EmberCoins - cost
    counters.bought[itemId] = already + quantity
    if item.kind == "speedup" then
        data.SpeedUps = (data.SpeedUps or 0) + quantity
    else
        PlayerDataService.AddMaterial(player, itemId, quantity)
    end
    PlayerDataService.MarkDirty(player)
    return true, string.format("Bought %d for %d coins", quantity, cost)
end

-- ── Selling ───────────────────────────────────────────────────────────────────
local function SoldToday(data)
    local c = data.SupplierSales
    local today = SupplierData.Today()
    if type(c) ~= "table" or c.day ~= today then
        c = { day = today, earned = 0 }
        data.SupplierSales = c
    end
    return c
end

-- What the Supplier will buy, what you hold, and how much of today's allowance is left
function SupplierService.GetBuyList(player)
    local data = PlayerDataService.Get(player)
    if not data then return { items = {}, cap = 0, earned = 0 } end
    local sales = SoldToday(data)
    local items = {}
    for id, price in pairs(SupplierData.SellPrices) do
        local have = data.Inventory[id] or 0
        local mat = MaterialData.Get(id)
        if have > 0 and mat then
            table.insert(items, { id = id, name = mat.displayName, price = price, have = have, rarity = mat.rarity, element = mat.element })
        end
    end
    table.sort(items, function(a, b) return a.price > b.price or (a.price == b.price and a.id < b.id) end)
    return { items = items, cap = SupplierData.SellCap(data), earned = sales.earned }
end

-- Returns ok, message. Sells as many of `quantity` as today's allowance allows.
function SupplierService.Sell(player, itemId, quantity)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    if type(itemId) ~= "string" then return false, "Unknown item" end
    if type(quantity) ~= "number" or quantity ~= quantity or quantity < 1 or math.floor(quantity) ~= quantity then
        return false, "Invalid quantity"
    end
    local price = SupplierData.SellPrices[itemId]
    if not price then return false, "The Supplier doesn't buy that" end
    local have = data.Inventory[itemId] or 0
    if have < quantity then return false, string.format("You only have %d", have) end

    local sales = SoldToday(data)
    local room = SupplierData.SellCap(data) - sales.earned
    if room < price then return false, "You've reached today's selling limit. It resets at midnight UTC." end
    local qty = math.min(quantity, math.floor(room / price))

    if not PlayerDataService.RemoveMaterial(player, itemId, qty) then return false, "You don't have enough" end
    local coins = qty * price
    data.EmberCoins = (data.EmberCoins or 0) + coins
    sales.earned = sales.earned + coins
    PlayerDataService.MarkDirty(player)
    local note = qty < quantity and string.format(" (limit reached: kept %d)", quantity - qty) or ""
    return true, string.format("Sold %d for %d coins%s", qty, coins, note)
end

return SupplierService
