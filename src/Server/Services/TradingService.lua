-- Player-to-player trading and the Forge Market (player-run marketplace).

local DataStoreService  = game:GetService("DataStoreService")
local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TradingService = {}

-- Pending trade sessions: tradeId → { offererId, targetId, offererItems, targetItems, confirmed }
local pendingTrades = {}

-- Market listings: in-memory cache backed by DataStore
local marketListings = {}  -- listingId → listing
local marketStore    = DataStoreService:GetDataStore("EmberForge_Market_v1")
local MARKET_KEY     = "listings_v1"

local function PersistMarket()
    task.spawn(function()
        pcall(function()
            marketStore:SetAsync(MARKET_KEY, marketListings)
        end)
    end)
end

-- Load persisted listings on server start
task.spawn(function()
    local ok, saved = pcall(function()
        return marketStore:GetAsync(MARKET_KEY)
    end)
    if ok and type(saved) == "table" then
        marketListings = saved
    end
end)

-- ── Direct Trading ────────────────────────────────────────────────────────────
function TradingService.InitiateTrade(offererPlayer, targetPlayer)
    local tradeId = Utils.GenerateId()
    pendingTrades[tradeId] = {
        tradeId     = tradeId,
        offererId   = offererPlayer.UserId,
        targetId    = targetPlayer.UserId,
        offererItems = {},   -- array of { type="material"|"golem", id, qty }
        targetItems  = {},
        offererConfirmed = false,
        targetConfirmed  = false,
        createdAt   = Utils.UnixTimestamp(),
    }
    return tradeId
end

function TradingService.AddToOffer(player, tradeId, item)
    local trade = pendingTrades[tradeId]
    if not trade then return false, "Trade not found" end

    local isOfferer = player.UserId == trade.offererId
    local isTarget  = player.UserId == trade.targetId
    if not isOfferer and not isTarget then return false, "Not in this trade" end

    -- Reset confirmations when offer changes
    trade.offererConfirmed = false
    trade.targetConfirmed  = false

    local offerSide = isOfferer and trade.offererItems or trade.targetItems
    if #offerSide >= GameConfig.MAX_TRADE_ITEMS_PER_SIDE then
        return false, "Trade offer full"
    end

    -- Validate item ownership
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    if item.type == "blueprint" then
        return false, "Blueprints cannot be traded"
    elseif item.type == "material" then
        local have = data.Inventory[item.id] or 0
        if have < (item.qty or 1) then return false, "Insufficient material" end
    elseif item.type == "golem" then
        local found = false
        for _, g in ipairs(data.Golems) do
            if g.id == item.id and not g.deployed then found = true; break end
        end
        if not found then return false, "Golem not found or deployed" end
    else
        return false, "Unknown item type"
    end

    table.insert(offerSide, item)
    return true
end

function TradingService.ConfirmTrade(player, tradeId)
    local trade = pendingTrades[tradeId]
    if not trade then return false, "Trade not found" end

    if player.UserId == trade.offererId then
        trade.offererConfirmed = true
    elseif player.UserId == trade.targetId then
        trade.targetConfirmed = true
    else
        return false, "Not in trade"
    end

    if trade.offererConfirmed and trade.targetConfirmed then
        return TradingService._ExecuteTrade(tradeId)
    end

    return true, "Waiting for both parties"
end

function TradingService._ExecuteTrade(tradeId)
    local trade = pendingTrades[tradeId]
    if not trade then return false, "Trade not found" end

    local Players = game:GetService("Players")
    local offerer = Players:GetPlayerByUserId(trade.offererId)
    local target  = Players:GetPlayerByUserId(trade.targetId)

    if not offerer or not target then
        pendingTrades[tradeId] = nil
        return false, "A player left"
    end

    -- Atomic validation: both sides must still have their offered items
    local offData = PlayerDataService.Get(offerer)
    local tarData = PlayerDataService.Get(target)

    local function validateOffer(data, items)
        for _, item in ipairs(items) do
            if item.type == "material" then
                if (data.Inventory[item.id] or 0) < item.qty then
                    return false, item.id
                end
            elseif item.type == "golem" then
                local found = false
                for _, g in ipairs(data.Golems) do
                    if g.id == item.id and not g.deployed then found = true; break end
                end
                if not found then return false, item.id end
            end
        end
        return true
    end

    local offOk, offMissing = validateOffer(offData, trade.offererItems)
    local tarOk, tarMissing = validateOffer(tarData, trade.targetItems)

    if not offOk then
        pendingTrades[tradeId] = nil
        return false, "Offerer no longer has: " .. tostring(offMissing)
    end
    if not tarOk then
        pendingTrades[tradeId] = nil
        return false, "Target no longer has: " .. tostring(tarMissing)
    end

    -- Execute swap
    local function transferItems(fromPlayer, fromData, toPlayer, toData, items)
        for _, item in ipairs(items) do
            if item.type == "material" then
                fromData.Inventory[item.id] = (fromData.Inventory[item.id] or 0) - item.qty
                toData.Inventory[item.id]   = (toData.Inventory[item.id] or 0) + item.qty
            elseif item.type == "golem" then
                for i = #fromData.Golems, 1, -1 do
                    if fromData.Golems[i].id == item.id then
                        local golem = table.remove(fromData.Golems, i)
                        table.insert(toData.Golems, golem)
                        break
                    end
                end
            end
        end
        PlayerDataService.MarkDirty(fromPlayer)
        PlayerDataService.MarkDirty(toPlayer)
    end

    transferItems(offerer, offData, target, tarData, trade.offererItems)
    transferItems(target, tarData, offerer, offData, trade.targetItems)

    pendingTrades[tradeId] = nil
    return true, trade
end

function TradingService.CancelTrade(player, tradeId)
    local trade = pendingTrades[tradeId]
    if not trade then return false end
    if player.UserId ~= trade.offererId and player.UserId ~= trade.targetId then
        return false
    end
    pendingTrades[tradeId] = nil
    return true
end

-- ── Forge Market ──────────────────────────────────────────────────────────────
function TradingService.ListOnMarket(player, item, priceCoins)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end

    if priceCoins <= 0 then return nil, "Price must be positive" end

    if item.type == "blueprint" then
        return nil, "Blueprints cannot be listed on the market"
    end

    -- Validate and consume item
    if item.type == "material" then
        if not PlayerDataService.RemoveMaterial(player, item.id, item.qty) then
            return nil, "Insufficient material"
        end
    elseif item.type == "golem" then
        local found = false
        for i, g in ipairs(data.Golems) do
            if g.id == item.id and not g.deployed then
                table.remove(data.Golems, i)
                found = true; break
            end
        end
        if not found then return nil, "Golem not found" end
    else
        return nil, "Not tradeable"
    end

    local listing = {
        id         = Utils.GenerateId(),
        sellerId   = player.UserId,
        sellerName = player.Name,
        item       = Utils.DeepCopy(item),
        priceCoins = priceCoins,
        listedAt   = Utils.UnixTimestamp(),
    }
    marketListings[listing.id] = listing
    PersistMarket()
    return listing, nil
end

function TradingService.BuyFromMarket(player, listingId)
    local listing = marketListings[listingId]
    if not listing then return false, "Listing not found" end
    if listing.sellerId == player.UserId then return false, "Cannot buy own listing" end

    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local coins = data.EmberCoins or 0
    if coins < listing.priceCoins then return false, "Insufficient Ember Coins" end

    -- Deduct coins from buyer
    data.EmberCoins = coins - listing.priceCoins

    -- Award item to buyer
    if listing.item.type == "material" then
        PlayerDataService.AddMaterial(player, listing.item.id, listing.item.qty)
    elseif listing.item.type == "golem" then
        table.insert(data.Golems, listing.item)
    end

    -- Pay seller (minus listing fee); works whether they are online or offline
    local netAmount = math.floor(listing.priceCoins * (1 - GameConfig.MARKET_LISTING_FEE_PERCENT))
    PlayerDataService.CreditOfflineCoins(listing.sellerId, netAmount)

    marketListings[listingId] = nil
    PersistMarket()
    PlayerDataService.MarkDirty(player)

    return true, listing
end

function TradingService.GetMarketListings(filterType, filterElement, maxResults)
    local results = {}
    for _, listing in pairs(marketListings) do
        local include = true
        if filterType and listing.item.type ~= filterType then include = false end
        if filterElement and listing.item.element ~= filterElement then include = false end
        if include then
            table.insert(results, listing)
            if maxResults and #results >= maxResults then break end
        end
    end
    table.sort(results, function(a, b) return a.listedAt > b.listedAt end)
    return results
end

function TradingService.CancelListing(player, listingId)
    local listing = marketListings[listingId]
    if not listing then return false, "Not found" end
    if listing.sellerId ~= player.UserId then return false, "Not your listing" end

    -- Return item to player
    local data = PlayerDataService.Get(player)
    if data then
        if listing.item.type == "material" then
            PlayerDataService.AddMaterial(player, listing.item.id, listing.item.qty)
        elseif listing.item.type == "golem" then
            table.insert(data.Golems, listing.item)
        end
        PlayerDataService.MarkDirty(player)
    end

    marketListings[listingId] = nil
    PersistMarket()
    return true
end

-- Cleanup trades when player leaves
function TradingService.OnPlayerLeave(player)
    for tradeId, trade in pairs(pendingTrades) do
        if trade.offererId == player.UserId or trade.targetId == player.UserId then
            pendingTrades[tradeId] = nil
        end
    end
end

return TradingService
