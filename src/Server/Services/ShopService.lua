-- Handles all Robux purchases via MarketplaceService receipt validation.

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")

local GameConfig         = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local SeasonData         = require(game.ReplicatedStorage.Shared.Data.SeasonData)
local Utils              = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService  = require(script.Parent.PlayerDataService)

local ShopService = {}

-- Developer product IDs → handler functions
-- These must match the product IDs configured in the Roblox Creator Dashboard
local PRODUCT_HANDLERS = {}

-- ── Speed-ups ─────────────────────────────────────────────────────────────────
local function grantSpeedUp(player, qty)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    data.SpeedUps = (data.SpeedUps or 0) + qty
    PlayerDataService.MarkDirty(player)
    return true
end

PRODUCT_HANDLERS["EF_SpeedUp_x1"]  = function(player) return grantSpeedUp(player, 1)  end
PRODUCT_HANDLERS["EF_SpeedUp_x10"] = function(player) return grantSpeedUp(player, 10) end

-- ── Storage expansion ─────────────────────────────────────────────────────────
PRODUCT_HANDLERS["EF_StorageExpansion"] = function(player)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    data.StorageTier = math.min(2, (data.StorageTier or 0) + 1)
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Temporary golem slot boost (7 days) ──────────────────────────────────────
PRODUCT_HANDLERS["EF_SlotBoost_7d"] = function(player)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    data.TempSlotBoostExpiry = Utils.UnixTimestamp() + (7 * 86400)
    -- Effective slot count calculated in GolemService
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Material Magnet (24hr double resources) ───────────────────────────────────
PRODUCT_HANDLERS["EF_MaterialMagnet"] = function(player)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    data.MaterialMagnetExpiry = Utils.UnixTimestamp() + 86400
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Event Catalyst purchase ───────────────────────────────────────────────────
PRODUCT_HANDLERS["EF_EventCatalyst_S1"] = function(player)
    PlayerDataService.AddMaterial(player, "EventCatalyst", 1)
    return true
end

-- ── Season Pass ───────────────────────────────────────────────────────────────
PRODUCT_HANDLERS[SeasonData.ProductIds.StandardPass] = function(player)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    data.SeasonPassTier = math.max(data.SeasonPassTier or 0, SeasonData.PassTier.Standard)
    -- Grant storage slot perk
    data.GolemSlots = math.max(data.GolemSlots or 3, 12)
    PlayerDataService.MarkDirty(player)
    return true
end

PRODUCT_HANDLERS[SeasonData.ProductIds.PremiumPass] = function(player)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    data.SeasonPassTier = SeasonData.PassTier.Premium
    data.GolemSlots = math.max(data.GolemSlots or 3, 12)
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Cosmetic purchases ────────────────────────────────────────────────────────
-- Forge Skins
local FORGE_SKINS = {
    "EF_ForgeSkin_Basic", "EF_ForgeSkin_Ember", "EF_ForgeSkin_Frost",
    "EF_ForgeSkin_Storm", "EF_ForgeSkin_Void",
}
for _, skinId in ipairs(FORGE_SKINS) do
    PRODUCT_HANDLERS[skinId] = function(player)
        local data = PlayerDataService.Get(player)
        if not data then return false end
        data.OwnedCosmetics = data.OwnedCosmetics or {}
        if not Utils.TableContains(data.OwnedCosmetics, skinId) then
            table.insert(data.OwnedCosmetics, skinId)
        end
        PlayerDataService.MarkDirty(player)
        return true
    end
end

-- ── MarketplaceService receipt processing ─────────────────────────────────────
-- This is the authoritative purchase handler. All grants happen here.
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player left — retry later
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Check if already processed (idempotency)
    local data = PlayerDataService.Get(player)
    if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end

    local receiptKey = "receipt_" .. receiptInfo.PurchaseId
    data.ProcessedReceipts = data.ProcessedReceipts or {}
    if data.ProcessedReceipts[receiptKey] then
        return Enum.ProductPurchaseDecision.PurchaseGranted  -- already done
    end

    -- Find and call handler
    local productId = receiptInfo.ProductId
    local handler   = PRODUCT_HANDLERS[tostring(productId)]

    if handler then
        local success, err = pcall(handler, player)
        if success then
            data.ProcessedReceipts[receiptKey] = true
            PlayerDataService.MarkDirty(player)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        else
            warn("[ShopService] Handler error for product " .. tostring(productId) .. ": " .. tostring(err))
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    else
        warn("[ShopService] No handler for product: " .. tostring(productId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
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
    local base = data.GolemSlots or GameConfig.BASE_GOLEM_SLOTS
    local now  = Utils.UnixTimestamp()
    if (data.TempSlotBoostExpiry or 0) > now then
        base = math.min(base + 1, GameConfig.MAX_GOLEM_SLOTS)
    end
    return base
end

return ShopService
