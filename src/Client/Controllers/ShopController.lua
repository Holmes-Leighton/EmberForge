-- Manages the Shop / Season Pass UI and Robux purchase flows.

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents   = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local SeasonData     = require(game.ReplicatedStorage.Shared.Data.SeasonData)
local ProductData    = require(game.ReplicatedStorage.Shared.Data.ProductData)
local Theme          = require(game.ReplicatedStorage.Shared.Modules.Theme)
local Utils          = require(game.ReplicatedStorage.Shared.Modules.Utils)

local ShopController = {}

local shopGui
local seasonGui

-- ── Init ──────────────────────────────────────────────────────────────────────
function ShopController.Init(playerData)
    ShopController._data = playerData

    task.spawn(function()
        shopGui   = PlayerGui:WaitForChild("ShopMenu",   10)
        seasonGui = PlayerGui:WaitForChild("SeasonMenu", 10)

        if shopGui   then ShopController._SetupShopGui()   end
        if seasonGui then ShopController._SetupSeasonGui() end
    end)
end

-- ── Convenience Shop ──────────────────────────────────────────────────────────
function ShopController._SetupShopGui()
    local function wireBtn(btnName, productKey)
        local btn = shopGui:FindFirstChild(btnName, true)
        if not btn or not btn:IsA("TextButton") then return end
        btn.MouseButton1Click:Connect(function()
            ShopController._Prompt(productKey)
        end)
    end

    wireBtn("SpeedUpx1Btn",          "SpeedUp_x1")
    wireBtn("SpeedUpx10Btn",         "SpeedUp_x10")
    wireBtn("SlotBoostBtn",          "SlotBoost_7d")
    wireBtn("MaterialMagnetBtn",     "MaterialMagnet")
    wireBtn("EventCatalystBtn",      "EventCatalyst")
    wireBtn("StandardPassBtn",       "SeasonPass_Standard")
    wireBtn("PremiumPassBtn",        "SeasonPass_Premium")

    -- Permanent unlocks are Game Passes
    local storageBtn = shopGui:FindFirstChild("StorageExpansionBtn", true)
    if storageBtn then storageBtn:SetAttribute("PassKey", "Storage24h") end
    for _, name in ipairs({ "StorageExpansionBtn", "PadCopperBtn", "PadIronBtn", "PadGoldBtn" }) do
        local btn = shopGui:FindFirstChild(name, true)
        if btn and btn:IsA("TextButton") then
            btn.MouseButton1Click:Connect(function()
                ShopController._PromptPass(btn:GetAttribute("PassKey"))
            end)
        end
    end
    shopGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if shopGui.Enabled then task.spawn(ShopController.RefreshPads) end
    end)
    if MarketplaceService.PromptGamePassPurchaseFinished then
        MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, purchased)
            if purchased then task.delay(1.5, ShopController.RefreshPads) end   -- the server grants on the same event
        end)
    end

    local closeBtn = shopGui:FindFirstChild("CloseButton", true)
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            shopGui.Enabled = false
        end)
    end
end

-- Buy a game pass (permanent). Roblox shows its own confirmation and receipt.
function ShopController._PromptPass(key)
    local pass = key and ProductData.GamePasses[key]
    local HUD = require(script.Parent.HUDController)
    if not pass or not ProductData.PassIsAvailable(key) then
        HUD.ShowNotification("Not available yet", (pass and pass.displayName or tostring(key)) .. " isn't on sale yet.")
        return
    end
    if ProductData.PassOwned(pass, ShopController._data) then
        HUD.ShowNotification("You already own this", pass.displayName)
        return
    end
    local ok, err = pcall(function() MarketplaceService:PromptGamePassPurchase(LocalPlayer, pass.id) end)
    if not ok then warn("[ShopController] Pass prompt failed: " .. tostring(err)) end
end

-- Show what is already yours in the Shop (bought, or unlocked by level for pads)
function ShopController.RefreshPads()
    if not shopGui then return end
    local PadData = require(game.ReplicatedStorage.Shared.Data.PadData)
    local fresh = RemoteEvents.GetPlayerData:InvokeServer()
    if fresh then ShopController._data = fresh end
    local data = ShopController._data
    if not data then return end
    local function state(btn, owned, byLevel)
        if not btn then return end
        if owned then
            btn.Text, btn.Active, btn.BackgroundColor3 = "Owned", false, Theme.Colors.Success
        elseif byLevel then
            btn.Text, btn.Active, btn.BackgroundColor3 = "Unlocked by level", false, Theme.Colors.PanelAlt
        else
            btn.Text, btn.Active = (btn:GetAttribute("Price") or "") .. " - Unlock", true
        end
    end
    for _, def in ipairs(PadData.Pads) do
        local key, pass = ProductData.PassForPad(def.id)
        if key then
            state(shopGui:FindFirstChild("Pad" .. def.id .. "Btn", true), ProductData.PassOwned(pass, data),
                (data.PlayerLevel or 1) >= (def.minLevel or 1))
        end
    end
    local storage = shopGui:FindFirstChild("StorageExpansionBtn", true)
    if storage then
        if ProductData.PassOwned(ProductData.GamePasses.Storage24h, data) then
            state(storage, true)
        else
            storage.Text, storage.Active = "299 R$", true
        end
    end
end

-- Buy a Developer Product (consumables, timed boosts, season passes)
function ShopController._Prompt(productKey)
    local product = ProductData.Products[productKey]
    if not product or not ProductData.IsAvailable(productKey) then
        require(script.Parent.HUDController).ShowNotification("Not available yet",
            (product and product.displayName or productKey) .. " isn't on sale yet.")
        return
    end
    -- Don't let someone pay twice for a season pass they already hold
    local held = (ShopController._data and ShopController._data.SeasonPassTier) or 0
    local wanted = (productKey == "SeasonPass_Premium" and SeasonData.PassTier.Premium)
        or (productKey == "SeasonPass_Standard" and SeasonData.PassTier.Standard) or nil
    if wanted and held >= wanted then
        require(script.Parent.HUDController).ShowNotification("You already have this", product.displayName)
        return
    end
    local ok, err = pcall(function()
        MarketplaceService:PromptProductPurchase(LocalPlayer, product.id)
    end)
    if not ok then
        warn("[ShopController] Prompt failed: " .. tostring(err))
    end
end

-- ── Season Pass GUI ───────────────────────────────────────────────────────────
local CosmeticData = require(game.ReplicatedStorage.Shared.Data.CosmeticData)
local refreshQueued = false

function ShopController._SetupSeasonGui()
    local closeBtn = seasonGui:FindFirstChild("CloseButton", true)
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function() seasonGui.Enabled = false end)
    end
    local function wirePassBtn(btnName, productKey)
        local btn = seasonGui:FindFirstChild(btnName, true)
        if btn then
            btn.MouseButton1Click:Connect(function()
                if btn.Active then ShopController._Prompt(productKey) end
            end)
        end
    end
    wirePassBtn("BuyStandardBtn", "SeasonPass_Standard")
    wirePassBtn("BuyPremiumBtn",  "SeasonPass_Premium")

    seasonGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if seasonGui.Enabled then ShopController.RefreshSeason() end
    end)
    ShopController.RefreshSeason()
end

-- Server answered a claim / purchase: redraw from the truth
function ShopController.OnResult(ok, payload, err)
    if seasonGui and seasonGui.Enabled and not refreshQueued then
        refreshQueued = true
        task.delay(0.3, function()
            refreshQueued = false
            ShopController.RefreshSeason()
        end)
    end
end

function ShopController.RefreshSeason()
    if not seasonGui then return end
    local fresh = RemoteEvents.GetPlayerData:InvokeServer()
    if fresh then ShopController._data = fresh end
    local data = ShopController._data
    local season = SeasonData.GetCurrentSeason()
    if not data or not season then return end
    local status = data.SeasonStatus or { currentWeek = 1, totalWeeks = season.durationWeeks, claimedWeeks = {}, communityCurrent = 0, communityTarget = 0 }
    local passTier = data.SeasonPassTier or 0

    local header = seasonGui:FindFirstChild("SeasonHeader", true)
    if header then header.Text = season.displayName end
    local weekLabel = seasonGui:FindFirstChild("WeekLabel", true)
    if weekLabel then weekLabel.Text = string.format("Week %d of %d", status.currentWeek or 1, status.totalWeeks or season.durationWeeks) end

    -- Community milestone
    local communityLabel = seasonGui:FindFirstChild("CommunityLabel", true)
    local target, current = status.communityTarget or 0, status.communityCurrent or 0
    local reward = season.communityMilestone and season.communityMilestone.reward
    if communityLabel then
        communityLabel.Text = string.format("Community Progress: %s / %s crafts  -  Unlock: %s",
            Utils.FormatNumber(current), Utils.FormatNumber(target),
            reward and string.format("%gx drop rate for everyone for %d hrs", reward.multiplier or 1, reward.durationHours or 0) or "a community reward")
    end
    local fill = seasonGui:FindFirstChild("MilestoneBarFill", true)
    if fill then fill.Size = UDim2.new(target > 0 and math.clamp(current / target, 0, 1) or 0, 0, 1, 0) end

    -- Pass buttons
    for btnName, req in pairs({ BuyStandardBtn = SeasonData.PassTier.Standard, BuyPremiumBtn = SeasonData.PassTier.Premium }) do
        local btn = seasonGui:FindFirstChild(btnName, true)
        if btn and passTier >= req then
            btn.Text = "Owned"
            btn.BackgroundColor3 = Color3.fromRGB(60, 130, 60)
            btn.Active = false
            btn.AutoButtonColor = false
        end
    end

    ShopController._RenderSeasonTrack(season, passTier, status)
end

function ShopController._RenderSeasonTrack(season, passTier, status)
    local trackScroll = seasonGui:FindFirstChild("TrackScroll", true)
    if not trackScroll then return end
    for _, child in ipairs(trackScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for week = 1, season.durationWeeks do
        ShopController._CreateWeekCard(trackScroll, season, week, passTier, status)
    end
end

local TRACKS = {
    { key = "freeTrackRewards",     name = "free",     label = "Free",     tier = 0, color = Color3.fromRGB(170, 170, 170) },
    { key = "standardTrackRewards", name = "standard", label = "Standard", tier = 1, color = Color3.fromRGB(70, 160, 230) },
    { key = "premiumTrackRewards",  name = "premium",  label = "Premium",  tier = 2, color = Color3.fromRGB(240, 180, 40) },
}

function ShopController._CreateWeekCard(parent, season, week, passTier, status)
    local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
    local weekReached = week <= (status.currentWeek or 1)

    local card = Instance.new("Frame")
    card.Name = "Week" .. week
    card.LayoutOrder = week
    card.Size = UDim2.new(0, 132, 1, 0)
    card.BackgroundColor3 = weekReached and Theme.Colors.Panel or Color3.fromRGB(24, 20, 17)
    card.BorderSizePixel = 0
    card.Parent = parent
    Theme.AddCorner(card, Theme.Corner.Small)

    local weekLbl = Theme.Label(card, "Week " .. week .. (week == status.currentWeek and "  (now)" or ""),
        Theme.TextSize.Body, weekReached and Theme.Colors.Gold or Theme.Colors.TextDim, Theme.Fonts.Heading)
    weekLbl.Position = UDim2.new(0, 6, 0, 4)
    weekLbl.Size = UDim2.new(1, -12, 0, 22)
    weekLbl.TextXAlignment = Enum.TextXAlignment.Center

    local slotH = math.floor((card.AbsoluteSize.Y > 0 and card.AbsoluteSize.Y or 420) / 3) - 12
    slotH = math.max(slotH, 100)
    for i, track in ipairs(TRACKS) do
        local entry
        for _, e in ipairs(season[track.key] or {}) do
            if e.week == week then entry = e.reward break end
        end

        local slot = Instance.new("Frame")
        slot.Size = UDim2.new(1, -8, 0, 118)
        slot.Position = UDim2.new(0, 4, 0, 30 + (i - 1) * 124)
        slot.BackgroundColor3 = Theme.Colors.PanelAlt
        slot.BorderSizePixel = 0
        slot.Parent = card
        Theme.AddCorner(slot, Theme.Corner.Small)
        Theme.Stripe(slot, track.color)

        local owned = passTier >= track.tier
        local claimed = status.claimedWeeks and status.claimedWeeks[track.name .. "_" .. week] == true

        local trackLbl = Theme.Label(slot, track.label, Theme.TextSize.Small, track.color, Theme.Fonts.Heading)
        trackLbl.Position = UDim2.new(0, 10, 0, 2)
        trackLbl.Size = UDim2.new(1, -14, 0, 16)

        local rewardLbl = Theme.Label(slot, entry and CosmeticData.RewardText(entry) or "-", Theme.TextSize.Small,
            owned and Theme.Colors.TextPrimary or Theme.Colors.TextDim, Theme.Fonts.Body)
        rewardLbl.Position = UDim2.new(0, 10, 0, 20)
        rewardLbl.Size = UDim2.new(1, -14, 0, 56)
        rewardLbl.TextXAlignment = Enum.TextXAlignment.Left
        rewardLbl.TextYAlignment = Enum.TextYAlignment.Top

        if entry then
            local state, text, color
            if claimed then
                state, text, color = "claimed", "Claimed", Color3.fromRGB(60, 90, 60)
            elseif not owned then
                state, text, color = "locked", track.tier == 1 and "Needs Pass" or "Needs Premium", Color3.fromRGB(60, 50, 45)
            elseif not weekReached then
                state, text, color = "locked", "Not yet", Color3.fromRGB(60, 50, 45)
            else
                state, text, color = "claim", "Claim", Color3.fromRGB(50, 160, 80)
            end
            local btn = Theme.Button(slot, text, color, Color3.fromRGB(255, 255, 255))
            btn.Size = UDim2.new(1, -16, 0, 26)
            btn.Position = UDim2.new(0, 8, 1, -32)
            btn.TextSize = 11
            btn.AutoButtonColor = state == "claim"
            if state == "claim" then
                btn.MouseButton1Click:Connect(function()
                    btn.Text = "..."
                    btn.Active = false
                    RemoteEvents.ClaimSeasonReward:FireServer(season.id, week, track.name)
                end)
            end
        end
    end
    return card
end

return ShopController
