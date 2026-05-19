-- Creates the Forge Market ScreenGui: browse and list items for sale.
-- Named elements expected by TradingController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

local gui = Instance.new("ScreenGui")
gui.Name = "MarketMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1, 0, 1, 0)
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
container.Size = UDim2.new(0, 780, 0, 580)
container.Position = UDim2.new(0.5, -390, 0.5, -290)
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

local tfill = Instance.new("Frame")
tfill.Size = UDim2.new(1,0,0,12); tfill.Position = UDim2.new(0,0,1,-12)
tfill.BackgroundColor3 = Theme.Colors.Panel; tfill.BorderSizePixel = 0
tfill.Parent = titleBar

Theme.Label(titleBar, "🏪  Forge Market", Theme.TextSize.Title,
    Theme.Colors.Gold, Theme.Fonts.Title).Size = UDim2.new(0.5, 0, 1, 0)

local closeBtn = Theme.Button(titleBar, "✕", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- ── Filter / action bar ───────────────────────────────────────────────────────
local filterBar = Instance.new("Frame")
filterBar.Name = "FilterBar"
filterBar.Size = UDim2.new(1, -16, 0, 44)
filterBar.Position = UDim2.new(0, 8, 0, 56)
filterBar.BackgroundColor3 = Theme.Colors.Panel
filterBar.BorderSizePixel = 0
filterBar.Parent = container
Theme.AddCorner(filterBar, Theme.Corner.Small)
Theme.AddPadding(filterBar, 6, 6, 6, 6)

local filterLayout = Instance.new("UIListLayout")
filterLayout.FillDirection = Enum.FillDirection.Horizontal
filterLayout.Padding = UDim.new(0, 6)
filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
filterLayout.Parent = filterBar

local materialsTab = Theme.Button(filterBar, "Materials", Theme.Colors.Accent,
    Color3.fromRGB(255,255,255), "MaterialsTab")
materialsTab.Size = UDim2.new(0, 100, 0, 30)

local golemsTab = Theme.Button(filterBar, "Golems", Theme.Colors.PanelAlt,
    Theme.Colors.TextSecondary, "GolemsTab")
golemsTab.Size = UDim2.new(0, 100, 0, 30)

local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, -390, 1, 0)
spacer.BackgroundTransparency = 1
spacer.BorderSizePixel = 0
spacer.Parent = filterBar

local refreshBtn = Theme.Button(filterBar, "↻  Refresh", Theme.Colors.PanelAlt,
    Theme.Colors.TextPrimary, "RefreshButton")
refreshBtn.Size = UDim2.new(0, 100, 0, 30)

local listItemBtn = Theme.Button(filterBar, "+  List Item", Theme.Colors.Success,
    Color3.fromRGB(255,255,255), "ListItemButton")
listItemBtn.Size = UDim2.new(0, 110, 0, 30)

-- ── Column headers ────────────────────────────────────────────────────────────
local colHeader = Instance.new("Frame")
colHeader.Size = UDim2.new(1, -16, 0, 28)
colHeader.Position = UDim2.new(0, 8, 0, 106)
colHeader.BackgroundTransparency = 1
colHeader.Parent = container

local function colLabel(text, xScale, xOff, align)
    local l = Theme.Label(colHeader, text, Theme.TextSize.Small,
        Theme.Colors.TextDim, Theme.Fonts.Heading)
    l.Size = UDim2.new(xScale, 0, 1, 0)
    l.Position = UDim2.new(0, xOff, 0, 0)
    l.TextXAlignment = align or Enum.TextXAlignment.Left
end
colLabel("Item",       0.40, 8)
colLabel("Seller",     0.20, 0 + 8 + 312)
colLabel("Price",      0.15, 0)
colLabel("",           0.12, 0)

-- ── Listing scroll ────────────────────────────────────────────────────────────
local listingScroll = Theme.ScrollFrame(container, "ListingScroll")
listingScroll.Size = UDim2.new(1, -16, 1, -144)
listingScroll.Position = UDim2.new(0, 8, 0, 136)

-- Empty state
local emptyLbl = Theme.Label(listingScroll, "No listings found. Try refreshing or change the filter.",
    Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, "EmptyLabel")
emptyLbl.Size = UDim2.new(1, 0, 0, 40)
emptyLbl.Position = UDim2.new(0, 0, 0, 20)
emptyLbl.TextXAlignment = Enum.TextXAlignment.Center

-- ── Tab switching ─────────────────────────────────────────────────────────────
materialsTab.MouseButton1Click:Connect(function()
    materialsTab.BackgroundColor3 = Theme.Colors.Accent
    materialsTab.TextColor3 = Color3.fromRGB(255,255,255)
    golemsTab.BackgroundColor3 = Theme.Colors.PanelAlt
    golemsTab.TextColor3 = Theme.Colors.TextSecondary
end)
golemsTab.MouseButton1Click:Connect(function()
    golemsTab.BackgroundColor3 = Theme.Colors.Accent
    golemsTab.TextColor3 = Color3.fromRGB(255,255,255)
    materialsTab.BackgroundColor3 = Theme.Colors.PanelAlt
    materialsTab.TextColor3 = Theme.Colors.TextSecondary
end)
