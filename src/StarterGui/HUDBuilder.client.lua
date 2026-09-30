-- Creates the persistent heads-up display ScreenGui.
-- Named elements are expected by HUDController.

local Players    = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

-- ── Root ScreenGui ────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ── Top bar ───────────────────────────────────────────────────────────────────
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 48)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Theme.Colors.Background
topBar.BackgroundTransparency = 0.15
topBar.BorderSizePixel = 0
topBar.Parent = gui

Theme.AddCorner(topBar, UDim.new(0, 0))  -- no radius on top bar

-- gradient
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Colors.Panel),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 8, 6)),
})
grad.Rotation = 90
grad.Parent = topBar

-- ── MainFrame (controller reference point) ────────────────────────────────────
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(1, 0, 0, 48)
mainFrame.BackgroundTransparency = 1
mainFrame.Parent = topBar

-- Player Level
local playerLevelLabel = Instance.new("TextLabel")
playerLevelLabel.Name = "PlayerLevelLabel"
playerLevelLabel.Size = UDim2.new(0, 110, 0, 44)
playerLevelLabel.Position = UDim2.new(0, 8, 0, 2)
playerLevelLabel.BackgroundTransparency = 1
playerLevelLabel.Text = "Level 1"
playerLevelLabel.TextColor3 = Theme.Colors.Gold
playerLevelLabel.Font = Theme.Fonts.Heading
playerLevelLabel.TextSize = 15
playerLevelLabel.TextXAlignment = Enum.TextXAlignment.Left
playerLevelLabel.Parent = mainFrame

-- Forge Level
local forgeLevelLabel = Instance.new("TextLabel")
forgeLevelLabel.Name = "ForgeLevelLabel"
forgeLevelLabel.Size = UDim2.new(0, 110, 0, 44)
forgeLevelLabel.Position = UDim2.new(0, 118, 0, 2)
forgeLevelLabel.BackgroundTransparency = 1
forgeLevelLabel.Text = "Forge 1"
forgeLevelLabel.TextColor3 = Theme.Colors.Ember
forgeLevelLabel.Font = Theme.Fonts.Heading
forgeLevelLabel.TextSize = 15
forgeLevelLabel.TextXAlignment = Enum.TextXAlignment.Left
forgeLevelLabel.Parent = mainFrame

-- Ember Coins
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.new(0, 120, 0, 44)
coinsLabel.Position = UDim2.new(0, 228, 0, 2)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "200 ⚡"
coinsLabel.TextColor3 = Theme.Colors.Gold
coinsLabel.Font = Theme.Fonts.Heading
coinsLabel.TextSize = 15
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Parent = mainFrame

-- Golem Slots
local golemSlotsLabel = Instance.new("TextLabel")
golemSlotsLabel.Name = "GolemSlotsLabel"
golemSlotsLabel.Size = UDim2.new(0, 100, 0, 44)
golemSlotsLabel.Position = UDim2.new(0, 348, 0, 2)
golemSlotsLabel.BackgroundTransparency = 1
golemSlotsLabel.Text = "3 Slots"
golemSlotsLabel.TextColor3 = Theme.Colors.TextSecondary
golemSlotsLabel.Font = Theme.Fonts.Body
golemSlotsLabel.TextSize = 13
golemSlotsLabel.TextXAlignment = Enum.TextXAlignment.Left
golemSlotsLabel.Parent = mainFrame

-- Mastery (highest element mastery across all elements)
local masteryLabel = Instance.new("TextLabel")
masteryLabel.Name = "MasteryLabel"
masteryLabel.Size = UDim2.new(0, 90, 0, 44)
masteryLabel.Position = UDim2.new(0, 448, 0, 2)
masteryLabel.BackgroundTransparency = 1
masteryLabel.Text = "M: Lv 0"
masteryLabel.TextColor3 = Color3.fromRGB(160, 120, 220)
masteryLabel.Font = Theme.Fonts.Body
masteryLabel.TextSize = 13
masteryLabel.TextXAlignment = Enum.TextXAlignment.Left
masteryLabel.Parent = mainFrame

-- ── Right-side nav buttons ────────────────────────────────────────────────────
local navData = {
    { name = "InventoryButton",   label = "🎒 Inventory",  targetGui = "InventoryMenu"   },
    { name = "ForgeButton",       label = "🔥 Forge",      targetGui = "ForgeMenu"       },
    { name = "MarketButton",      label = "🏪 Market",     targetGui = "MarketMenu"      },
    { name = "ShopButton",        label = "💎 Shop",       targetGui = "ShopMenu"        },
    { name = "SeasonButton",      label = "🌟 Season",     targetGui = "SeasonMenu"      },
    { name = "ChallengesButton",  label = "📋 Challenges", targetGui = "ChallengesMenu"  },
    { name = "LeaderboardBtn",    label = "🏆 Leaders",    targetGui = "LeaderboardMenu" },
}

-- Right-hand sidebar, vertically centred
local BTN_H, BTN_GAP, SIDE_W = 38, 6, 132
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.AnchorPoint = Vector2.new(1, 0.5)
sidebar.Size = UDim2.new(0, SIDE_W, 0, #navData * (BTN_H + BTN_GAP) + BTN_GAP)
sidebar.Position = UDim2.new(1, -8, 0.5, 0)
sidebar.BackgroundColor3 = Theme.Colors.Panel
sidebar.BackgroundTransparency = 0.15
sidebar.BorderSizePixel = 0
sidebar.Parent = gui
Theme.AddCorner(sidebar, Theme.Corner.Large)

for i, nav in ipairs(navData) do
    local btn = Theme.Button(sidebar, nav.label, Theme.Colors.PanelAlt, Theme.Colors.AccentBright, nav.name)
    btn.Size = UDim2.new(1, -12, 0, BTN_H)
    btn.Position = UDim2.new(0, 6, 0, BTN_GAP + (i - 1) * (BTN_H + BTN_GAP))
    btn.TextSize = 13

    btn.MouseButton1Click:Connect(function()
        local pg = LocalPlayer:WaitForChild("PlayerGui")
        local target = pg:FindFirstChild(nav.targetGui)
        if target then
            target.Enabled = not target.Enabled
        else
            warn("[HUD] Menu not found in PlayerGui: " .. nav.targetGui)
        end
    end)
end

-- ── Bottom action bar ─────────────────────────────────────────────────────────
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(0, 220, 0, 52)
bottomBar.Position = UDim2.new(0.5, -110, 1, -62)
bottomBar.BackgroundColor3 = Theme.Colors.Panel
bottomBar.BackgroundTransparency = 0.1
bottomBar.BorderSizePixel = 0
bottomBar.Parent = gui
Theme.AddCorner(bottomBar, Theme.Corner.Large)

-- Collect button
local collectBtn = Theme.Button(bottomBar, "⛏  Collect Resources", Theme.Colors.Accent, Color3.fromRGB(255,255,255), "CollectButton")
collectBtn.Size = UDim2.new(1, -12, 0, 38)
collectBtn.Position = UDim2.new(0, 6, 0, 7)
collectBtn.TextSize = 15

-- pulse animation on collect button
local TweenService = game:GetService("TweenService")
local function pulseCollect()
    local t1 = TweenService:Create(collectBtn, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundColor3 = Theme.Colors.AccentBright })
    t1:Play()
end
task.spawn(pulseCollect)

-- ── Active boosts strip ────────────────────────────────────────────────────────
local boostStrip = Instance.new("Frame")
boostStrip.Name = "BoostStrip"
boostStrip.Size = UDim2.new(0, 280, 0, 24)
boostStrip.Position = UDim2.new(0.5, -140, 1, -32)
boostStrip.BackgroundTransparency = 1
boostStrip.Parent = gui
Theme.AddListLayout(boostStrip, Enum.FillDirection.Horizontal, 6)

local magnetLabel = Theme.Label(boostStrip, "", Theme.TextSize.Small,
    Color3.fromRGB(100, 220, 100), Theme.Fonts.Mono, "MagnetBoostLabel")
magnetLabel.Size    = UDim2.new(0, 130, 0, 22)
magnetLabel.Visible = false

local slotBoostLabel = Theme.Label(boostStrip, "", Theme.TextSize.Small,
    Color3.fromRGB(100, 170, 255), Theme.Fonts.Mono, "SlotBoostLabel")
slotBoostLabel.Size    = UDim2.new(0, 130, 0, 22)
slotBoostLabel.Visible = false

-- ── XP progress bar at very bottom ───────────────────────────────────────────
local xpBarBg = Instance.new("Frame")
xpBarBg.Name = "XPBarBg"
xpBarBg.Size = UDim2.new(1, 0, 0, 4)
xpBarBg.Position = UDim2.new(0, 0, 1, -4)
xpBarBg.BackgroundColor3 = Theme.Colors.PanelAlt
xpBarBg.BorderSizePixel = 0
xpBarBg.Parent = gui

local xpBarFill = Instance.new("Frame")
xpBarFill.Name = "XPBarFill"
xpBarFill.Size = UDim2.new(0, 0, 1, 0)
xpBarFill.BackgroundColor3 = Theme.Colors.Gold
xpBarFill.BorderSizePixel = 0
xpBarFill.Parent = xpBarBg
