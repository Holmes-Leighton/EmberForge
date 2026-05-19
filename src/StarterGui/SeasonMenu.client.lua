-- Creates the Season Pass ScreenGui: weekly reward tracks and community milestone.
-- Named elements expected by ShopController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

local gui = Instance.new("ScreenGui")
gui.Name = "SeasonMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1,0,1,0)
scrim.BackgroundColor3 = Color3.fromRGB(0,0,0)
scrim.BackgroundTransparency = 0.45
scrim.BorderSizePixel = 0
scrim.Parent = gui
scrim.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then gui.Enabled = false end
end)

-- ── Container ─────────────────────────────────────────────────────────────────
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 860, 0, 560)
container.Position = UDim2.new(0.5, -430, 0.5, -280)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel = 0
container.Parent = gui
Theme.AddCorner(container, Theme.Corner.Large)

-- ── Title bar ─────────────────────────────────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 60)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tf = Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,12); tf.Position=UDim2.new(0,0,1,-12)
tf.BackgroundColor3=Theme.Colors.Panel; tf.BorderSizePixel=0; tf.Parent=titleBar

-- Flame gradient on title bar
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 30, 10)),
    ColorSequenceKeypoint.new(0.5, Theme.Colors.Panel),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 20, 60)),
})
grad.Rotation = 0
grad.Parent = titleBar

local seasonHeader = Theme.Label(titleBar, "🌟  Season 1 — The First Forge",
    Theme.TextSize.Title, Theme.Colors.Gold, Theme.Fonts.Title, "SeasonHeader")
seasonHeader.Size = UDim2.new(0.65, 0, 0, 34)
seasonHeader.Position = UDim2.new(0, 16, 0, 6)
seasonHeader.TextXAlignment = Enum.TextXAlignment.Left

local weekLabel = Theme.Label(titleBar, "Week 1 of 7", Theme.TextSize.Body,
    Theme.Colors.TextSecondary, Theme.Fonts.Body, "WeekLabel")
weekLabel.Size = UDim2.new(0.3, 0, 0, 20)
weekLabel.Position = UDim2.new(0, 16, 0, 36)

local closeBtn = Theme.Button(titleBar, "✕", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 12)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- ── Pass purchase buttons ─────────────────────────────────────────────────────
local passBtnRow = Instance.new("Frame")
passBtnRow.Name = "PassBtnRow"
passBtnRow.Size = UDim2.new(0, 350, 0, 44)
passBtnRow.Position = UDim2.new(1, -358, 0, 10)
passBtnRow.BackgroundTransparency = 1
passBtnRow.Parent = titleBar

local buyStandardBtn = Theme.Button(passBtnRow, "Standard — 699 R$",
    Theme.Colors.Info, Color3.fromRGB(255,255,255), "BuyStandardBtn")
buyStandardBtn.Size = UDim2.new(0, 166, 1, -8)
buyStandardBtn.Position = UDim2.new(0, 0, 0, 4)
buyStandardBtn.TextSize = 12

local buyPremiumBtn = Theme.Button(passBtnRow, "Premium — 1,299 R$",
    Theme.Colors.Legendary, Color3.fromRGB(255,255,255), "BuyPremiumBtn")
buyPremiumBtn.Size = UDim2.new(0, 176, 1, -8)
buyPremiumBtn.Position = UDim2.new(0, 174, 0, 4)
buyPremiumBtn.TextSize = 12

-- ── Community milestone bar ───────────────────────────────────────────────────
local milestonePanel = Instance.new("Frame")
milestonePanel.Name = "MilestonePanel"
milestonePanel.Size = UDim2.new(1, -16, 0, 52)
milestonePanel.Position = UDim2.new(0, 8, 0, 68)
milestonePanel.BackgroundColor3 = Theme.Colors.Panel
milestonePanel.BorderSizePixel = 0
milestonePanel.Parent = container
Theme.AddCorner(milestonePanel, Theme.Corner.Medium)

local communityLabel = Theme.Label(milestonePanel,
    "Community Progress: 0 / 500,000 crafts  —  Unlock: 2× drop rate for all players for 48 hrs",
    Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body, "CommunityLabel")
communityLabel.Size = UDim2.new(1, -10, 0, 20)
communityLabel.Position = UDim2.new(0, 10, 0, 4)

-- Progress bar
local milestoneBarBg = Instance.new("Frame")
milestoneBarBg.Name = "MilestoneBarBg"
milestoneBarBg.Size = UDim2.new(1, -16, 0, 12)
milestoneBarBg.Position = UDim2.new(0, 8, 0, 30)
milestoneBarBg.BackgroundColor3 = Theme.Colors.PanelAlt
milestoneBarBg.BorderSizePixel = 0
milestoneBarBg.Parent = milestonePanel
Theme.AddCorner(milestoneBarBg, Theme.Corner.Small)

local milestoneBarFill = Instance.new("Frame")
milestoneBarFill.Name = "MilestoneBarFill"
milestoneBarFill.Size = UDim2.new(0, 0, 1, 0)
milestoneBarFill.BackgroundColor3 = Theme.Colors.Gold
milestoneBarFill.BorderSizePixel = 0
milestoneBarFill.Parent = milestoneBarBg
Theme.AddCorner(milestoneBarFill, Theme.Corner.Small)

-- ── Track label row ───────────────────────────────────────────────────────────
local trackLabelRow = Instance.new("Frame")
trackLabelRow.Name = "TrackLabelRow"
trackLabelRow.Size = UDim2.new(0, 90, 1, -132)
trackLabelRow.Position = UDim2.new(0, 8, 0, 130)
trackLabelRow.BackgroundColor3 = Theme.Colors.Panel
trackLabelRow.BorderSizePixel = 0
trackLabelRow.Parent = container
Theme.AddCorner(trackLabelRow, Theme.Corner.Small)

local trackNames = { "FREE", "STANDARD", "PREMIUM" }
local trackColors = { Theme.Colors.TextSecondary, Theme.Colors.Info, Theme.Colors.Legendary }
local trackH = math.floor((560 - 132 - 8) / 3)

for i, name in ipairs(trackNames) do
    local lbl = Theme.Label(trackLabelRow, name, Theme.TextSize.Small,
        trackColors[i], Theme.Fonts.Heading)
    lbl.Size = UDim2.new(1, -8, 0, trackH - 8)
    lbl.Position = UDim2.new(0, 4, 0, (i-1) * trackH + 4)
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.VerticalAlignment.Center
    lbl.TextWrapped = true
end

-- ── Horizontal week scroll ────────────────────────────────────────────────────
local trackScroll = Instance.new("ScrollingFrame")
trackScroll.Name = "TrackScroll"
trackScroll.Size = UDim2.new(1, -108, 1, -132)
trackScroll.Position = UDim2.new(0, 106, 0, 130)
trackScroll.BackgroundTransparency = 1
trackScroll.BorderSizePixel = 0
trackScroll.ScrollBarThickness = 6
trackScroll.ScrollBarImageColor3 = Theme.Colors.Accent
trackScroll.ScrollingDirection = Enum.ScrollingDirection.X
trackScroll.CanvasSize = UDim2.new(0, 0, 1, 0)
trackScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
trackScroll.Parent = container

local weekLayout = Instance.new("UIListLayout")
weekLayout.FillDirection = Enum.FillDirection.Horizontal
weekLayout.Padding = UDim.new(0, 6)
weekLayout.SortOrder = Enum.SortOrder.LayoutOrder
weekLayout.Parent = trackScroll
Theme.AddPadding(trackScroll, 0, 4, 0, 4)

-- Render placeholder week cards (will be replaced by ShopController)
for w = 1, 7 do
    local weekCard = Instance.new("Frame")
    weekCard.Name = "Week" .. w
    weekCard.LayoutOrder = w
    weekCard.Size = UDim2.new(0, 128, 1, 0)
    weekCard.BackgroundColor3 = Theme.Colors.Panel
    weekCard.BorderSizePixel = 0
    weekCard.Parent = trackScroll
    Theme.AddCorner(weekCard, Theme.Corner.Small)

    -- Week number
    local weekLbl = Theme.Label(weekCard, "Week " .. w, Theme.TextSize.Heading,
        w == 1 and Theme.Colors.Gold or Theme.Colors.TextSecondary, Theme.Fonts.Heading)
    weekLbl.Size = UDim2.new(1, -8, 0, 24)
    weekLbl.Position = UDim2.new(0, 6, 0, 4)
    weekLbl.TextXAlignment = Enum.TextXAlignment.Center

    -- Three track reward slots
    local slotColors = { Theme.Colors.TextDim, Theme.Colors.Info, Theme.Colors.Legendary }
    local slotH = math.floor((560 - 132 - 30 - 8) / 3) - 4

    for ti = 1, 3 do
        local slot = Instance.new("Frame")
        slot.Size = UDim2.new(1, -8, 0, slotH)
        slot.Position = UDim2.new(0, 4, 0, 30 + (ti-1) * (slotH + 4))
        slot.BackgroundColor3 = Theme.Colors.PanelAlt
        slot.BorderSizePixel = 0
        slot.Parent = weekCard
        Theme.AddCorner(slot, Theme.Corner.Small)

        -- Left track indicator stripe
        local stripe = Theme.Stripe(slot, slotColors[ti])

        local rewardLbl = Theme.Label(slot, "—", Theme.TextSize.Small,
            slotColors[ti], Theme.Fonts.Body, "RewardLabel" .. ti)
        rewardLbl.Size = UDim2.new(1, -12, 0.6, 0)
        rewardLbl.Position = UDim2.new(0, 8, 0.2, 0)
        rewardLbl.TextXAlignment = Enum.TextXAlignment.Center
        rewardLbl.TextWrapped = true
    end
end
