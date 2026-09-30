-- Manages the Shop / Season Pass UI and Robux purchase flows.

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents   = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local SeasonData     = require(game.ReplicatedStorage.Shared.Data.SeasonData)
local ProductData    = require(game.ReplicatedStorage.Shared.Data.ProductData)
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
    wireBtn("StorageExpansionBtn",   "StorageExpansion")
    wireBtn("SlotBoostBtn",          "SlotBoost_7d")
    wireBtn("MaterialMagnetBtn",     "MaterialMagnet")
    wireBtn("EventCatalystBtn",      "EventCatalyst")
    wireBtn("StandardPassBtn",       "SeasonPass_Standard")
    wireBtn("PremiumPassBtn",        "SeasonPass_Premium")

    local closeBtn = shopGui:FindFirstChild("CloseButton", true)
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            shopGui.Enabled = false
        end)
    end
end

function ShopController._Prompt(productKey)
    local product = ProductData.Products[productKey]
    if not product or not ProductData.IsAvailable(productKey) then
        require(script.Parent.HUDController).ShowNotification("Not available yet",
            (product and product.displayName or productKey) .. " isn't on sale yet.")
        return
    end
    local productId = product.id
    local ok, err = pcall(function()
        MarketplaceService:PromptProductPurchase(LocalPlayer, productId)
    end)
    if not ok then
        warn("[ShopController] Prompt failed: " .. tostring(err))
    end
end

-- ── Season Pass GUI ───────────────────────────────────────────────────────────
function ShopController._SetupSeasonGui()
    local season = SeasonData.GetCurrentSeason()
    if not season then return end

    -- Set season name header
    local header = seasonGui:FindFirstChild("SeasonHeader", true)
    if header then header.Text = season.displayName end

    local data = ShopController._data
    local passTier = data.SeasonPassTier or 0

    -- Render week reward tracks
    ShopController._RenderSeasonTrack(season, passTier)

    -- Buy pass buttons
    local function wirePassBtn(btnName, productKey, requiredTier)
        local btn = seasonGui:FindFirstChild(btnName, true)
        if not btn then return end
        if passTier >= requiredTier then
            btn.Text = "Owned"
            btn.BackgroundColor3 = Color3.fromRGB(60, 130, 60)
            btn.Active = false
        else
            btn.MouseButton1Click:Connect(function()
                ShopController._Prompt(productKey)
            end)
        end
    end

    wirePassBtn("BuyStandardBtn", "SeasonPass_Standard", SeasonData.PassTier.Standard)
    wirePassBtn("BuyPremiumBtn",  "SeasonPass_Premium",  SeasonData.PassTier.Premium)

    -- Community milestone
    local communityLabel = seasonGui:FindFirstChild("CommunityLabel", true)
    if communityLabel then
        local current, target = 0, 0  -- fetched from server in full build
        communityLabel.Text = "Community Progress: " ..
            Utils.FormatNumber(current) .. " / " .. Utils.FormatNumber(target)
    end

    local closeBtn = seasonGui:FindFirstChild("CloseButton", true)
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            seasonGui.Enabled = false
        end)
    end
end

function ShopController._RenderSeasonTrack(season, passTier)
    if not seasonGui then return end
    local trackScroll = seasonGui:FindFirstChild("TrackScroll", true)
    if not trackScroll then return end

    for _, child in ipairs(trackScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local maxWeeks = season.durationWeeks
    local xOff = 0

    for week = 1, maxWeeks do
        local weekCard = ShopController._CreateWeekCard(season, week, passTier, xOff)
        weekCard.Parent = trackScroll
        xOff = xOff + 130
    end
    trackScroll.CanvasSize = UDim2.new(0, xOff + 5, 0, 0)
end

function ShopController._CreateWeekCard(season, week, passTier, xOff)
    local card = Instance.new("Frame")
    card.Name = "Week" .. week
    card.Size = UDim2.new(0, 125, 1, -10)
    card.Position = UDim2.new(0, xOff + 2, 0, 5)
    card.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
    card.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    local weekLbl = Instance.new("TextLabel")
    weekLbl.Size = UDim2.new(1, 0, 0, 24)
    weekLbl.Position = UDim2.new(0, 0, 0, 0)
    weekLbl.BackgroundTransparency = 1
    weekLbl.Text = "Week " .. week
    weekLbl.TextColor3 = Color3.fromRGB(255, 200, 60)
    weekLbl.Font = Enum.Font.GothamBold
    weekLbl.TextSize = 13
    weekLbl.Parent = card

    -- Show free track reward
    local tracks = {
        { key = "freeTrackRewards", label = "Free",     tier = 0,                         color = Color3.fromRGB(140, 140, 140) },
        { key = "standardTrackRewards", label = "Std",  tier = SeasonData.PassTier.Standard, color = Color3.fromRGB(60, 180, 230) },
        { key = "premiumTrackRewards",  label = "Prem", tier = SeasonData.PassTier.Premium,  color = Color3.fromRGB(230, 180, 40) },
    }

    local yOff = 26
    for _, track in ipairs(tracks) do
        local rewardList = season[track.key] or {}
        local rewardEntry
        for _, entry in ipairs(rewardList) do
            if entry.week == week then rewardEntry = entry.reward; break end
        end

        local rewardLbl = Instance.new("TextLabel")
        rewardLbl.Size = UDim2.new(1, -4, 0, 28)
        rewardLbl.Position = UDim2.new(0, 2, 0, yOff)
        rewardLbl.BackgroundColor3 = Color3.fromRGB(25, 22, 18)
        rewardLbl.BackgroundTransparency = passTier >= track.tier and 0.5 or 0.2
        rewardLbl.BorderSizePixel = 0
        rewardLbl.Text = track.label .. ": " ..
            (rewardEntry and rewardEntry.type or "—")
        rewardLbl.TextColor3 = passTier >= track.tier and track.color or Color3.fromRGB(80, 80, 80)
        rewardLbl.Font = Enum.Font.Gotham
        rewardLbl.TextSize = 10
        rewardLbl.TextWrapped = true
        rewardLbl.Parent = card

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 3)
        rc.Parent = rewardLbl

        -- Claim button (if unlocked and unclaimed)
        if passTier >= track.tier and rewardEntry then
            local claimBtn = Instance.new("TextButton")
            claimBtn.Size = UDim2.new(0, 50, 0, 20)
            claimBtn.Position = UDim2.new(0.5, -25, 1, -22)
            claimBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
            claimBtn.Text = "Claim"
            claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            claimBtn.Font = Enum.Font.GothamBold
            claimBtn.TextSize = 10
            claimBtn.BorderSizePixel = 0
            claimBtn.Parent = card

            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 4)
            bc.Parent = claimBtn

            local trackName = track.key == "freeTrackRewards" and "free"
                or track.key == "standardTrackRewards" and "standard" or "premium"

            claimBtn.MouseButton1Click:Connect(function()
                RemoteEvents.ClaimSeasonReward:FireServer(season.id, week, trackName)
                claimBtn.Text = "Claimed"
                claimBtn.Active = false
                claimBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 60)
            end)
        end

        yOff = yOff + 32
    end

    return card
end

return ShopController
