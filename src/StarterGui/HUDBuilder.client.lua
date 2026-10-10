-- Creates the persistent heads-up display ScreenGui.
-- Named elements are expected by HUDController.

local Players    = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local MaterialIcon = require(game.ReplicatedStorage.Shared.Modules.MaterialIcon)

-- ── Root ScreenGui ────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ── MainFrame: the player card on the left (controller reference point) ──────
-- A level badge with the player's name and an XP bar, the coin purse, then accent-striped rows for Forge, Mastery, the Golem slots (one pip per slot:
-- green working, red broken, hollow free) and the Smelter. HUDController.Refresh fills in the numbers; the names below are what it looks for.
local CARD_W = 196
local function Gradient(parent, top, bottom)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(top, bottom)
    g.Rotation = 90
    g.Parent = parent
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0, 0.5)
mainFrame.Size = UDim2.new(0, CARD_W, 0, 352)
mainFrame.Position = UDim2.new(0, 8, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BackgroundTransparency = 0.04
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui
Theme.AddCorner(mainFrame, UDim.new(0, 16))
Gradient(mainFrame, Color3.fromRGB(70, 54, 44), Color3.fromRGB(38, 30, 27))
Theme.AddStroke(mainFrame, Theme.Colors.Accent, 2, 0.35)
ScaleUI.ApplyHud(mainFrame)

local function Text(parent, name, text, size, colour, font, pos, dim, align)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.BackgroundTransparency = 1
    l.Position = pos
    l.Size = dim
    l.Text = text
    l.TextSize = size
    l.TextColor3 = colour
    l.Font = font
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = parent
    return l
end

-- Header: level badge, name, XP bar
local badge = Instance.new("Frame")
badge.Name = "LevelBadge"
badge.Position = UDim2.new(0, 10, 0, 10)
badge.Size = UDim2.new(0, 50, 0, 50)
badge.BackgroundColor3 = Theme.Colors.Gold
badge.BorderSizePixel = 0
badge.Parent = mainFrame
Theme.AddCorner(badge, UDim.new(1, 0))
Gradient(badge, Color3.fromRGB(255, 226, 110), Color3.fromRGB(235, 160, 30))
Theme.AddStroke(badge, Color3.fromRGB(255, 240, 180), 2, 0.1)
Text(badge, "LevelCaption", "LEVEL", 9, Color3.fromRGB(90, 52, 8), Enum.Font.GothamBlack, UDim2.new(0, 0, 0, 7), UDim2.new(1, 0, 0, 10), Enum.TextXAlignment.Center)
local playerLevelLabel = Text(badge, "PlayerLevelLabel", "1", 22, Color3.fromRGB(60, 34, 4), Enum.Font.GothamBlack, UDim2.new(0, 0, 0, 16), UDim2.new(1, 0, 0, 28), Enum.TextXAlignment.Center)

Text(mainFrame, "PlayerNameLabel", LocalPlayer.DisplayName, 16, Color3.fromRGB(255, 244, 228), Enum.Font.GothamBlack,
    UDim2.new(0, 68, 0, 12), UDim2.new(1, -78, 0, 20))
local xpTrack = Instance.new("Frame")
xpTrack.Name = "PanelXPTrack"
xpTrack.Position = UDim2.new(0, 68, 0, 36)
xpTrack.Size = UDim2.new(1, -78, 0, 10)
xpTrack.BackgroundColor3 = Color3.fromRGB(24, 18, 16)
xpTrack.BorderSizePixel = 0
xpTrack.Parent = mainFrame
Theme.AddCorner(xpTrack, UDim.new(0, 5))
local xpFill = Instance.new("Frame")
xpFill.Name = "PanelXPFill"
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Theme.Colors.Gold
xpFill.BorderSizePixel = 0
xpFill.Parent = xpTrack
Theme.AddCorner(xpFill, UDim.new(0, 5))
Gradient(xpFill, Color3.fromRGB(255, 226, 110), Color3.fromRGB(240, 150, 30))
Text(mainFrame, "PanelXPText", "0 / 0 XP", 11, Color3.fromRGB(205, 190, 170), Enum.Font.Gotham, UDim2.new(0, 68, 0, 48), UDim2.new(1, -78, 0, 14))

-- Coin purse: a drawn coin and the amount, big
local purse = Instance.new("Frame")
purse.Name = "Purse"
purse.Position = UDim2.new(0, 10, 0, 72)
purse.Size = UDim2.new(1, -20, 0, 42)
purse.BackgroundColor3 = Color3.fromRGB(26, 20, 17)
purse.BackgroundTransparency = 0.15
purse.BorderSizePixel = 0
purse.Parent = mainFrame
Theme.AddCorner(purse, UDim.new(0, 12))
Theme.AddStroke(purse, Theme.Colors.Gold, 1.5, 0.55)
local coin = Instance.new("Frame")
coin.Name = "CoinIcon"
coin.Position = UDim2.new(0, 8, 0.5, -14)
coin.Size = UDim2.new(0, 28, 0, 28)
coin.BackgroundColor3 = Theme.Colors.Gold
coin.BorderSizePixel = 0
coin.Parent = purse
Theme.AddCorner(coin, UDim.new(1, 0))
Gradient(coin, Color3.fromRGB(255, 232, 130), Color3.fromRGB(225, 150, 20))
Theme.AddStroke(coin, Color3.fromRGB(255, 244, 190), 2, 0.1)
local coinInner = Instance.new("Frame")
coinInner.Position = UDim2.new(0.5, -8, 0.5, -8)
coinInner.Size = UDim2.new(0, 16, 0, 16)
coinInner.BackgroundTransparency = 1
coinInner.BorderSizePixel = 0
coinInner.Parent = coin
Theme.AddCorner(coinInner, UDim.new(1, 0))
Theme.AddStroke(coinInner, Color3.fromRGB(170, 105, 10), 2, 0.2)
local coinsLabel = Text(purse, "CoinsLabel", "200", 22, Theme.Colors.Gold, Enum.Font.GothamBlack, UDim2.new(0, 46, 0, 3), UDim2.new(1, -54, 0, 26))
Text(purse, "CoinsCaption", "EMBER COINS", 9, Color3.fromRGB(190, 160, 110), Enum.Font.GothamBold, UDim2.new(0, 46, 0, 27), UDim2.new(1, -54, 0, 12))

-- Accent-striped rows
local function Row(name, y, height, accent)
    local row = Instance.new("Frame")
    row.Name = name
    row.Position = UDim2.new(0, 10, 0, y)
    row.Size = UDim2.new(1, -20, 0, height)
    row.BackgroundColor3 = Color3.fromRGB(20, 15, 13)
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    row.Parent = mainFrame
    Theme.AddCorner(row, UDim.new(0, 10))
    local stripe = Instance.new("Frame")
    stripe.Name = "Stripe"
    stripe.Position = UDim2.new(0, 0, 0, 5)
    stripe.Size = UDim2.new(0, 4, 1, -10)
    stripe.BackgroundColor3 = accent
    stripe.BorderSizePixel = 0
    stripe.Parent = row
    Theme.AddCorner(stripe, UDim.new(0, 2))
    return row
end

local forgeRow = Row("ForgeRow", 122, 30, Theme.Colors.Ember)
local forgeLevelLabel = Text(forgeRow, "ForgeLevelLabel", "Forge 1", 15, Color3.fromRGB(255, 150, 90), Enum.Font.GothamBlack, UDim2.new(0, 14, 0, 0), UDim2.new(1, -20, 1, 0))

local masteryRow = Row("MasteryRow", 158, 30, Color3.fromRGB(160, 120, 220))
local masteryLabel = Text(masteryRow, "MasteryLabel", "Mastery Lv 0", 14, Color3.fromRGB(196, 160, 245), Enum.Font.GothamBold, UDim2.new(0, 14, 0, 0), UDim2.new(1, -20, 1, 0))

local golemRow = Row("GolemRow", 194, 56, Color3.fromRGB(90, 200, 110))
local golemSlotsLabel = Text(golemRow, "GolemSlotsLabel", "Golems 0/3", 13, Theme.Colors.TextSecondary, Enum.Font.GothamBold, UDim2.new(0, 14, 0, 3), UDim2.new(1, -20, 0, 23))
local pips = Instance.new("Frame")
pips.Name = "SlotPips"
pips.BackgroundTransparency = 1
pips.Position = UDim2.new(0, 14, 0, 28)
pips.Size = UDim2.new(1, -22, 0, 20)
pips.Parent = golemRow
local pipLayout = Instance.new("UIListLayout")
pipLayout.FillDirection = Enum.FillDirection.Horizontal
pipLayout.Padding = UDim.new(0, 4)
pipLayout.Parent = pips
for i = 1, 12 do                                    -- one pip per slot (the controller shows as many as you have)
    local pip = Instance.new("Frame")
    pip.Name = "Pip" .. i
    pip.Size = UDim2.new(0, 11, 0, 18)
    pip.BackgroundColor3 = Color3.fromRGB(90, 200, 110)
    pip.BackgroundTransparency = 1
    pip.BorderSizePixel = 0
    pip.LayoutOrder = i
    pip.Visible = false
    pip.Parent = pips
    Theme.AddCorner(pip, UDim.new(0, 4))
    Theme.AddStroke(pip, Color3.fromRGB(150, 140, 125), 1.5, 0.3)
end

local smeltRow = Row("SmeltRow", 256, 32, Color3.fromRGB(150, 140, 125))
local smeltStatusLabel = Text(smeltRow, "SmeltStatusLabel", "Smelter idle", 13, Theme.Colors.TextSecondary, Enum.Font.GothamBold, UDim2.new(0, 14, 0, 0), UDim2.new(1, -20, 1, 0))

-- On a short screen the small caption lines (LEVEL, EMBER COINS, the XP numbers) would be too tiny to read, and the badge, the coin
-- icon and the bar already say the same thing, so they are dropped there.
local function CompactCard()
    local cam = workspace.CurrentCamera
    local short = cam and cam.ViewportSize.Y < 520
    for _, name in ipairs({ "LevelCaption", "CoinsCaption", "PanelXPText" }) do
        local l = mainFrame:FindFirstChild(name, true)
        if l then l.Visible = not short end
    end
end
CompactCard()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(CompactCard) end

-- What to do next: one line, kept up to date by HUDController from NextGoal
local goalRow = Row("GoalRow", 294, 48, Theme.Colors.Gold)
local goalLabel = Text(goalRow, "GoalLabel", "", 12, Color3.fromRGB(255, 230, 170), Enum.Font.GothamBold, UDim2.new(0, 14, 0, 0), UDim2.new(1, -20, 1, 0))
goalLabel.TextWrapped = true
goalLabel.TextTruncate = Enum.TextTruncate.None

-- ── Navigation: big icon hotbar (bottom) + small icon column (right) ─────────
local NAV = {
    -- primary: the things you do every session
    { name = "ForgeButton",       mesh = "Forge", icon = "🔥", label = "Forge",      key = "F", color = Color3.fromRGB(235, 110, 40),  targetGui = "ForgeMenu",       primary = true },
    { name = "InventoryButton",   mesh = "Bag", icon = "🎒", label = "Bag",        key = "B", color = Color3.fromRGB(190, 130, 70),  targetGui = "InventoryMenu",   primary = true },
    { name = "MarketButton",      mesh = "Market", icon = "🏪", label = "Market",     key = "M", color = Color3.fromRGB(70, 180, 100),  targetGui = "MarketMenu",      primary = true },
    { name = "ChallengesButton",  mesh = "Quests", icon = "📋", label = "Quests",     key = "Q", color = Color3.fromRGB(80, 150, 230),  targetGui = "ChallengesMenu",  primary = true },
    { name = "ShopButton",        mesh = "Shop", icon = "💎", label = "Shop",       key = "P", color = Color3.fromRGB(160, 100, 230), targetGui = "ShopMenu",        primary = true },
    -- secondary
    { name = "TradeButton",       mesh = "Trades", icon = "🤝", label = "Trades",     color = Color3.fromRGB(70, 160, 170),  targetGui = "TradeMenu"       },
    { name = "SeasonButton",      mesh = "Season", icon = "🌟", label = "Season",     color = Color3.fromRGB(230, 180, 50),  targetGui = "SeasonMenu"      },
    { name = "StyleButton",       mesh = "Style", icon = "🎨", label = "Style",      color = Color3.fromRGB(220, 90, 150),  targetGui = "StyleMenu"       },
    { name = "PetsButton",        mesh = "Pets", icon = "🐾", label = "Pets",       color = Color3.fromRGB(110, 185, 100), targetGui = "PetsMenu"        },
    { name = "RewardsButton",     mesh = "Rewards", icon = "🎁", label = "Rewards",    color = Color3.fromRGB(215, 100, 90),  targetGui = "RewardsMenu"     },
    { name = "QuarryButton",      mesh = "Quarry", icon = "💎", label = "Quarry",     color = Color3.fromRGB(110, 150, 220), targetGui = "QuarryMenu"      },
    { name = "BuildButton",      mesh = "Build", icon = "🔨", label = "Build",      color = Color3.fromRGB(200, 130, 60),  targetGui = "BuildMenu"       },
    { name = "GuildButton",      mesh = "Guild", icon = "🛡️", label = "Guild",      color = Color3.fromRGB(90, 130, 210),  targetGui = "GuildMenu"       },
    { name = "HomeButton",        mesh = "Home", icon = "🏠", label = "My Forge",   color = Color3.fromRGB(120, 130, 150), action = "GoToMyForge"        },
    { name = "LeaderboardBtn",    mesh = "Leaders", icon = "🏆", label = "Leaders",    color = Color3.fromRGB(200, 150, 60),  targetGui = "LeaderboardMenu" },
    -- appears at Forge Level 10 (FeatureGates.Reveal): opens the Build menu on its Ascension tab
    { name = "AscendButton",      mesh = "Ascend", icon = "✨", label = "Ascend",     color = Color3.fromRGB(235, 190, 60),  targetGui = "BuildMenu", openTab = "Ascend", hidden = true },
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
        if nav.openTab and not target.Enabled then target:SetAttribute("OpenTab", nav.openTab) end
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

    -- the spinning 3D icon replaces the emoji once its mesh has loaded
    local function ApplyMesh()
        if btn:FindFirstChild("Mesh3D") then return true end
        local vp = MaterialIcon.Make(btn, "Nav_" .. (nav.mesh or ""), 10)
        if not vp then return false end
        vp.Name = "Mesh3D"
        vp.Size = UDim2.new(1, 0, 0, size * 0.68)
        vp.Position = UDim2.new(0, 0, 0, size * 0.02)
        icon.Text = ""
        return true
    end
    if not ApplyMesh() then
        local folder = game:GetService("ReplicatedStorage"):FindFirstChild("IconAssets")
        if folder then
            local conn
            conn = folder.ChildAdded:Connect(function()
                task.defer(function() if ApplyMesh() then conn:Disconnect() end end)
            end)
        end
    end

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

    local touchOnly = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
    if nav.key and not touchOnly then         -- keyboard hints mean nothing on a phone
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

    btn.MouseButton1Click:Connect(function()
        if btn:GetAttribute("GateReason") then return end       -- locked: GateController explains why
        OpenNav(nav)
    end)
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
sidebar.Size = UDim2.new(0, 56 + 16, 0, nSecondary * 64 + 8)
sidebar.BackgroundColor3 = Theme.Colors.Panel
sidebar.BackgroundTransparency = 0.25
sidebar.BorderSizePixel = 0
sidebar.Parent = gui
Theme.AddCorner(sidebar, UDim.new(0, 20))
local sidebarScale = Instance.new("UIScale")
sidebarScale.Parent = sidebar
local secondaryTiles = {}

-- Lays out the tiles that are visible (locked-far-away and not-yet-revealed ones take no room). On a short screen the column
-- becomes two columns so the buttons stay big enough to tap, instead of shrinking to a sliver.
local relayoutQueued = false
local function Relayout()
    local shown = {}
    for _, t in ipairs(secondaryTiles) do if t.Visible then table.insert(shown, t) end end
    local n = math.max(#shown, 1)
    local cam = workspace.CurrentCamera
    local vy = cam and cam.ViewportSize.Y or 720
    local avail = vy - 36 - 16                       -- 36 = Roblox top bar
    local cols = 1                                   -- add columns until the tiles can stay (nearly) full size
    while cols < 3 and avail / (math.ceil(n / cols) * 64 + 8) < 0.9 do cols += 1 end
    local rows = math.ceil(n / cols)
    for k, t in ipairs(shown) do
        t.Position = UDim2.new(0, 8 + ((k - 1) % cols) * 64, 0, 8 + math.floor((k - 1) / cols) * 64)
    end
    local h = rows * 64 + 8
    sidebar.Size = UDim2.new(0, cols * 64 + 8, 0, h)
    sidebar.Visible = #shown > 0
    sidebarScale.Scale = math.clamp(math.min(1, avail / h), 0.55, 1)       -- fit only: never shrunk just because the screen is small
end
local function QueueRelayout()                       -- several tiles can change in the same moment: lay out once
    if relayoutQueued then return end
    relayoutQueued = true
    task.defer(function() relayoutQueued = false Relayout() end)
end
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(QueueRelayout) end

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
        if nav.hidden then btn.Visible = false end
        table.insert(secondaryTiles, btn)
        btn:GetPropertyChangedSignal("Visible"):Connect(QueueRelayout)
        si += 1
    end
end

Relayout()

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
