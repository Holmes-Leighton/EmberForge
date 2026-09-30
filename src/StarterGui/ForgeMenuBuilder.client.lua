-- Creates the Forge ScreenGui: blueprint list, smelt queue, and deploy panel.
-- Named elements expected by ForgeController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

local gui = Instance.new("ScreenGui")
gui.Name = "ForgeMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ── Background scrim ──────────────────────────────────────────────────────────
local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1, 0, 1, 0)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.45
scrim.BorderSizePixel = 0
scrim.Parent = gui

scrim.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        gui.Enabled = false
    end
end)

-- ── Main container ────────────────────────────────────────────────────────────
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 860, 0, 600)
container.Position = UDim2.new(0.5, -430, 0.5, -300)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel = 0
container.Parent = gui
Theme.AddCorner(container, Theme.Corner.Large)

-- ── Title bar ─────────────────────────────────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = container
Theme.AddCorner(titleBar, Theme.Corner.Large)

-- bottom fill to square off title bar bottom corners
local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0, 12)
titleFill.Position = UDim2.new(0, 0, 1, -12)
titleFill.BackgroundColor3 = Theme.Colors.Panel
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local titleLbl = Theme.Label(titleBar, "🔥  Forge", Theme.TextSize.Title, Theme.Colors.Ember, Theme.Fonts.Title, "TitleLabel")
titleLbl.Size = UDim2.new(0, 220, 1, 0)
titleLbl.Position = UDim2.new(0, 16, 0, 0)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- ── Tab bar ───────────────────────────────────────────────────────────────────
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, 0, 0, 38)
tabBar.Position = UDim2.new(0, 0, 0, 50)
tabBar.BackgroundColor3 = Theme.Colors.Panel
tabBar.BorderSizePixel = 0
tabBar.Parent = container

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 2)
tabLayout.Parent = tabBar
Theme.AddPadding(tabBar, 4, 4, 4, 8)

local tabs = { "Blueprints", "Smelt Queue", "Deploy" }
local tabBtns = {}
local panels = {}

for _, tabName in ipairs(tabs) do
    local tb = Theme.Button(tabBar, tabName, Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, tabName .. "Tab")
    tb.Size = UDim2.new(0, 130, 0, 30)
    tb.TextSize = 13
    tabBtns[tabName] = tb
end

-- ── Content area ─────────────────────────────────────────────────────────────
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, 0, 1, -88)
contentArea.Position = UDim2.new(0, 0, 0, 88)
contentArea.BackgroundTransparency = 1
contentArea.Parent = container

-- ── Blueprints Panel ──────────────────────────────────────────────────────────
local blueprintPanel = Theme.Panel(contentArea, "BlueprintPanel", Theme.Colors.Background)
blueprintPanel.Size = UDim2.new(1, 0, 1, 0)
blueprintPanel.BackgroundTransparency = 1

-- Fuse button (top-right of blueprint panel)
local fuseBtn = Theme.Button(blueprintPanel, "🔥 Fuse Golems", Theme.Colors.PanelAlt,
    Theme.Colors.Ember, "FuseGolemsButton")
fuseBtn.Size     = UDim2.new(0, 130, 0, 30)
fuseBtn.Position = UDim2.new(1, -138, 0, 4)
fuseBtn.TextSize = 12

local bpScroll = Theme.ScrollFrame(blueprintPanel, "BlueprintScroll")
bpScroll.Size = UDim2.new(1, -16, 1, -44)
bpScroll.Position = UDim2.new(0, 8, 0, 40)
panels["Blueprints"] = blueprintPanel

-- ── Smelt Queue Panel ─────────────────────────────────────────────────────────
local smeltPanel = Theme.Panel(contentArea, "SmeltPanel", Theme.Colors.Background)
smeltPanel.Size = UDim2.new(1, 0, 1, 0)
smeltPanel.BackgroundTransparency = 1
smeltPanel.Visible = false

-- Smelt input row
local smeltInputRow = Instance.new("Frame")
smeltInputRow.Name = "SmeltInputRow"
smeltInputRow.Size = UDim2.new(1, -16, 0, 50)
smeltInputRow.Position = UDim2.new(0, 8, 0, 8)
smeltInputRow.BackgroundColor3 = Theme.Colors.Panel
smeltInputRow.BorderSizePixel = 0
smeltInputRow.Parent = smeltPanel
Theme.AddCorner(smeltInputRow, Theme.Corner.Small)

local smeltHint = Theme.Label(smeltInputRow, "Select a raw material from Inventory to smelt →",
    Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, "SmeltHintLabel")
smeltHint.Size = UDim2.new(0.7, 0, 1, 0)
smeltHint.Position = UDim2.new(0, 10, 0, 0)
smeltHint.TextXAlignment = Enum.TextXAlignment.Left

local smeltButton = Theme.Button(smeltInputRow, "⚗  Smelt", Theme.Colors.Accent, Color3.fromRGB(255,255,255), "SmeltButton")
smeltButton.Size = UDim2.new(0, 110, 0, 34)
smeltButton.Position = UDim2.new(1, -118, 0, 8)

-- Queue display
local smeltQueueLabel = Theme.Label(smeltPanel, "Active Queue", Theme.TextSize.Heading,
    Theme.Colors.TextSecondary, Theme.Fonts.Heading)
smeltQueueLabel.Size = UDim2.new(1, -16, 0, 24)
smeltQueueLabel.Position = UDim2.new(0, 8, 0, 66)

local smeltQueueScroll = Theme.ScrollFrame(smeltPanel, "SmeltQueueScroll")
smeltQueueScroll.Size = UDim2.new(1, -16, 1, -100)
smeltQueueScroll.Position = UDim2.new(0, 8, 0, 94)
panels["Smelt Queue"] = smeltPanel

-- ── Deploy Panel ──────────────────────────────────────────────────────────────
local deployPanelFrame = Theme.Panel(contentArea, "DeployPanel", Theme.Colors.Background)
deployPanelFrame.Size = UDim2.new(1, 0, 1, 0)
deployPanelFrame.BackgroundTransparency = 1
deployPanelFrame.Visible = false

local deployZoneLabel = Theme.Label(deployPanelFrame, "Mining Zones", Theme.TextSize.Heading,
    Theme.Colors.TextSecondary, Theme.Fonts.Heading)
deployZoneLabel.Size = UDim2.new(1, -16, 0, 28)
deployZoneLabel.Position = UDim2.new(0, 8, 0, 8)

-- Zone strip (horizontal scroll)
local zoneStrip = Instance.new("ScrollingFrame")
zoneStrip.Name = "ZoneStrip"
zoneStrip.Size = UDim2.new(1, -16, 0, 80)
zoneStrip.Position = UDim2.new(0, 8, 0, 40)
zoneStrip.BackgroundTransparency = 1
zoneStrip.BorderSizePixel = 0
zoneStrip.ScrollBarThickness = 4
zoneStrip.ScrollBarImageColor3 = Theme.Colors.Accent
zoneStrip.ScrollingDirection = Enum.ScrollingDirection.X
zoneStrip.CanvasSize = UDim2.new(0, 0, 1, 0)
zoneStrip.AutomaticCanvasSize = Enum.AutomaticSize.X
zoneStrip.Parent = deployPanelFrame

Theme.AddListLayout(zoneStrip, Enum.FillDirection.Horizontal, 8)

local golemListLabel = Theme.Label(deployPanelFrame, "Your Golems", Theme.TextSize.Heading,
    Theme.Colors.TextSecondary, Theme.Fonts.Heading)
golemListLabel.Size = UDim2.new(1, -16, 0, 28)
golemListLabel.Position = UDim2.new(0, 8, 0, 128)

local golemDeployScroll = Theme.ScrollFrame(deployPanelFrame, "GolemDeployScroll")
golemDeployScroll.Size = UDim2.new(1, -16, 1, -166)
golemDeployScroll.Position = UDim2.new(0, 8, 0, 158)
panels["Deploy"] = deployPanelFrame

-- ── Tab switching logic ────────────────────────────────────────────────────────
local function switchTab(selected)
    for name, btn in pairs(tabBtns) do
        local isSelected = name == selected
        btn.BackgroundColor3 = isSelected and Theme.Colors.Accent or Theme.Colors.PanelAlt
        btn.TextColor3       = isSelected and Color3.fromRGB(255,255,255) or Theme.Colors.TextSecondary
    end
    for name, panel in pairs(panels) do
        panel.Visible = name == selected
    end
end

for name, btn in pairs(tabBtns) do
    btn.MouseButton1Click:Connect(function() switchTab(name) end)
end

switchTab("Blueprints")  -- default
