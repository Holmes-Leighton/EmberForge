-- HUD overlay shown when the local player is standing inside another player's forge zone.
-- Displays the forge owner's stats (read-only) and a "Request Trade" shortcut.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme       = require(game.ReplicatedStorage.Shared.Modules.Theme)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

local gui = Instance.new("ScreenGui")
gui.Name            = "ForgeVisitOverlay"
gui.ResetOnSpawn    = false
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Enabled         = false
gui.DisplayOrder    = 5    -- below modal dialogs, above world
gui.Parent          = LocalPlayer:WaitForChild("PlayerGui")

-- ── Panel (anchored to the right side of the screen) ─────────────────────────
local panel = Instance.new("Frame")
panel.Name              = "Panel"
panel.Size              = UDim2.new(0, 260, 0, 360)
panel.Position          = UDim2.new(1, -272, 0.5, -180)
panel.BackgroundColor3  = Theme.Colors.Background
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel   = 0
panel.Parent            = gui
Theme.AddCorner(panel, Theme.Corner.Large)

-- Top accent bar (ember colour)
local accent = Instance.new("Frame")
accent.Size             = UDim2.new(1, 0, 0, 4)
accent.BackgroundColor3 = Theme.Colors.Ember
accent.BorderSizePixel  = 0
accent.Parent           = panel
Theme.AddCorner(accent, Theme.Corner.Small)

-- Visiting label
local visitingLbl = Theme.Label(panel, "Visiting Forge", Theme.TextSize.Small,
    Theme.Colors.TextDim, Theme.Fonts.Body, "VisitingLabel")
visitingLbl.Size     = UDim2.new(1, -16, 0, 18)
visitingLbl.Position = UDim2.new(0, 8, 0, 10)

-- Owner name
local ownerLbl = Theme.Label(panel, "—", Theme.TextSize.Title,
    Theme.Colors.Gold, Theme.Fonts.Title, "OwnerLabel")
ownerLbl.Size     = UDim2.new(1, -16, 0, 32)
ownerLbl.Position = UDim2.new(0, 8, 0, 28)
ownerLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Divider
local div = Instance.new("Frame")
div.Size             = UDim2.new(1, -16, 0, 1)
div.Position         = UDim2.new(0, 8, 0, 68)
div.BackgroundColor3 = Theme.Colors.PanelAlt
div.BorderSizePixel  = 0
div.Parent           = panel

-- ── Stat rows ─────────────────────────────────────────────────────────────────
local function StatRow(labelText, valueName, yPos)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -16, 0, 26)
    row.Position         = UDim2.new(0, 8, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent           = panel

    local lbl = Theme.Label(row, labelText, Theme.TextSize.Body,
        Theme.Colors.TextSecondary, Theme.Fonts.Body)
    lbl.Size     = UDim2.new(0.6, 0, 1, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Theme.Label(row, "—", Theme.TextSize.Body,
        Theme.Colors.TextPrimary, Theme.Fonts.Heading, valueName)
    val.Size     = UDim2.new(0.4, 0, 1, 0)
    val.Position = UDim2.new(0.6, 0, 0, 0)
    val.TextXAlignment = Enum.TextXAlignment.Right

    return val
end

local forgeLvlVal  = StatRow("Forge Level",  "ForgeLevelVal",  76)
local playerLvlVal = StatRow("Player Level", "PlayerLevelVal", 106)
local golemCntVal  = StatRow("Golems",       "GolemCountVal",  136)

-- ── Golem element summary ─────────────────────────────────────────────────────
local elemHeader = Theme.Label(panel, "Deployed Elements", Theme.TextSize.Small,
    Theme.Colors.TextDim, Theme.Fonts.Heading)
elemHeader.Size     = UDim2.new(1, -16, 0, 18)
elemHeader.Position = UDim2.new(0, 8, 0, 170)

local elemScroll = Theme.ScrollFrame(panel, "ElemScroll")
elemScroll.Size                = UDim2.new(1, -16, 0, 100)
elemScroll.Position            = UDim2.new(0, 8, 0, 190)
elemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local elemLayout = Instance.new("UIListLayout")
elemLayout.FillDirection = Enum.FillDirection.Vertical
elemLayout.Padding       = UDim.new(0, 2)
elemLayout.Parent        = elemScroll

local ELEM_COLORS = {
    Ember = Theme.Colors.Ember,
    Stone = Color3.fromRGB(160, 130, 90),
    Frost = Theme.Colors.Frost,
    Storm = Theme.Colors.Storm,
    Void  = Theme.Colors.Void,
}

-- ── Action buttons ────────────────────────────────────────────────────────────
local tradeBtn = Theme.Button(panel, "⚖  Request Trade",
    Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "TradeButton")
tradeBtn.Size     = UDim2.new(1, -16, 0, 36)
tradeBtn.Position = UDim2.new(0, 8, 1, -96)
tradeBtn.TextSize = 13

local closeBtn = Theme.Button(panel, "X  Leave View",
    Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, "CloseButton")
closeBtn.Size     = UDim2.new(1, -16, 0, 30)
closeBtn.Position = UDim2.new(0, 8, 1, -52)
closeBtn.TextSize = 12
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- ── Populate ──────────────────────────────────────────────────────────────────
local currentOwnerId

local function ClearElems()
    for _, child in ipairs(elemScroll:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
    end
end

local function Show(ownerName, forgeData)
    ownerLbl.Text      = ownerName
    currentOwnerId     = forgeData and forgeData.userId

    if forgeData then
        forgeLvlVal.Text  = tostring(forgeData.forgeLevel  or "?")
        playerLvlVal.Text = tostring(forgeData.playerLevel or "?")
        golemCntVal.Text  = tostring(forgeData.golemCount  or "?")

        ClearElems()
        -- Tally deployed golems by element
        local counts = {}
        for _, g in ipairs(forgeData.golems or {}) do
            if g.deployed then
                counts[g.element] = (counts[g.element] or 0) + 1
            end
        end
        if next(counts) then
            for elem, cnt in pairs(counts) do
                local row = Theme.Label(elemScroll,
                    "  " .. elem .. "  ×" .. cnt,
                    Theme.TextSize.Small,
                    ELEM_COLORS[elem] or Theme.Colors.TextSecondary,
                    Theme.Fonts.Body)
                row.Size           = UDim2.new(1, 0, 0, 18)
                row.TextXAlignment = Enum.TextXAlignment.Left
            end
        else
            local none = Theme.Label(elemScroll, "  No deployed golems",
                Theme.TextSize.Small, Theme.Colors.TextDim)
            none.Size = UDim2.new(1, 0, 0, 18)
        end
    else
        forgeLvlVal.Text  = "?"
        playerLvlVal.Text = "?"
        golemCntVal.Text  = "?"
        ClearElems()
    end
end

-- Trade button: open trade with the forge owner
tradeBtn.MouseButton1Click:Connect(function()
    if not currentOwnerId then return end
    RemoteEvents.InitiateTrade:FireServer(currentOwnerId)
end)

-- ── Public API (called by ForgeZoneController) ────────────────────────────────
local showFn = Instance.new("BindableFunction")
showFn.Name = "Show"
showFn.OnInvoke = Show
showFn.Parent = gui
