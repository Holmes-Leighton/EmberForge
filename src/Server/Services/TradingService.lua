-- Player-to-player trading and the Forge Market (player-run marketplace).
-- Every number and id a client sends is treated as hostile: quantities must be positive
-- integers, prices are bounded, and Golems are always moved as the real server-side object.

local Players           = game:GetService("Players")
local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local MaterialData      = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SafeDataStore     = require(script.Parent.SafeDataStore)
local GolemNames        = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
local PetData           = require(game.ReplicatedStorage.Shared.Data.PetData)

local TradingService = {}

-- ── Limits ────────────────────────────────────────────────────────────────────
local MAX_ITEM_QTY          = 1000000
local MAX_PRICE             = 1000000000
local MAX_LISTINGS_PER_USER = 20
local TRADE_REQUEST_TTL     = 300      -- seconds a trade window may stay open
local MAX_HISTORY           = 20

-- Active direct trades: tradeId → session
local pendingTrades = {}
local tradeOfUser   = {}   -- userId → tradeId (a player can only be in one trade at a time)

-- Market listings: shared through a DataStore so every server sees the same market.
-- Writes go through UpdateAsync (atomic) so two servers can never sell the same listing.
local marketListings = {}  -- listingId → listing (local cache)
local marketStore    = SafeDataStore.GetDataStore("EmberForge_Market_v1")
local MARKET_KEY     = "listings_v2"

local function RefreshMarketCache()
    local ok, saved = pcall(function() return marketStore:GetAsync(MARKET_KEY) end)
    if ok and type(saved) == "table" then
        marketListings = saved
    end
end

task.spawn(function()
    RefreshMarketCache()
    while true do
        task.wait(20)
        RefreshMarketCache()
    end
end)

-- Atomically edit the shared listing table. `edit(listings)` may mutate it and return a result.
local function EditMarket(edit)
    local result
    local ok, err = pcall(function()
        marketStore:UpdateAsync(MARKET_KEY, function(old)
            local listings = type(old) == "table" and old or {}
            result = edit(listings)
            return listings
        end)
    end)
    if not ok then
        warn("[TradingService] Market write failed: " .. tostring(err))
        return nil, "Market unavailable, try again"
    end
    return result
end

-- ── Item validation ───────────────────────────────────────────────────────────
local function PositiveInt(n, max)
    return type(n) == "number" and n == n and n >= 1 and n <= max and math.floor(n) == n
end

-- Ownership totals already committed by `items`, so the same stack can't be offered twice
local function CommittedTotals(items)
    local mats, golems, pets = {}, {}, {}
    for _, it in ipairs(items) do
        if it.type == "material" then
            mats[it.id] = (mats[it.id] or 0) + it.qty
        elseif it.type == "golem" then
            golems[it.id] = true
        elseif it.type == "pet" then
            pets[it.id] = true
        end
    end
    return mats, golems, pets
end

-- Returns a clean item table built from *our* data (never the client's), or nil + reason.
-- `alreadyOffered` is the list of items already in this offer.
local function ValidateItem(data, raw, alreadyOffered)
    if type(raw) ~= "table" then return nil, "Bad item" end
    local kind, id = raw.type, raw.id
    if kind == "blueprint" then return nil, "Blueprints cannot be traded" end
    if type(id) ~= "string" then return nil, "Bad item" end

    local mats, golems, pets = CommittedTotals(alreadyOffered or {})

    if kind == "material" then
        if not PositiveInt(raw.qty, MAX_ITEM_QTY) then return nil, "Invalid quantity" end
        local def = MaterialData.Get(id)
        if not def then return nil, "Unknown material" end
        if def.tradeable == false then return nil, def.displayName .. " cannot be traded" end
        local have = (data.Inventory[id] or 0) - (mats[id] or 0)
        if have < raw.qty then return nil, "Not enough " .. def.displayName end
        return { type = "material", id = id, qty = raw.qty, element = def.element, name = def.displayName }

    elseif kind == "golem" then
        if golems[id] then return nil, "Golem already offered" end
        for _, g in ipairs(data.Golems) do
            if g.id == id then
                if g.deployed then return nil, "Recall that Golem before trading it" end
                local d = GolemNames.Describe(g)
                return { type = "golem", id = id, qty = 1, element = g.element, tier = g.tier,
                         rarity = d.rarity, variant = g.variant,
                         name = string.format("%s (%s)", d.name, d.rarity) }
            end
        end
        return nil, "Golem not found"

    elseif kind == "pet" then
        if pets[id] then return nil, "Pet already offered" end
        for _, pet in ipairs(data.OwnedPets or {}) do
            if pet.id == id then
                if table.find(data.EquippedPets or {}, id) then return nil, "Put that pet away before trading it" end
                local def = PetData.Get(pet.type)
                if not def then return nil, "Unknown pet" end
                return { type = "pet", id = id, qty = 1, petType = pet.type, variant = pet.variant, grown = pet.grown,
                         rarity = def.rarity, name = PetData.DisplayName(pet) .. " (" .. PetData.StageOf(pet).id .. ")" }
            end
        end
        return nil, "Pet not found"
    end
    return nil, "Unknown item type"
end

local function DescribeItems(items)
    local out = {}
    for _, it in ipairs(items) do
        table.insert(out, it.type == "material" and string.format("%s x%d", it.name or it.id, it.qty) or (it.name or it.id))
    end
    return out
end

-- ── Direct Trading ────────────────────────────────────────────────────────────
function TradingService.InitiateTrade(offererPlayer, targetPlayer)
    if not offererPlayer or not targetPlayer then return nil, "Player not found" end
    if offererPlayer == targetPlayer then return nil, "You can't trade with yourself" end
    if tradeOfUser[offererPlayer.UserId] then return nil, "You are already in a trade" end
    if tradeOfUser[targetPlayer.UserId] then return nil, targetPlayer.DisplayName .. " is already in a trade" end
    if not PlayerDataService.Get(targetPlayer) then return nil, "That player isn't ready" end

    local tradeId = Utils.GenerateId()
    pendingTrades[tradeId] = {
        tradeId          = tradeId,
        offererId        = offererPlayer.UserId,
        targetId         = targetPlayer.UserId,
        offererItems     = {},   -- array of clean items
        targetItems      = {},
        offererConfirmed = false,
        targetConfirmed  = false,
        createdAt        = Utils.UnixTimestamp(),
    }
    tradeOfUser[offererPlayer.UserId] = tradeId
    tradeOfUser[targetPlayer.UserId]  = tradeId
    return tradeId
end

-- True while this player is in an open trade (so a trade request to them, or from them, makes no sense)
function TradingService.InTrade(userId)
    return tradeOfUser[userId] ~= nil
end

local function CloseTrade(tradeId)
    local trade = pendingTrades[tradeId]
    if not trade then return end
    if tradeOfUser[trade.offererId] == tradeId then tradeOfUser[trade.offererId] = nil end
    if tradeOfUser[trade.targetId]  == tradeId then tradeOfUser[trade.targetId]  = nil end
    pendingTrades[tradeId] = nil
end

local function GetTradeFor(player, tradeId)
    local trade = type(tradeId) == "string" and pendingTrades[tradeId]
    if not trade then return nil, "Trade not found" end
    if Utils.UnixTimestamp() - trade.createdAt > TRADE_REQUEST_TTL then
        CloseTrade(tradeId)
        return nil, "Trade expired"
    end
    if player.UserId ~= trade.offererId and player.UserId ~= trade.targetId then
        return nil, "Not in this trade"
    end
    return trade
end

function TradingService.AddToOffer(player, tradeId, rawItem)
    local trade, err = GetTradeFor(player, tradeId)
    if not trade then return false, err end
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local isOfferer = player.UserId == trade.offererId
    local side = isOfferer and trade.offererItems or trade.targetItems
    if #side >= GameConfig.MAX_TRADE_ITEMS_PER_SIDE then return false, "Trade offer full" end

    local item, why = ValidateItem(data, rawItem, side)
    if not item then return false, why end

    table.insert(side, item)
    trade.offererConfirmed, trade.targetConfirmed = false, false   -- any change resets confirmations
    return true
end

function TradingService.RemoveFromOffer(player, tradeId, index)
    local trade, err = GetTradeFor(player, tradeId)
    if not trade then return false, err end
    local side = player.UserId == trade.offererId and trade.offererItems or trade.targetItems
    if not PositiveInt(index, #side) then return false, "Bad item" end
    table.remove(side, index)
    trade.offererConfirmed, trade.targetConfirmed = false, false
    return true
end

-- Sets this player's confirmation. Executes the trade when both have confirmed.
-- Returns ok, result   (result is the trade table when it has just executed)
function TradingService.ConfirmTrade(player, tradeId)
    local trade, err = GetTradeFor(player, tradeId)
    if not trade then return false, err end

    if player.UserId == trade.offererId then
        trade.offererConfirmed = true
    else
        trade.targetConfirmed = true
    end

    if trade.offererConfirmed and trade.targetConfirmed then
        return TradingService._ExecuteTrade(tradeId)
    end
    return true, "waiting"
end

-- What a player should see: their side, the other side, and who has confirmed.
function TradingService.GetTradeView(player, tradeId)
    local trade = GetTradeFor(player, tradeId)
    if not trade then return nil end
    local isOfferer = player.UserId == trade.offererId
    local partner = Players:GetPlayerByUserId(isOfferer and trade.targetId or trade.offererId)
    return {
        tradeId      = tradeId,
        partnerName  = partner and partner.DisplayName or "Player",
        partnerId    = isOfferer and trade.targetId or trade.offererId,
        yourItems    = isOfferer and trade.offererItems or trade.targetItems,
        theirItems   = isOfferer and trade.targetItems or trade.offererItems,
        youConfirmed = isOfferer and trade.offererConfirmed or trade.targetConfirmed,
        theyConfirmed = isOfferer and trade.targetConfirmed or trade.offererConfirmed,
    }
end

function TradingService.GetPartners(tradeId)
    local trade = pendingTrades[tradeId]
    if not trade then return nil end
    return Players:GetPlayerByUserId(trade.offererId), Players:GetPlayerByUserId(trade.targetId)
end

function TradingService._ExecuteTrade(tradeId)
    local trade = pendingTrades[tradeId]
    if not trade then return false, "Trade not found" end

    local offerer = Players:GetPlayerByUserId(trade.offererId)
    local target  = Players:GetPlayerByUserId(trade.targetId)
    if not offerer or not target then
        CloseTrade(tradeId)
        return false, "A player left"
    end

    local offData = PlayerDataService.Get(offerer)
    local tarData = PlayerDataService.Get(target)
    if not offData or not tarData then
        CloseTrade(tradeId)
        return false, "Player data unavailable"
    end

    -- Atomic validation: rebuild every item from current data; anything that changed cancels the trade
    local function revalidate(data, items)
        local checked = {}
        for _, it in ipairs(items) do
            local clean, why = ValidateItem(data, { type = it.type, id = it.id, qty = it.qty }, checked)
            if not clean then return false, why end
            table.insert(checked, clean)
        end
        return true
    end
    local offOk, offWhy = revalidate(offData, trade.offererItems)
    local tarOk, tarWhy = revalidate(tarData, trade.targetItems)
    if not offOk or not tarOk then
        CloseTrade(tradeId)
        return false, "Trade cancelled: " .. tostring(offWhy or tarWhy)
    end

    -- a full pet box cancels the trade rather than losing a pet
    local function incomingPets(items) local n = 0 for _, it in ipairs(items) do if it.type == "pet" then n += 1 end end return n end
    local offIn, tarIn = incomingPets(trade.targetItems), incomingPets(trade.offererItems)
    local offHeld, tarHeld = #(offData.OwnedPets or {}), #(tarData.OwnedPets or {})
    if offHeld - tarIn + offIn > PetData.MAX_OWNED or tarHeld - offIn + tarIn > PetData.MAX_OWNED then
        CloseTrade(tradeId)
        return false, "Trade cancelled: a pet box would be full"
    end

    local function transfer(fromData, toData, items)
        for _, it in ipairs(items) do
            if it.type == "material" then
                fromData.Inventory[it.id] = (fromData.Inventory[it.id] or 0) - it.qty
                if fromData.Inventory[it.id] <= 0 then fromData.Inventory[it.id] = nil end
                toData.Inventory[it.id] = (toData.Inventory[it.id] or 0) + it.qty
            elseif it.type == "golem" then
                for i = #fromData.Golems, 1, -1 do
                    if fromData.Golems[i].id == it.id then
                        table.insert(toData.Golems, table.remove(fromData.Golems, i))
                        break
                    end
                end
            elseif it.type == "pet" then
                for i = #fromData.OwnedPets, 1, -1 do
                    if fromData.OwnedPets[i].id == it.id then
                        toData.OwnedPets = toData.OwnedPets or {}
                        local moved = table.remove(fromData.OwnedPets, i)
                        table.insert(toData.OwnedPets, moved)
                        PetData.NoteSeen(toData, moved)
                        break
                    end
                end
            end
        end
    end
    transfer(offData, tarData, trade.offererItems)
    transfer(tarData, offData, trade.targetItems)

    -- History for both players
    local now = Utils.UnixTimestamp()
    local function record(data, partner, gave, got)
        data.TradeHistory = data.TradeHistory or {}
        table.insert(data.TradeHistory, 1, {
            time = now, partner = partner.DisplayName,
            gave = DescribeItems(gave), got = DescribeItems(got),
        })
        while #data.TradeHistory > MAX_HISTORY do table.remove(data.TradeHistory) end
    end
    record(offData, target, trade.offererItems, trade.targetItems)
    record(tarData, offerer, trade.targetItems, trade.offererItems)

    PlayerDataService.MarkDirty(offerer)
    PlayerDataService.MarkDirty(target)
    PlayerDataService.Save(offerer, true)   -- items moved: persist both sides right away
    PlayerDataService.Save(target, true)

    local result = {
        tradeId = tradeId, offererId = trade.offererId, targetId = trade.targetId,
        offererItems = trade.offererItems, targetItems = trade.targetItems,
    }
    CloseTrade(tradeId)
    return true, result
end

function TradingService.CancelTrade(player, tradeId)
    local trade = type(tradeId) == "string" and pendingTrades[tradeId]
    if not trade then return false end
    if player.UserId ~= trade.offererId and player.UserId ~= trade.targetId then return false end
    CloseTrade(tradeId)
    return true, trade
end

-- ── Forge Market ──────────────────────────────────────────────────────────────
local function CountListings(userId)
    local n = 0
    for _, l in pairs(marketListings) do
        if l.sellerId == userId then n = n + 1 end
    end
    return n
end

function TradingService.ListOnMarket(player, rawItem, priceCoins)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end

    if not PositiveInt(priceCoins, MAX_PRICE) then return nil, "Price must be a whole number of coins" end
    if CountListings(player.UserId) >= MAX_LISTINGS_PER_USER then
        return nil, "You can have at most " .. MAX_LISTINGS_PER_USER .. " listings"
    end

    local item, why = ValidateItem(data, rawItem, {})
    if not item then return nil, why end

    -- Take the item out of the seller's hands (the real object, not the client's copy)
    local golemObject, petObject
    if item.type == "material" then
        if not PlayerDataService.RemoveMaterial(player, item.id, item.qty) then
            return nil, "Not enough material"
        end
    elseif item.type == "pet" then
        for i, pet in ipairs(data.OwnedPets) do
            if pet.id == item.id then
                petObject = table.remove(data.OwnedPets, i)
                break
            end
        end
        if not petObject then return nil, "Pet not found" end
    else
        for i, g in ipairs(data.Golems) do
            if g.id == item.id then
                golemObject = table.remove(data.Golems, i)
                break
            end
        end
        if not golemObject then return nil, "Golem not found" end
    end
    PlayerDataService.MarkDirty(player)

    local listing = {
        id         = Utils.GenerateId(),
        sellerId   = player.UserId,
        sellerName = player.DisplayName,
        item       = item,
        golem      = golemObject,            -- only set for Golem listings
        pet        = petObject,              -- only set for pet listings
        priceCoins = priceCoins,
        listedAt   = Utils.UnixTimestamp(),
    }

    local _, err = EditMarket(function(listings) listings[listing.id] = listing return true end)
    if err then
        -- couldn't publish: give everything back
        if golemObject then table.insert(data.Golems, golemObject)
        elseif petObject then table.insert(data.OwnedPets, petObject)
        else PlayerDataService.AddMaterial(player, item.id, item.qty) end
        return nil, err
    end
    marketListings[listing.id] = listing
    PlayerDataService.Save(player, true)
    return listing, nil
end

-- Hand a claimed listing's item to a player
local function DeliverListing(player, listing)
    if listing.item.type == "material" then
        PlayerDataService.AddMaterial(player, listing.item.id, listing.item.qty)
    elseif listing.golem then
        local data = PlayerDataService.Get(player)
        table.insert(data.Golems, listing.golem)
        PlayerDataService.MarkDirty(player)
    elseif listing.pet then
        local data = PlayerDataService.Get(player)
        data.OwnedPets = data.OwnedPets or {}
        table.insert(data.OwnedPets, listing.pet)
        PetData.NoteSeen(data, listing.pet)
        PlayerDataService.MarkDirty(player)
    end
end

function TradingService.BuyFromMarket(player, listingId)
    if type(listingId) ~= "string" then return false, "Bad listing" end
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local cached = marketListings[listingId]
    if not cached then return false, "Listing not found" end
    if cached.sellerId == player.UserId then return false, "You can't buy your own listing" end
    if (data.EmberCoins or 0) < cached.priceCoins then return false, "Not enough Ember Coins" end
    if cached.pet and #(data.OwnedPets or {}) >= PetData.MAX_OWNED then return false, "Your pet box is full" end

    -- Claim it atomically; whoever removes it from the shared table first owns it
    local listing, err = EditMarket(function(listings)
        local l = listings[listingId]
        if l and l.sellerId ~= player.UserId then
            listings[listingId] = nil
            return l
        end
        return nil
    end)
    marketListings[listingId] = nil
    if not listing then return false, err or "Someone else just bought that" end

    if (data.EmberCoins or 0) < listing.priceCoins then
        -- spent the coins while we were waiting: put it back
        EditMarket(function(listings) listings[listing.id] = listing return true end)
        marketListings[listing.id] = listing
        return false, "Not enough Ember Coins"
    end

    data.EmberCoins = data.EmberCoins - listing.priceCoins
    DeliverListing(player, listing)

    local net = math.floor(listing.priceCoins * (1 - GameConfig.MARKET_LISTING_FEE_PERCENT))
    PlayerDataService.CreditOfflineCoins(listing.sellerId, net)
    local seller = Players:GetPlayerByUserId(listing.sellerId)
    if seller then
        local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
        RemoteEvents.Notify:FireClient(seller, "Item sold!",
            string.format("%s sold for %d coins", listing.item.name or listing.item.id, net))
    end

    PlayerDataService.MarkDirty(player)
    PlayerDataService.Save(player, true)
    return true, listing
end

function TradingService.GetMarketListings(filterType, filterElement, maxResults)
    local results = {}
    for _, listing in pairs(marketListings) do
        local include = true
        if filterType and listing.item.type ~= filterType then include = false end
        if filterElement and listing.item.element ~= filterElement then include = false end
        if include then table.insert(results, listing) end
    end
    table.sort(results, function(a, b) return a.listedAt > b.listedAt end)
    if maxResults and #results > maxResults then
        for i = #results, maxResults + 1, -1 do results[i] = nil end
    end
    return results
end

function TradingService.GetMyListings(player)
    local mine = {}
    for _, listing in pairs(marketListings) do
        if listing.sellerId == player.UserId then table.insert(mine, listing) end
    end
    table.sort(mine, function(a, b) return a.listedAt > b.listedAt end)
    return mine
end

function TradingService.CancelListing(player, listingId)
    if type(listingId) ~= "string" then return false, "Bad listing" end
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local listing, err = EditMarket(function(listings)
        local l = listings[listingId]
        if l and l.sellerId == player.UserId then
            listings[listingId] = nil
            return l
        end
        return nil
    end)
    marketListings[listingId] = nil
    if not listing then return false, err or "Listing not found" end

    DeliverListing(player, listing)
    PlayerDataService.MarkDirty(player)
    PlayerDataService.Save(player, true)
    return true
end

-- Cleanup trades when a player leaves
-- Returns the userId of the trading partner (so the caller can tell them), if any.
function TradingService.OnPlayerLeave(player)
    local tradeId = tradeOfUser[player.UserId]
    local trade = tradeId and pendingTrades[tradeId]
    if not trade then return nil end
    local partnerId = trade.offererId == player.UserId and trade.targetId or trade.offererId
    CloseTrade(tradeId)
    return partnerId
end

-- Trades left open past their time-to-live are swept periodically
task.spawn(function()
    while true do
        task.wait(60)
        local now = Utils.UnixTimestamp()
        for tradeId, trade in pairs(pendingTrades) do
            if now - trade.createdAt > TRADE_REQUEST_TTL then CloseTrade(tradeId) end
        end
    end
end)

return TradingService
