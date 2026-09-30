-- Handles all Robux purchases via MarketplaceService receipt validation.

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")

local GameConfig         = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local SeasonData         = require(game.ReplicatedStorage.Shared.Data.SeasonData)
local ProductData        = require(game.ReplicatedStorage.Shared.Data.ProductData)
local Utils              = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService  = require(script.Parent.PlayerDataService)

local ShopService = {}

local function RemoteEvents_Notify(player, title, message)
    local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
    if RemoteEvents.Notify then RemoteEvents.Notify:FireClient(player, title, message) end
end

-- Product handlers are keyed by ProductData key; receipts are matched by numeric product id.
local PRODUCT_HANDLERS = {}

local function withData(player, fn)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    fn(data)
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Speed-ups ─────────────────────────────────────────────────────────────────
PRODUCT_HANDLERS.SpeedUp_x1  = function(player) return withData(player, function(d) d.SpeedUps = (d.SpeedUps or 0) + 1  end) end
PRODUCT_HANDLERS.SpeedUp_x10 = function(player) return withData(player, function(d) d.SpeedUps = (d.SpeedUps or 0) + 10 end) end

-- ── Slot packs: +5 permanent Golem slots per purchase, stackable ───────────────
-- (Repeatable, so a Developer Product. The cap is enforced where the purchase is offered; once
-- Robux has been paid the grant always goes through, so nobody is ever charged for nothing.)
PRODUCT_HANDLERS.SlotPack_5 = function(player)
    return withData(player, function(d)
        d.PurchasedSlots = (d.PurchasedSlots or 0) + GameConfig.SLOT_PACK_SIZE
    end)
end

-- ── Temporary Golem slot boost (7 days) ───────────────────────────────────────
PRODUCT_HANDLERS.SlotBoost_7d = function(player)
    return withData(player, function(d)
        local now = Utils.UnixTimestamp()
        -- stacking a second purchase extends the boost
        d.TempSlotBoostExpiry = math.max(d.TempSlotBoostExpiry or 0, now) + (7 * 86400)
    end)
end

-- ── Material Magnet (24h double resources) ────────────────────────────────────
PRODUCT_HANDLERS.MaterialMagnet = function(player)
    return withData(player, function(d)
        local now = Utils.UnixTimestamp()
        d.MaterialMagnetExpiry = math.max(d.MaterialMagnetExpiry or 0, now) + 86400
    end)
end

-- ── Event Catalyst ────────────────────────────────────────────────────────────
PRODUCT_HANDLERS.EventCatalyst = function(player)
    PlayerDataService.AddMaterial(player, "EventCatalyst", 1)
    return true
end

-- ── Pet eggs: hatch `count` pets from the egg and show each one (Robux has already been paid, so the
-- grant always goes through, even if the pet box is full) ──────────────────────────────────────────
for key, product in pairs(ProductData.Products) do
    if product.eggId then
        PRODUCT_HANDLERS[key] = function(player)
            local pets = require(script.Parent.PetService).HatchPaid(player, product.eggId, product.count)
            return #pets == product.count
        end
    end
end

-- ── Season Pass (perks are derived from SeasonPassTier; no slots are granted here) ─
PRODUCT_HANDLERS.SeasonPass_Standard = function(player)
    return withData(player, function(d)
        d.SeasonPassTier = math.max(d.SeasonPassTier or 0, SeasonData.PassTier.Standard)
    end)
end
PRODUCT_HANDLERS.SeasonPass_Premium = function(player)
    return withData(player, function(d) d.SeasonPassTier = SeasonData.PassTier.Premium end)
end

-- ── Game passes: permanent unlocks (pads, storage, forge skins) ───────────────
local function ApplyPass(data, pass)
    if pass.padId then
        data.UnlockedPads = data.UnlockedPads or {}
        data.UnlockedPads[pass.padId] = true
    elseif pass.storageTier then
        data.StorageTier = math.max(data.StorageTier or 0, pass.storageTier)
    elseif pass.cosmeticId then
        data.OwnedCosmetics = data.OwnedCosmetics or {}
        if not Utils.TableContains(data.OwnedCosmetics, pass.cosmeticId) then
            table.insert(data.OwnedCosmetics, pass.cosmeticId)
        end
    end
end

-- Give a pass's reward once. Returns true only if something new was granted.
function ShopService.GrantPass(player, key, announce)
    local pass = ProductData.GamePasses[key]
    local data = PlayerDataService.Get(player)
    if not pass or not data or ProductData.PassOwned(pass, data) then return false end
    ApplyPass(data, pass)
    PlayerDataService.MarkDirty(player)
    if announce then
        RemoteEvents_Notify(player, "Unlocked!", pass.displayName .. " is yours forever.")
        PlayerDataService.Save(player, true)
    end
    return true
end

-- Ask Roblox which passes the player owns (covers passes bought on the game page or on another
-- server) and unlock them. `onlyKey` limits the check to one pass. True if anything unlocked.
function ShopService.RefreshPasses(player, onlyKey)
    local any = false
    for key, pass in pairs(ProductData.GamePasses) do
        if pass.id ~= 0 and (not onlyKey or key == onlyKey) then
            local data = PlayerDataService.Get(player)
            if not data then return any end
            if not ProductData.PassOwned(pass, data) then
                local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id) end)
                if ok and owns and ShopService.GrantPass(player, key, false) then any = true end
            end
        end
    end
    return any
end

function ShopService.OnPlayerAdded(player)
    task.spawn(function() ShopService.RefreshPasses(player) end)
end

if MarketplaceService.PromptGamePassPurchaseFinished then
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
        if not wasPurchased then return end
        for key, pass in pairs(ProductData.GamePasses) do
            if pass.id ~= 0 and pass.id == passId then ShopService.GrantPass(player, key, true) end
        end
    end)
end

-- ── Contextual offers (the shop pops up when it's useful, like the big games do) ─
-- kind = "pass" | "product". At most one offer every 3 minutes per player, and the same offer
-- at most every 10 minutes. Never offers something that isn't on sale or is already owned.
local lastAnyOffer, lastKeyOffer = {}, {}
function ShopService.Offer(player, kind, key, reason)
    local item = (kind == "pass" and ProductData.GamePasses[key]) or (kind == "product" and ProductData.Products[key]) or nil
    if not item or item.id == 0 then return false end
    local data = PlayerDataService.Get(player)
    if not data then return false end
    if kind == "pass" and ProductData.PassOwned(item, data) then return false end
    if key == "SlotPack_5" and (data.PurchasedSlots or 0) >= GameConfig.MAX_PURCHASED_SLOTS then return false end
    local now, uid = os.clock(), player.UserId
    if now - (lastAnyOffer[uid] or -1e9) < 180 then return false end
    local k = uid .. ":" .. key
    if now - (lastKeyOffer[k] or -1e9) < 600 then return false end
    lastAnyOffer[uid], lastKeyOffer[k] = now, now
    local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
    if RemoteEvents.ShopOffer then RemoteEvents.ShopOffer:FireClient(player, kind, key, reason) end
    return true
end
if Players.PlayerRemoving then
    Players.PlayerRemoving:Connect(function(p)
        lastAnyOffer[p.UserId] = nil
        for k in pairs(lastKeyOffer) do
            if k:sub(1, #tostring(p.UserId) + 1) == p.UserId .. ":" then lastKeyOffer[k] = nil end
        end
    end)
end

-- ── MarketplaceService receipt processing ─────────────────────────────────────
-- Authoritative purchase handler: matches the receipt's numeric ProductId to a key,
-- grants exactly once (receipts are remembered), and only then confirms.
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet   -- retried when they rejoin
    end

    local data = PlayerDataService.Get(player)
    if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end

    local receiptKey = "receipt_" .. tostring(receiptInfo.PurchaseId)
    data.ProcessedReceipts = data.ProcessedReceipts or {}
    if data.ProcessedReceipts[receiptKey] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local key = ProductData.KeyForId(receiptInfo.ProductId)
    local handler = key and PRODUCT_HANDLERS[key]
    if not handler then
        warn("[ShopService] No handler for product id " .. tostring(receiptInfo.ProductId)
            .. " — set its id in ProductData.lua")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local success, result = pcall(handler, player)
    if success and result then
        data.ProcessedReceipts[receiptKey] = true
        PlayerDataService.MarkDirty(player)
        PlayerDataService.Save(player, true)   -- persist the grant + receipt immediately
        require(script.Parent.AnalyticsHelper).Custom(player, "Purchase", ProductData.Products[key].robux,
            { product = key })
        RemoteEvents_Notify(player, "Purchase complete", ProductData.Products[key].displayName)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    warn("[ShopService] Handler failed for " .. tostring(key) .. ": " .. tostring(result))
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ── Active boost queries ──────────────────────────────────────────────────────
function ShopService.HasMaterialMagnet(player)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    local expiry = data.MaterialMagnetExpiry or 0
    return Utils.UnixTimestamp() < expiry
end

function ShopService.GetEffectiveGolemSlots(player)
    local data = PlayerDataService.Get(player)
    if not data then return GameConfig.BASE_GOLEM_SLOTS end
    local slots = data.GolemSlots or GameConfig.BASE_GOLEM_SLOTS
    if (data.SeasonPassTier or 0) >= 1 then slots = slots + 3 end          -- pass holder bonus (spec 3.4)
    if (data.TempSlotBoostExpiry or 0) > Utils.UnixTimestamp() then slots = slots + 1 end
    slots = slots + (data.PurchasedSlots or 0)
    return math.min(slots, GameConfig.MAX_GOLEM_SLOTS)
end

return ShopService
