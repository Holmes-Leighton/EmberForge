-- Creates the Inventory ScreenGui: materials list and Golem collection.
-- Named elements expected by InventoryController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryMenu"
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
scrim.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then gui.Enabled = false end
end)

-- ── Container (split: left = materials, right = golems) ───────────────────────
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 820, 0, 580)
container.Position = UDim2.new(0.5, -410, 0.5, -290)
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

local fillBot = Instance.new("Frame")
fillBot.Size = UDim2.new(1, 0, 0, 12)
fillBot.Position = UDim2.new(0, 0, 1, -12)
fillBot.BackgroundColor3 = Theme.Colors.Panel
fillBot.BorderSizePixel = 0
fillBot.Parent = titleBar

Theme.Label(titleBar, "🎒  Inventory", Theme.TextSize.Title,
    Theme.Colors.AccentBright, Theme.Fonts.Title).Size = UDim2.new(0.5, 0, 1, 0)
Theme.Label(titleBar, "Your Materials", Theme.TextSize.Heading,
    Theme.Colors.TextSecondary, Theme.Fonts.Heading, "MaterialsTitle").Size  = UDim2.new(0, 140, 0, 20)
local mt = titleBar:FindFirstChild("MaterialsTitle")
if mt then mt.Position = UDim2.new(0, 16, 0, 30); mt.Size = UDim2.new(0, 200, 0, 18) end

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- ── Left pane — Materials ─────────────────────────────────────────────────────
local leftPane = Instance.new("Frame")
leftPane.Name = "LeftPane"
leftPane.Size = UDim2.new(0.48, -4, 1, -58)
leftPane.Position = UDim2.new(0, 8, 0, 54)
leftPane.BackgroundTransparency = 1
leftPane.Parent = container

local matHeader = Instance.new("Frame")
matHeader.Size = UDim2.new(1, 0, 0, 30)
matHeader.BackgroundColor3 = Theme.Colors.Panel
matHeader.BorderSizePixel = 0
matHeader.Parent = leftPane
Theme.AddCorner(matHeader, Theme.Corner.Small)

Theme.Label(matHeader, "Materials", Theme.TextSize.Heading,
    Theme.Colors.AccentBright, Theme.Fonts.Heading).Size = UDim2.new(1, -8, 1, 0)
local mhl = leftPane:FindFirstChild("Label")
if mhl then mhl.Position = UDim2.new(0, 8, 0, 0) end

local materialScroll = Theme.ScrollFrame(leftPane, "MaterialScroll")
materialScroll.Size = UDim2.new(1, 0, 1, -36)
materialScroll.Position = UDim2.new(0, 0, 0, 34)

-- ── Right pane — Golems ───────────────────────────────────────────────────────
local rightPane = Instance.new("Frame")
rightPane.Name = "RightPane"
rightPane.Size = UDim2.new(0.52, -8, 1, -58)
rightPane.Position = UDim2.new(0.48, 4, 0, 54)
rightPane.BackgroundTransparency = 1
rightPane.Parent = container

local golemHeader = Instance.new("Frame")
golemHeader.Size = UDim2.new(1, 0, 0, 30)
golemHeader.BackgroundColor3 = Theme.Colors.Panel
golemHeader.BorderSizePixel = 0
golemHeader.Parent = rightPane
Theme.AddCorner(golemHeader, Theme.Corner.Small)

Theme.Label(golemHeader, "Golems", Theme.TextSize.Heading,
    Theme.Colors.AccentBright, Theme.Fonts.Heading).Size = UDim2.new(1, -8, 1, 0)

local golemScroll = Theme.ScrollFrame(rightPane, "GolemScroll")
golemScroll.Size = UDim2.new(1, 0, 1, -36)
golemScroll.Position = UDim2.new(0, 0, 0, 34)

-- ── Vertical divider ──────────────────────────────────────────────────────────
local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 1, 1, -60)
divider.Position = UDim2.new(0.48, 0, 0, 58)
divider.BackgroundColor3 = Theme.Colors.PanelAlt
divider.BorderSizePixel = 0
divider.Parent = container
