-- Creates the Challenges ScreenGui: daily, weekly and lifetime achievement panels.
-- Named elements expected by ChallengesController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)

local gui = Instance.new("ScreenGui")
gui.Name = "ChallengesMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Scrim
local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1,0,1,0)
scrim.BackgroundColor3 = Color3.fromRGB(0,0,0)
scrim.BackgroundTransparency = 0.45
scrim.BorderSizePixel = 0
scrim.Parent = gui
scrim.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then gui.Enabled = false end
end)

-- Container
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 820, 0, 580)
ScaleUI.Apply(container, 820, 580)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel = 0
container.Parent = gui
Theme.AddCorner(container, Theme.Corner.Large)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tf = Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,12); tf.Position=UDim2.new(0,0,1,-12)
tf.BackgroundColor3=Theme.Colors.Panel; tf.BorderSizePixel=0; tf.Parent=titleBar

Theme.Label(titleBar, "🎯  Challenges", Theme.TextSize.Title,
    Theme.Colors.AccentBright, Theme.Fonts.Title).Size = UDim2.new(0.5, 0, 1, 0)

-- Reset timers
local dailyResetLabel = Theme.Label(titleBar, "Daily reset: —", Theme.TextSize.Small,
    Theme.Colors.TextDim, Theme.Fonts.Body, "DailyResetLabel")
dailyResetLabel.Size = UDim2.new(0, 180, 0, 20)
dailyResetLabel.Position = UDim2.new(0.5, 0, 0, 8)

local weeklyResetLabel = Theme.Label(titleBar, "Weekly reset: —", Theme.TextSize.Small,
    Theme.Colors.TextDim, Theme.Fonts.Body, "WeeklyResetLabel")
weeklyResetLabel.Size = UDim2.new(0, 180, 0, 20)
weeklyResetLabel.Position = UDim2.new(0.5, 0, 0, 26)

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 40)
tabBar.Position = UDim2.new(0, 0, 0, 50)
tabBar.BackgroundColor3 = Theme.Colors.Panel
tabBar.BorderSizePixel = 0
tabBar.Parent = container
Theme.AddPadding(tabBar, 5, 6, 5, 8)
Theme.AddListLayout(tabBar, Enum.FillDirection.Horizontal, 6)

local tabDefs = {
    { name = "DailyTab",    label = "Daily",    color = Theme.Colors.Success  },
    { name = "WeeklyTab",   label = "Weekly",   color = Theme.Colors.Info     },
    { name = "LifetimeTab", label = "Lifetime", color = Theme.Colors.Legendary },
}
local tabBtns  = {}
local tabPanels = {}

for _, td in ipairs(tabDefs) do
    local btn = Theme.Button(tabBar, td.label, Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, td.name)
    btn.Size = UDim2.new(0, 120, 0, 30)
    btn.TextSize = 13
    tabBtns[td.name] = { btn = btn, color = td.color }
end

-- Content area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -16, 1, -98)
contentArea.Position = UDim2.new(0, 8, 0, 94)
contentArea.BackgroundTransparency = 1
contentArea.Parent = container

-- Helper: build a challenge list panel
local function makePanel(name)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = contentArea

    local scroll = Theme.ScrollFrame(panel, name .. "Scroll")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

    -- Layout for cards
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    Theme.AddPadding(scroll, 4, 4, 4, 4)

    return panel, scroll
end

local dailyPanel,    dailyScroll    = makePanel("DailyPanel")
local weeklyPanel,   weeklyScroll   = makePanel("WeeklyPanel")
local lifetimePanel, lifetimeScroll = makePanel("LifetimePanel")

tabPanels["DailyTab"]    = dailyPanel
tabPanels["WeeklyTab"]   = weeklyPanel
tabPanels["LifetimeTab"] = lifetimePanel

-- Challenge card factory (used by ChallengesController to populate each tab)
-- Exposed as gui.BuildChallengeCard so the controller can call it
local function BuildChallengeCard(scroll, challenge, progress, claimed, layoutOrder)
    local isComplete = progress >= challenge.target
    local cardColor  = claimed and Theme.Colors.PanelAlt
                    or isComplete and Color3.fromRGB(40, 60, 35)
                    or Theme.Colors.Panel

    local card = Instance.new("Frame")
    card.Name = challenge.id
    card.LayoutOrder = layoutOrder or 0
    card.Size = UDim2.new(1, -8, 0, 88)
    card.BackgroundColor3 = cardColor
    card.BorderSizePixel = 0
    card.Parent = scroll
    Theme.AddCorner(card, Theme.Corner.Medium)

    -- Completion stripe
    local stripeColor = claimed and Theme.Colors.TextDim
                     or isComplete and Theme.Colors.Success
                     or Theme.Colors.AccentDim
    Theme.Stripe(card, stripeColor)

    -- Title
    local titleLbl = Theme.Label(card, challenge.displayName, Theme.TextSize.Heading,
        claimed and Theme.Colors.TextDim or Theme.Colors.TextPrimary, Theme.Fonts.Heading, "TitleLabel")
    titleLbl.Size = UDim2.new(0.7, 0, 0, 22)
    titleLbl.Position = UDim2.new(0, 10, 0, 6)

    -- Description
    local descLbl = Theme.Label(card, challenge.description, Theme.TextSize.Small,
        Theme.Colors.TextSecondary, Theme.Fonts.Body, "DescLabel")
    descLbl.Size = UDim2.new(0.7, 0, 0, 18)
    descLbl.Position = UDim2.new(0, 10, 0, 28)

    -- Reward summary
    local rewards = challenge.rewards or {}
    local rewardParts = {}
    if rewards.coins   then table.insert(rewardParts, rewards.coins .. " coins") end
    if rewards.xp      then table.insert(rewardParts, rewards.xp .. " XP") end
    if rewards.blueprints and #rewards.blueprints > 0 then
        table.insert(rewardParts, "Blueprint")
    end
    if rewards.title   then table.insert(rewardParts, "Title: " .. rewards.title) end
    if rewards.materials then
        for _, m in ipairs(rewards.materials) do
            local mat = MaterialData.Get(m.id)
            table.insert(rewardParts, m.qty .. "× " .. (mat and mat.displayName or m.id))
        end
    end

    local rewardLbl = Theme.Label(card, "Reward: " .. table.concat(rewardParts, " • "),
        Theme.TextSize.Small, Theme.Colors.Gold, Theme.Fonts.Body, "RewardLabel")
    rewardLbl.Size = UDim2.new(0.7, 0, 0, 16)
    rewardLbl.Position = UDim2.new(0, 10, 0, 48)

    -- Progress bar background
    local barBg = Instance.new("Frame")
    barBg.Name = "ProgressBarBg"
    barBg.Size = UDim2.new(0.68, 0, 0, 8)
    barBg.Position = UDim2.new(0, 10, 0, 70)
    barBg.BackgroundColor3 = Theme.Colors.PanelAlt
    barBg.BorderSizePixel = 0
    barBg.Parent = card
    Theme.AddCorner(barBg, Theme.Corner.Small)

    local fillPct = math.min(progress / challenge.target, 1)
    local barFill = Instance.new("Frame")
    barFill.Name = "ProgressBarFill"
    barFill.Size = UDim2.new(fillPct, 0, 1, 0)
    barFill.BackgroundColor3 = isComplete and Theme.Colors.Success or Theme.Colors.Accent
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Theme.AddCorner(barFill, Theme.Corner.Small)

    -- Progress text
    local progressLbl = Theme.Label(card, progress .. " / " .. challenge.target,
        Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Mono, "ProgressLabel")
    progressLbl.Size = UDim2.new(0, 80, 0, 16)
    progressLbl.Position = UDim2.new(0, 10, 0, 68)

    -- Claim button
    local claimBtn = Theme.Button(card,
        claimed and "Claimed" or isComplete and "Claim!" or "In Progress",
        claimed and Theme.Colors.TextDim or isComplete and Theme.Colors.Success or Theme.Colors.PanelAlt,
        Color3.fromRGB(255,255,255), "ClaimButton")
    claimBtn.Name = "ClaimButton_" .. challenge.id
    claimBtn.Size = UDim2.new(0, 110, 0, 34)
    claimBtn.Position = UDim2.new(1, -118, 0.5, -17)
    claimBtn.TextSize = 13
    claimBtn.Active = not claimed and isComplete

    return card, claimBtn
end

-- Expose factory and scrolls as attributes that ChallengesController reads
gui:SetAttribute("ready", true)
-- Store references in a module-style value object so the controller can reach them
local refs = Instance.new("ObjectValue"); refs.Name = "DailyScroll";    refs.Value = dailyScroll;    refs.Parent = gui
local refs2 = Instance.new("ObjectValue"); refs2.Name = "WeeklyScroll";  refs2.Value = weeklyScroll;  refs2.Parent = gui
local refs3 = Instance.new("ObjectValue"); refs3.Name = "LifetimeScroll";refs3.Value = lifetimeScroll;refs3.Parent = gui

-- Tab switching
local function switchTab(selected)
    for name, data in pairs(tabBtns) do
        local isSelected = name == selected
        data.btn.BackgroundColor3 = isSelected and data.color or Theme.Colors.PanelAlt
        data.btn.TextColor3       = isSelected and Color3.fromRGB(255,255,255) or Theme.Colors.TextSecondary
    end
    for name, panel in pairs(tabPanels) do
        panel.Visible = name == selected
    end
end

for name, data in pairs(tabBtns) do
    data.btn.MouseButton1Click:Connect(function() switchTab(name) end)
end
switchTab("DailyTab")

-- Expose BuildChallengeCard via a BindableFunction so ChallengesController can call it
local buildFn = Instance.new("BindableFunction")
buildFn.Name = "BuildChallengeCard"
buildFn.OnInvoke = BuildChallengeCard
buildFn.Parent = gui
