-- Leaderboard modal: category tabs + ranked list of top 20 players.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme       = require(game.ReplicatedStorage.Shared.Modules.Theme)

local gui = Instance.new("ScreenGui")
gui.Name            = "LeaderboardMenu"
gui.ResetOnSpawn    = false
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Enabled         = false
gui.DisplayOrder    = 12
gui.Parent          = LocalPlayer:WaitForChild("PlayerGui")

-- Scrim
Theme.Scrim(gui)

-- Container
local container = Instance.new("Frame")
container.Name              = "Container"
container.Size              = UDim2.new(0, 540, 0, 560)
container.Position          = UDim2.new(0.5, -270, 0.5, -280)
container.BackgroundColor3  = Theme.Colors.Background
container.BorderSizePixel   = 0
container.Parent            = gui
Theme.AddCorner(container, Theme.Corner.Large)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size               = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3   = Theme.Colors.Panel
titleBar.BorderSizePixel    = 0
titleBar.Parent             = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tf = Instance.new("Frame")
tf.Size             = UDim2.new(1, 0, 0, 12)
tf.Position         = UDim2.new(0, 0, 1, -12)
tf.BackgroundColor3 = Theme.Colors.Panel
tf.BorderSizePixel  = 0
tf.Parent           = titleBar

local titleLabel = Theme.Label(titleBar, "🏆  Leaderboards", Theme.TextSize.Heading,
    Theme.Colors.Gold, Theme.Fonts.Heading, "TitleLabel")
titleLabel.Size             = UDim2.new(0.8, 0, 1, 0)
titleLabel.Position         = UDim2.new(0, 14, 0, 0)
titleLabel.TextXAlignment   = Enum.TextXAlignment.Left

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger,
    Color3.fromRGB(255, 255, 255), "CloseButton")
closeBtn.Size       = UDim2.new(0, 36, 0, 36)
closeBtn.Position   = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Category tab row
local tabRow = Instance.new("Frame")
tabRow.Name                 = "TabRow"
tabRow.Size                 = UDim2.new(1, -16, 0, 36)
tabRow.Position             = UDim2.new(0, 8, 0, 56)
tabRow.BackgroundTransparency = 1
tabRow.Parent               = container
Theme.AddListLayout(tabRow, Enum.FillDirection.Horizontal, 6)
Theme.AddPadding(tabRow, 0, 0, 0, 0)

local CATEGORIES = {
    { id = "ResourcesMined", label = "⛏ Resources" },
    { id = "GolemsCrafted",  label = "🗿 Golems"    },
    { id = "ForgeLevel",     label = "🔥 Forge"     },
    { id = "TradeCount",     label = "🔄 Trades"    },
    { id = "Ascensions",     label = "✦ Ascended"   },
}

local tabBtns      = {}
local activeCategory = "ResourcesMined"

for _, cat in ipairs(CATEGORIES) do
    local btn = Theme.Button(tabRow, cat.label,
        cat.id == activeCategory and Theme.Colors.Accent or Theme.Colors.PanelAlt,
        Color3.fromRGB(255, 255, 255), cat.id .. "Tab")
    btn.Size     = UDim2.new(1 / #CATEGORIES, -6, 0, 30)      -- the tabs share the row, however many there are
    btn.TextSize = 11
    tabBtns[cat.id] = btn
end

-- Leaderboard scroll
local scroll = Theme.ScrollFrame(container, "LeaderboardScroll")
scroll.Size                  = UDim2.new(1, -16, 0, 400)
scroll.Position              = UDim2.new(0, 8, 0, 100)
scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
scroll.Parent                = container

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding       = UDim.new(0, 4)
listLayout.Parent        = scroll
Theme.AddPadding(scroll, 4, 4, 4, 4)

-- Refresh button
local refreshBtn = Theme.Button(container, "↻  Refresh", Theme.Colors.Panel,
    Theme.Colors.TextSecondary, "RefreshButton")
refreshBtn.Size     = UDim2.new(0, 120, 0, 30)
refreshBtn.Position = UDim2.new(1, -128, 1, -38)
refreshBtn.TextSize = 12

-- Status label
local statusLabel = Theme.Label(container, "", Theme.TextSize.Small,
    Theme.Colors.TextDim, nil, "StatusLabel")
statusLabel.Size     = UDim2.new(0.6, 0, 0, 30)
statusLabel.Position = UDim2.new(0, 8, 1, -38)

-- ── Row builder ──────────────────────────────────────────────────────────────
local MEDAL_COLORS = {
    Color3.fromRGB(255, 215, 0),   -- gold
    Color3.fromRGB(192, 192, 192), -- silver
    Color3.fromRGB(205, 127, 50),  -- bronze
}

local function ClearList()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function AddRow(rank, displayName, value, isLocalPlayer)
    local row = Instance.new("Frame")
    row.Name              = "Row_" .. rank
    row.Size              = UDim2.new(1, -8, 0, 44)
    row.BackgroundColor3  = isLocalPlayer and Color3.fromRGB(40, 38, 28) or Theme.Colors.Panel
    row.BorderSizePixel   = 0
    row.Parent            = scroll
    Theme.AddCorner(row, Theme.Corner.Small)

    -- Rank badge
    local badge = Instance.new("Frame")
    badge.Size              = UDim2.new(0, 32, 0, 32)
    badge.Position          = UDim2.new(0, 6, 0.5, -16)
    badge.BackgroundColor3  = rank <= 3 and MEDAL_COLORS[rank] or Theme.Colors.PanelAlt
    badge.BorderSizePixel   = 0
    badge.Parent            = row
    Theme.AddCorner(badge, Theme.Corner.Small)

    local rankLbl = Theme.Label(badge, tostring(rank), 12,
        rank <= 3 and Color3.fromRGB(30, 20, 10) or Theme.Colors.TextSecondary,
        Theme.Fonts.Heading)
    rankLbl.Size = UDim2.new(1, 0, 1, 0)
    rankLbl.TextXAlignment = Enum.TextXAlignment.Center

    -- Player name
    local nameLbl = Theme.Label(row, displayName, Theme.TextSize.Body,
        isLocalPlayer and Theme.Colors.Gold or Theme.Colors.TextPrimary,
        isLocalPlayer and Theme.Fonts.Heading or Theme.Fonts.Body)
    nameLbl.Size     = UDim2.new(0.58, 0, 0, 22)
    nameLbl.Position = UDim2.new(0, 46, 0.5, -11)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Value
    local Utils  = require(game.ReplicatedStorage.Shared.Modules.Utils)
    local valLbl = Theme.Label(row, Utils.FormatNumber(value), Theme.TextSize.Body,
        Theme.Colors.Gold, Theme.Fonts.Mono)
    valLbl.Size     = UDim2.new(0.3, 0, 0, 22)
    valLbl.Position = UDim2.new(1, -8, 0.5, -11)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    -- Highlight stripe for local player
    if isLocalPlayer then
        Theme.Stripe(row, Theme.Colors.Gold)
    end
end

local function AddEmptyState(msg)
    local lbl = Theme.Label(scroll, msg, Theme.TextSize.Body, Theme.Colors.TextDim)
    lbl.Size              = UDim2.new(1, 0, 0, 50)
    lbl.TextXAlignment    = Enum.TextXAlignment.Center
end

-- ── Load and render ───────────────────────────────────────────────────────────
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

local isLoading = false

local function LoadCategory(category)
    if isLoading then return end
    isLoading = true
    statusLabel.Text = "Loading..."
    ClearList()

    task.spawn(function()
        local ok, entries = pcall(function()
            return RemoteEvents.GetLeaderboard:InvokeServer(category)
        end)

        isLoading = false

        if not ok or type(entries) ~= "table" then
            statusLabel.Text = "Failed to load."
            AddEmptyState("Could not fetch leaderboard data.")
            return
        end

        if #entries == 0 then
            statusLabel.Text = ""
            AddEmptyState("No data yet — be the first on the board!")
            return
        end

        statusLabel.Text = "Top " .. #entries .. " players"
        local myUserId   = tostring(LocalPlayer.UserId)

        for _, entry in ipairs(entries) do
            AddRow(entry.rank, entry.displayName, entry.value,
                tostring(entry.userId) == myUserId)
        end
    end)
end

-- Tab wiring
for _, cat in ipairs(CATEGORIES) do
    tabBtns[cat.id].MouseButton1Click:Connect(function()
        activeCategory = cat.id
        for _, c in ipairs(CATEGORIES) do
            tabBtns[c.id].BackgroundColor3 =
                c.id == cat.id and Theme.Colors.Accent or Theme.Colors.PanelAlt
        end
        LoadCategory(activeCategory)
    end)
end

refreshBtn.MouseButton1Click:Connect(function()
    LoadCategory(activeCategory)
end)

-- Auto-load when opened
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then
        LoadCategory(activeCategory)
    end
end)

-- Expose toggle for HUD nav button
local toggleFn = Instance.new("BindableFunction")
toggleFn.Name = "Toggle"
toggleFn.OnInvoke = function()
    gui.Enabled = not gui.Enabled
end
toggleFn.Parent = gui
