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

-- ── Storage expansion: permanent 24h offline cap ──────────────────────────────
PRODUCT_HANDLERS.StorageExpansion = function(player)
    return withData(player, function(d) d.StorageTier = 2 end)
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

-- ── Season Pass (perks are derived from SeasonPassTier; no slots are granted here) ─
PRODUCT_HANDLERS.SeasonPass_Standard = function(player)
    return withData(player, function(d)
        d.SeasonPassTier = math.max(d.SeasonPassTier or 0, SeasonData.PassTier.Standard)
    end)
end
PRODUCT_HANDLERS.SeasonPass_Premium = function(player)
    return withData(player, function(d) d.SeasonPassTier = SeasonData.PassTier.Premium end)
end

-- ── Cosmetics ─────────────────────────────────────────────────────────────────
for key, product in pairs(ProductData.Products) do
    if product.cosmeticId then
        PRODUCT_HANDLERS[key] = function(player)
            return withData(player, function(d)
                d.OwnedCosmetics = d.OwnedCosmetics or {}
                if not Utils.TableContains(d.OwnedCosmetics, product.cosmeticId) then
                    table.insert(d.OwnedCosmetics, product.cosmeticId)
                end
            end)
        end
    end
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
    return math.min(slots, GameConfig.MAX_GOLEM_SLOTS)
end

return ShopService
