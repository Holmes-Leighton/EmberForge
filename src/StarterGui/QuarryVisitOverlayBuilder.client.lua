-- Shown while you stand in another player's Quarry: whose it is, its Core level and what it is made of (read-only). The server sends a
-- summary when you walk in and nil when you leave (see ForgeZoneService.QuarrySummary); a Quarry that is private or not founded sends nothing.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

RemoteEvents.Load()

local gui = Instance.new("ScreenGui")
gui.Name = "QuarryVisitOverlay"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 250, 0, 214)
panel.Position = UDim2.new(1, -262, 0.5, -107)
panel.BorderSizePixel = 0
panel.Parent = gui
Theme.StyleWindow(panel, "Blue")
ScaleUI.ApplyHud(panel)


local visiting = Theme.Label(panel, "Visiting Quarry", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, "VisitingLabel")
visiting.Position, visiting.Size = UDim2.new(0, 10, 0, 6), UDim2.new(1, -20, 0, 20)

local owner = Theme.Label(panel, "", Theme.TextSize.Heading, Theme.Colors.Gold, Theme.Fonts.Title, "OwnerLabel")
owner.Position, owner.Size = UDim2.new(0, 10, 0, 26), UDim2.new(1, -20, 0, 26)

local core = Theme.Label(panel, "", Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Body, "CoreLabel")
core.Position, core.Size = UDim2.new(0, 10, 0, 56), UDim2.new(1, -20, 0, 18)

local body = Theme.Label(panel, "", Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body, "BodyLabel")
body.Position, body.Size = UDim2.new(0, 10, 0, 80), UDim2.new(1, -20, 0, 124)
body.TextYAlignment = Enum.TextYAlignment.Top

local ORDER = { "Ember", "Frost", "Storm", "Stone", "Void" }

RemoteEvents.QuarryVisit.OnClientEvent:Connect(function(summary)
    if type(summary) ~= "table" then
        gui.Enabled = false
        return
    end
    owner.Text = tostring(summary.name) .. "'s Quarry"
    core.Text = string.format("Core Level %d of %d   -   %d / %s nodes", summary.level, summary.maxLevel or summary.level, summary.nodes, tostring(summary.maxNodes or "?"))
    local lines = {}
    for _, element in ipairs(ORDER) do
        local n = summary.byElement and summary.byElement[element]
        if n and n > 0 then table.insert(lines, string.format("%s nodes: %d", element, n)) end
    end
    table.insert(lines, string.format("Helper buildings: %d", summary.helpers or 0))
    table.insert(lines, string.format("Golem crew: %d", summary.crew or 0))
    body.Text = table.concat(lines, "\n")
    gui.Enabled = true
end)
