-- Creates the Trade ScreenGui: direct player-to-player trade offer interface.
-- Named elements expected by TradingController.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

local gui = Instance.new("ScreenGui")
gui.Name = "TradeMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ── Scrim ─────────────────────────────────────────────────────────────────────
local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1, 0, 1, 0)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.5
scrim.BorderSizePixel = 0
scrim.Parent = gui

-- ── Container ─────────────────────────────────────────────────────────────────
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 700, 0, 520)
container.Position = UDim2.new(0.5, -350, 0.5, -260)
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
tfill.Size = UDim2.new(1, 0, 0, 12); tfill.Position = UDim2.new(0,0,1,-12)
tfill.BackgroundColor3 = Theme.Colors.Panel; tfill.BorderSizePixel = 0
tfill.Parent = titleBar

local tradeHeader = Theme.Label(titleBar, "⚖  Trade Request", Theme.TextSize.Title,
    Theme.Colors.Gold, Theme.Fonts.Title, "TradeHeader")
tradeHeader.Size = UDim2.new(0.8, 0, 1, 0)
tradeHeader.Position = UDim2.new(0, 16, 0, 0)
tradeHeader.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Theme.Button(titleBar, "✕", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- ── Two-column offer area ─────────────────────────────────────────────────────
local function makeOfferPane(name, title, xPos)
    local pane = Instance.new("Frame")
    pane.Name = name
    pane.Size = UDim2.new(0, 310, 0, 360)
    pane.Position = UDim2.new(0, xPos, 0, 60)
    pane.BackgroundColor3 = Theme.Colors.Panel
    pane.BorderSizePixel = 0
    pane.Parent = container
    Theme.AddCorner(pane, Theme.Corner.Medium)

    local hdr = Theme.Label(pane, title, Theme.TextSize.Heading,
        Theme.Colors.AccentBright, Theme.Fonts.Heading)
    hdr.Size = UDim2.new(1, -12, 0, 28)
    hdr.Position = UDim2.new(0, 10, 0, 6)

    local scroll = Theme.ScrollFrame(pane, name .. "Scroll")
    scroll.Size = UDim2.new(1, -10, 1, -44)
    scroll.Position = UDim2.new(0, 5, 0, 38)

    local emptyLbl = Theme.Label(scroll, "No items offered yet.", Theme.TextSize.Small,
        Theme.Colors.TextDim, Theme.Fonts.Body, "EmptyLabel")
    emptyLbl.Size = UDim2.new(1, 0, 0, 30)
    emptyLbl.Position = UDim2.new(0, 0, 0, 8)
    emptyLbl.TextXAlignment = Enum.TextXAlignment.Center

    return pane
end

makeOfferPane("YourOffer",  "Your Offer",   10)
makeOfferPane("TheirOffer", "Their Offer", 380)

-- Arrow between panes
local arrow = Theme.Label(container, "⇄", 28, Theme.Colors.Gold, Theme.Fonts.Heading, "Arrow")
arrow.Size = UDim2.new(0, 50, 0, 50)
arrow.Position = UDim2.new(0.5, -25, 0, 195)
arrow.TextXAlignment = Enum.TextXAlignment.Center

-- ── Confirmation info ─────────────────────────────────────────────────────────
local confirmInfo = Instance.new("Frame")
confirmInfo.Size = UDim2.new(1, -16, 0, 42)
confirmInfo.Position = UDim2.new(0, 8, 0, 428)
confirmInfo.BackgroundColor3 = Theme.Colors.PanelAlt
confirmInfo.BorderSizePixel = 0
confirmInfo.Parent = container
Theme.AddCorner(confirmInfo, Theme.Corner.Small)

local confirmLbl = Theme.Label(confirmInfo,
    "Both players must confirm. Review all items carefully before accepting.",
    Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body, "ConfirmLabel")
confirmLbl.Size = UDim2.new(1, -8, 1, 0)
confirmLbl.Position = UDim2.new(0, 8, 0, 0)
confirmLbl.TextXAlignment = Enum.TextXAlignment.Center

-- ── Action buttons ────────────────────────────────────────────────────────────
local btnRow = Instance.new("Frame")
btnRow.Name = "ButtonRow"
btnRow.Size = UDim2.new(1, -16, 0, 44)
btnRow.Position = UDim2.new(0, 8, 1, -52)
btnRow.BackgroundTransparency = 1
btnRow.Parent = container

local acceptBtn = Theme.Button(btnRow, "✓  Accept Trade", Theme.Colors.Success,
    Color3.fromRGB(255,255,255), "AcceptButton")
acceptBtn.Size = UDim2.new(0.48, 0, 1, 0)
acceptBtn.Position = UDim2.new(0, 0, 0, 0)
acceptBtn.TextSize = 15

local declineBtn = Theme.Button(btnRow, "✗  Decline", Theme.Colors.Danger,
    Color3.fromRGB(255,255,255), "DeclineButton")
declineBtn.Size = UDim2.new(0.48, 0, 1, 0)
declineBtn.Position = UDim2.new(0.52, 0, 0, 0)
declineBtn.TextSize = 15

-- Confirmation state labels (updated by TradingController)
local yourConfirm = Theme.Label(container, "Waiting...", Theme.TextSize.Small,
    Theme.Colors.TextDim, Theme.Fonts.Body, "YourConfirmLabel")
yourConfirm.Size = UDim2.new(0, 140, 0, 16)
yourConfirm.Position = UDim2.new(0, 10, 0, 418)

local theirConfirm = Theme.Label(container, "Waiting...", Theme.TextSize.Small,
    Theme.Colors.TextDim, Theme.Fonts.Body, "TheirConfirmLabel")
theirConfirm.Size = UDim2.new(0, 140, 0, 16)
theirConfirm.Position = UDim2.new(0, 380, 0, 418)
