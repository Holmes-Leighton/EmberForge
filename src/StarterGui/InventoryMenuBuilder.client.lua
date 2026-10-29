-- Creates the Inventory ScreenGui: materials list and Golem collection.
-- Named elements expected by InventoryController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)

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
ScaleUI.Apply(container, 820, 580)
container.BorderSizePixel = 0
container.Parent = gui
Theme.WindowHeader(container, gui, "Inventory", "Purple")

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
Theme.AddPadding(matHeader, 0, 0, 0, 10)

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
Theme.AddPadding(golemHeader, 0, 0, 0, 10)

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
