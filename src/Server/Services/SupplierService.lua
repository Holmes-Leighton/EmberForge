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

return SupplierService
