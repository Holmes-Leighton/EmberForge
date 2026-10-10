-- "Welcome back": what the Golems mined while the player was away, with a button to bank it. Opened by the server's WelcomeBack event.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local Utils = require(game.ReplicatedStorage.Shared.Modules.Utils)
local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
RemoteEvents.Load()

local gui = Instance.new("ScreenGui")
gui.Name = "WelcomeBack"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 15
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1, 0, 1, 0)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.55
scrim.BorderSizePixel = 0
scrim.Parent = gui

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.new(0, 440, 0, 330)
ScaleUI.Apply(card, 440, 330)
card.BackgroundColor3 = Theme.Colors.Background
card.BorderSizePixel = 0
card.Parent = gui
Theme.AddCorner(card, Theme.Corner.Large)
Theme.AddStroke(card, Theme.Colors.Accent, 2, 0.3)

local title = Theme.Label(card, "Welcome back!", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
title.Position = UDim2.new(0, 22, 0, 16)
title.Size = UDim2.new(1, -44, 0, 34)

local away = Theme.Label(card, "", Theme.TextSize.Heading, Theme.Colors.TextSecondary, Theme.Fonts.Body, "Away")
away.Position = UDim2.new(0, 22, 0, 54)
away.Size = UDim2.new(1, -44, 0, 24)

local haulBox = Theme.Panel(card, "Haul", Theme.Colors.Panel)
haulBox.Position = UDim2.new(0, 22, 0, 88)
haulBox.Size = UDim2.new(1, -44, 0, 120)
local haulLabel = Theme.Label(haulBox, "", Theme.TextSize.Heading, Theme.Colors.TextPrimary, Theme.Fonts.Body, "HaulText")
haulLabel.Position = UDim2.new(0, 14, 0, 8)
haulLabel.Size = UDim2.new(1, -28, 1, -16)
haulLabel.TextYAlignment = Enum.TextYAlignment.Top
haulLabel.RichText = true

local note = Theme.Label(card, "", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, "Note")
note.Position = UDim2.new(0, 22, 0, 214)
note.Size = UDim2.new(1, -44, 0, 36)

local collect = Theme.Button(card, "⛏  Collect now", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "CollectNow")
collect.Size = UDim2.new(0, 220, 0, 44)
collect.Position = UDim2.new(0, 22, 1, -62)
collect.TextSize = 17
collect.MouseButton1Click:Connect(function()
    RemoteEvents.CollectResources:FireServer()
    gui.Enabled = false
end)

local later = Theme.Button(card, "Later", Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "Later")
later.Size = UDim2.new(0, 120, 0, 44)
later.Position = UDim2.new(1, -142, 1, -62)
later.TextSize = 15
later.MouseButton1Click:Connect(function() gui.Enabled = false end)

RemoteEvents.WelcomeBack.OnClientEvent:Connect(function(seconds, haul, capHours, capped)
    local lines, total = {}, 0
    local rows = {}
    for id, qty in pairs(haul or {}) do table.insert(rows, { id = id, qty = qty }) end
    table.sort(rows, function(a, b) return a.qty > b.qty end)
    for i, r in ipairs(rows) do
        total += r.qty
        if i <= 5 then
            local def = MaterialData.Get(r.id)
            table.insert(lines, string.format("<b>%s</b>  %s", Utils.FormatNumber(r.qty), def and def.displayName or r.id))
        end
    end
    if #rows > 5 then table.insert(lines, string.format("…and %d more kinds", #rows - 5)) end
    if total == 0 then return end
    away.Text = "You were away " .. Utils.FormatTime(seconds or 0)
    haulLabel.Text = table.concat(lines, "\n")
    note.Text = capped
        and string.format("Your storage holds %d hours, so mining stopped after that. A Storage Vault holds more.", math.floor(capHours or 0))
        or "Your Golems kept mining the whole time you were gone."
    gui.Enabled = true
end)
