-- Creates the persistent heads-up display ScreenGui.
-- Named elements are expected by HUDController.

local Players    = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)

-- ── Root ScreenGui ────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ── MainFrame (controller reference point) ────────────────────────────────────
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0, 0.5)
mainFrame.Size = UDim2.new(0, 150, 0, 6 * 36 + 12)
mainFrame.Position = UDim2.new(0, 8, 0.5, 0)
mainFrame.BackgroundColor3 = Theme.Colors.Panel
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui
Theme.AddCorner(mainFrame, Theme.Corner.Large)
ScaleUI.ApplyHud(mainFrame)

-- Player Level
local playerLevelLabel = Instance.new("TextLabel")
playerLevelLabel.Name = "PlayerLevelLabel"
playerLevelLabel.Size = UDim2.new(1, -20, 0, 32)
playerLevelLabel.Position = UDim2.new(0, 12, 0, 6)
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
forgeLevelLabel.Size = UDim2.new(1, -20, 0, 32)
forgeLevelLabel.Position = UDim2.new(0, 12, 0, 42)
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
coinsLabel.Size = UDim2.new(1, -20, 0, 32)
coinsLabel.Position = UDim2.new(0, 12, 0, 78)
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
golemSlotsLabel.Size = UDim2.new(1, -20, 0, 32)
golemSlotsLabel.Position = UDim2.new(0, 12, 0, 114)
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
masteryLabel.Size = UDim2.new(1, -20, 0, 32)
masteryLabel.Position = UDim2.new(0, 12, 0, 150)
masteryLabel.BackgroundTransparency = 1
masteryLabel.Text = "M: Lv 0"
masteryLabel.TextColor3 = Color3.fromRGB(160, 120, 220)
masteryLabel.Font = Theme.Fonts.Body
masteryLabel.TextSize = 13
masteryLabel.TextXAlignment = Enum.TextXAlignment.Left
masteryLabel.Parent = mainFrame

-- Smelter status
local smeltStatusLabel = Instance.new("TextLabel")
smeltStatusLabel.Name = "SmeltStatusLabel"
smeltStatusLabel.Size = UDim2.new(1, -20, 0, 32)
smeltStatusLabel.Position = UDim2.new(0, 12, 0, 6 + 5 * 36)
smeltStatusLabel.BackgroundTransparency = 1
smeltStatusLabel.Text = "Smelter idle"
smeltStatusLabel.TextColor3 = Theme.Colors.TextSecondary
smeltStatusLabel.Font = Theme.Fonts.Body
smeltStatusLabel.TextSize = 13
smeltStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
smeltStatusLabel.Parent = mainFrame

-- ── Navigation: big icon hotbar (bottom) + small icon column (right) ─────────
local NAV = {
    -- primary: the things you do every session
    { name = "ForgeButton",       icon = "🔥", label = "Forge",      key = "F", color = Color3.fromRGB(235, 110, 40),  targetGui = "ForgeMenu",       primary = true },
    { name = "InventoryButton",   icon = "🎒", label = "Bag",        key = "B", color = Color3.fromRGB(190, 130, 70),  targetGui = "InventoryMenu",   primary = true },
    { name = "MarketButton",      icon = "🏪", label = "Market",     key = "M", color = Color3.fromRGB(70, 180, 100),  targetGui = "MarketMenu",      primary = true },
    { name = "ChallengesButton",  icon = "📋", label = "Quests",     key = "Q", color = Color3.fromRGB(80, 150, 230),  targetGui = "ChallengesMenu",  primary = true },
    { name = "ShopButton",        icon = "💎", label = "Shop",       key = "P", color = Color3.fromRGB(160, 100, 230), targetGui = "ShopMenu",        primary = true },
    -- secondary
    { name = "TradeButton",       icon = "🤝", label = "Trades",     color = Color3.fromRGB(70, 160, 170),  targetGui = "TradeMenu"       },
    { name = "SeasonButton",      icon = "🌟", label = "Season",     color = Color3.fromRGB(230, 180, 50),  targetGui = "SeasonMenu"      },
    { name = "StyleButton",       icon = "🎨", label = "Style",      color = Color3.fromRGB(220, 90, 150),  targetGui = "StyleMenu"       },
    { name = "PetsButton",        icon = "🐾", label = "Pets",       color = Color3.fromRGB(110, 185, 100), targetGui = "PetsMenu"        },
    { name = "GuildButton",       icon = "🛡️", label = "Guild",      color = Color3.fromRGB(90, 130, 210),  targetGui = "GuildMenu"       },
    { name = "HomeButton",        icon = "🏠", label = "My Forge",   color = Color3.fromRGB(120, 130, 150), action = "GoToMyForge"        },
    { name = "LeaderboardBtn",    icon = "🏆", label = "Leaders",    color = Color3.fromRGB(200, 150, 60),  targetGui = "LeaderboardMenu" },
}

local function OpenNav(nav)
    if nav.action then
        local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
        RemoteEvents.Load()
        RemoteEvents[nav.action]:FireServer()
        return
    end
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local target = pg:FindFirstChild(nav.targetGui)
    if target then
        target.Enabled = not target.Enabled
    else
        warn("[HUD] Menu not found in PlayerGui: " .. nav.targetGui)
    end
end

-- One icon tile: coloured button, big icon, small caption, optional hotkey and red badge
local function MakeTile(parent, nav, size)
    local btn = Theme.Button(parent, "", nav.color, Color3.fromRGB(255, 255, 255), nav.name)
    btn.Size = UDim2.new(0, size, 0, size)
    Theme.AddCorner(btn, UDim.new(0, size >= 70 and 18 or 14))

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(1, 0, 0, size * 0.58)
    icon.Position = UDim2.new(0, 0, 0, size * 0.06)
    icon.Text = nav.icon
    icon.TextSize = size * 0.42
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = Color3.fromRGB(255, 255, 255)
    icon.Parent = btn

    local cap = Instance.new("TextLabel")
    cap.Name = "Caption"
    cap.BackgroundTransparency = 1
    cap.Size = UDim2.new(1, 0, 0, size * 0.26)
    cap.Position = UDim2.new(0, 0, 1, -size * 0.30)
    cap.Text = nav.label
    cap.TextSize = size >= 70 and 13 or 11
    cap.Font = Enum.Font.GothamBlack
    cap.TextColor3 = Color3.fromRGB(255, 255, 255)
    cap.TextStrokeColor3 = Color3.fromRGB(20, 12, 8)
    cap.TextStrokeTransparency = 0.3
    cap.Parent = btn

    if nav.key then
        local hint = Instance.new("TextLabel")
        hint.Name = "KeyHint"
        hint.BackgroundColor3 = Color3.fromRGB(20, 14, 12)
        hint.BackgroundTransparency = 0.35
        hint.BorderSizePixel = 0
        hint.Size = UDim2.new(0, 16, 0, 16)
        hint.Position = UDim2.new(0, 4, 0, 4)
        hint.Text = nav.key
        hint.TextSize = 11
        hint.Font = Enum.Font.GothamBold
        hint.TextColor3 = Color3.fromRGB(255, 255, 255)
        hint.Parent = btn
        Theme.AddCorner(hint, UDim.new(0, 4))
    end

    local badge = Instance.new("TextLabel")
    badge.Name = "Badge"
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Position = UDim2.new(1, 6, 0, -6)
    badge.Size = UDim2.new(0, 24, 0, 24)
    badge.AutomaticSize = Enum.AutomaticSize.X
    badge.BackgroundColor3 = Color3.fromRGB(215, 48, 42)
    badge.BorderSizePixel = 0
    badge.Text = ""
    badge.TextColor3 = Color3.fromRGB(255, 255, 255)
    badge.Font = Enum.Font.GothamBlack
    badge.TextSize = 13
    badge.ZIndex = 6
    badge.Visible = false
    badge.Parent = btn
    Theme.AddCorner(badge, UDim.new(0, 12))
    Theme.AddPadding(badge, 0, 6, 0, 6)
    Theme.AddStroke(badge, Color3.fromRGB(255, 255, 255), 2)

    btn.MouseButton1Click:Connect(function() OpenNav(nav) end)
    return btn
end

local TILE, GAP = 76, 8
local nPrimary = 0
for _, nav in ipairs(NAV) do if nav.primary then nPrimary += 1 end end

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Size = UDim2.new(0, nPrimary * TILE + (nPrimary - 1) * GAP + 24, 0, TILE + 22)
hotbar.Position = UDim2.new(0.5, 0, 1, -14)
hotbar.BackgroundColor3 = Theme.Colors.Panel
hotbar.BackgroundTransparency = 0.1
hotbar.BorderSizePixel = 0
hotbar.Parent = gui
Theme.AddCorner(hotbar, UDim.new(0, 24))
Theme.AddStroke(hotbar, Color3.fromRGB(24, 17, 14), 3, 0.2)
ScaleUI.ApplyHud(hotbar)

local nSecondary = #NAV - nPrimary
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.AnchorPoint = Vector2.new(1, 0.5)
sidebar.Position = UDim2.new(1, -12, 0.5, 0)
sidebar.Size = UDim2.new(0, 56 + 16, 0, nSecondary * 64 + 8)          -- tall enough for every icon (it grows as tiles are added)
sidebar.BackgroundColor3 = Theme.Colors.Panel
sidebar.BackgroundTransparency = 0.25
sidebar.BorderSizePixel = 0
sidebar.Parent = gui
Theme.AddCorner(sidebar, UDim.new(0, 20))
ScaleUI.ApplyHud(sidebar)

-- On a short (landscape phone) screen the centred column runs into the jump button at the bottom right,
-- so it sits at the top edge instead; on a tall screen it stays centred.
local function PlaceSidebar()
    local cam = workspace.CurrentCamera
    local short = cam and cam.ViewportSize.Y < 520
    sidebar.AnchorPoint = short and Vector2.new(1, 0) or Vector2.new(1, 0.5)
    sidebar.Position = short and UDim2.new(1, -8, 0, 8) or UDim2.new(1, -12, 0.5, 0)
end
PlaceSidebar()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(PlaceSidebar) end

local pi, si = 0, 0
for _, nav in ipairs(NAV) do
    if nav.primary then
        local btn = MakeTile(hotbar, nav, TILE)
        btn.Position = UDim2.new(0, 12 + pi * (TILE + GAP), 0, 11)
        pi += 1
    else
        local btn = MakeTile(sidebar, nav, 56)
        btn.Position = UDim2.new(0, 8, 0, 8 + si * 64)
        si += 1
    end
end

-- Keyboard shortcuts for the hotbar (ignored while typing in a text box)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    for _, nav in ipairs(NAV) do
        if nav.key and input.KeyCode == Enum.KeyCode[nav.key] then OpenNav(nav) return end
    end
end)

-- ── Pending resources (per type) shown above the Collect button ──────────────
local pendingFrame = Instance.new("Frame")
pendingFrame.Name = "PendingFrame"
pendingFrame.AnchorPoint = Vector2.new(0.5, 1)
pendingFrame.Size = UDim2.new(0, 260, 0, 0)
pendingFrame.AutomaticSize = Enum.AutomaticSize.Y
pendingFrame.Position = UDim2.new(0.5, 0, 1, -184)
pendingFrame.BackgroundColor3 = Theme.Colors.Panel
pendingFrame.BackgroundTransparency = 0.15
pendingFrame.BorderSizePixel = 0
pendingFrame.Visible = false
pendingFrame.Parent = gui
Theme.AddCorner(pendingFrame, Theme.Corner.Large)
Theme.AddPadding(pendingFrame, 6, 10, 6, 10)

local pendingLabel = Instance.new("TextLabel")
pendingLabel.Name = "PendingLabel"
pendingLabel.Size = UDim2.new(1, 0, 0, 0)
pendingLabel.AutomaticSize = Enum.AutomaticSize.Y
pendingLabel.BackgroundTransparency = 1
pendingLabel.Text = ""
pendingLabel.TextColor3 = Theme.Colors.TextPrimary
pendingLabel.Font = Theme.Fonts.Body
pendingLabel.TextSize = 14
pendingLabel.TextXAlignment = Enum.TextXAlignment.Left
pendingLabel.TextYAlignment = Enum.TextYAlignment.Top
pendingLabel.Parent = pendingFrame

-- ── Bottom action bar ─────────────────────────────────────────────────────────
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(0, 220, 0, 52)
bottomBar.Position = UDim2.new(0.5, -110, 1, -176)
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
boostStrip.Position = UDim2.new(0.5, -140, 0, 90)
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
