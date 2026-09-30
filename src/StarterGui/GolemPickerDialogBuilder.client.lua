-- Modal for selecting a Golem — used for Deploy, Fuse, and Recall operations.
-- Caller specifies mode ("deploy", "fuse", "recall") and receives the chosen golem id.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)

local gui = Instance.new("ScreenGui")
gui.Name = "GolemPickerDialog"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.DisplayOrder = 20
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Scrim
local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1,0,1,0)
scrim.BackgroundColor3 = Color3.fromRGB(0,0,0)
scrim.BackgroundTransparency = 0.55
scrim.BorderSizePixel = 0
scrim.Parent = gui

-- Container
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 560, 0, 520)
ScaleUI.Apply(container, 560, 520)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel = 0
container.Parent = gui
Theme.AddCorner(container, Theme.Corner.Large)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tf=Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,12); tf.Position=UDim2.new(0,0,1,-12)
tf.BackgroundColor3=Theme.Colors.Panel; tf.BorderSizePixel=0; tf.Parent=titleBar

local titleLabel = Theme.Label(titleBar, "🗿  Select a Golem", Theme.TextSize.Heading,
    Theme.Colors.AccentBright, Theme.Fonts.Heading, "TitleLabel")
titleLabel.Size = UDim2.new(0.85, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Filter row
local filterRow = Instance.new("Frame")
filterRow.Size = UDim2.new(1, -16, 0, 36)
filterRow.Position = UDim2.new(0, 8, 0, 56)
filterRow.BackgroundTransparency = 1
filterRow.Parent = container
Theme.AddPadding(filterRow, 3, 3, 3, 0)
Theme.AddListLayout(filterRow, Enum.FillDirection.Horizontal, 6)

local elementFilters = { "All", "Ember", "Stone", "Frost", "Storm", "Void" }
local activeFilter = "All"
local filterBtns = {}

for _, elem in ipairs(elementFilters) do
    local elemColor = elem == "All" and Theme.Colors.TextSecondary
        or Theme.Colors[elem] or Theme.Colors.TextSecondary

    local fb = Theme.Button(filterRow, elem,
        elem == "All" and Theme.Colors.Accent or Theme.Colors.PanelAlt,
        elem == "All" and Color3.fromRGB(255,255,255) or elemColor, elem .. "Filter")
    fb.Size = UDim2.new(0, 72, 0, 28)
    fb.TextSize = 11
    filterBtns[elem] = fb
end

-- Golem list scroll
local scroll = Theme.ScrollFrame(container, "GolemScroll")
scroll.Size = UDim2.new(1, -16, 0, 360)
scroll.Position = UDim2.new(0, 8, 0, 98)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = scroll
Theme.AddPadding(scroll, 4, 4, 4, 4)

local ELEMENT_COLORS = {
    Ember=Theme.Colors.Ember, Stone=Theme.Colors.Stone,
    Frost=Theme.Colors.Frost, Storm=Theme.Colors.Storm, Void=Theme.Colors.Void,
}

-- State
local selectedGolemId = nil
local currentMode     = "deploy"
local currentCallback = nil   -- BindableEvent to fire on confirm
local allGolems       = {}

local function deselectAll()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then
            child.BackgroundColor3 = Theme.Colors.Panel
            local sb = child:FindFirstChild("SelectBtn")
            if sb then
                sb.BackgroundColor3 = Theme.Colors.PanelAlt
                sb.TextColor3 = Theme.Colors.TextPrimary
                sb.Text = "Select"
            end
        end
    end
    selectedGolemId = nil
end

local function RenderGolems(golems, mode)
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    selectedGolemId = nil

    local GolemData = require(game.ReplicatedStorage.Shared.Data.GolemData)
    local Utils     = require(game.ReplicatedStorage.Shared.Modules.Utils)

    local shown = 0
    for _, golem in ipairs(golems) do
        if activeFilter ~= "All" and golem.element ~= activeFilter then continue end
        if mode == "deploy"  and golem.deployed then continue end
        if mode == "recall"  and not golem.deployed then continue end
        if mode == "fuse"    and golem.deployed then continue end

        shown = shown + 1
        local elemColor = ELEMENT_COLORS[golem.element] or Theme.Colors.TextSecondary
        local tierDef   = GolemData.Tiers[golem.tier]
        local stats     = GolemData.ComputeStats(golem.element, golem.tier, golem.fusionBonus, golem.quality, golem.variant)

        local card = Instance.new("Frame")
        card.Name = golem.id
        card.Size = UDim2.new(1, -8, 0, 80)
        card.BackgroundColor3 = Theme.Colors.Panel
        card.BorderSizePixel = 0
        card.Parent = scroll
        Theme.AddCorner(card, Theme.Corner.Small)

        Theme.Stripe(card, elemColor)

        -- Tier badge
        local tierBadge = Instance.new("Frame")
        tierBadge.Size = UDim2.new(0, 28, 0, 28)
        tierBadge.Position = UDim2.new(0, 10, 0.5, -14)
        tierBadge.BackgroundColor3 = elemColor
        tierBadge.BorderSizePixel = 0
        tierBadge.Parent = card
        Theme.AddCorner(tierBadge, Theme.Corner.Small)
        local tierLbl = Theme.Label(tierBadge, "T" .. golem.tier, 12, Color3.fromRGB(255,255,255), Theme.Fonts.Heading)
        tierLbl.Size = UDim2.new(1, 0, 1, 0)
        tierLbl.TextXAlignment = Enum.TextXAlignment.Center

        -- Name + element
        local nameLbl = Theme.Label(card,
            (tierDef and tierDef.name or "Golem") .. " — " .. golem.element,
            Theme.TextSize.Heading, elemColor, Theme.Fonts.Heading)
        nameLbl.Size = UDim2.new(0.55, 0, 0, 22)
        nameLbl.Position = UDim2.new(0, 48, 0, 6)

        -- Status
        local statusText = golem.deployed and ("⚡ Mining: " .. (golem.zoneId or "?")) or "● Idle"
        local statusColor = golem.deployed and Theme.Colors.Success or Theme.Colors.TextDim
        local statusLbl = Theme.Label(card, statusText, Theme.TextSize.Small, statusColor)
        statusLbl.Size = UDim2.new(0.5, 0, 0, 16)
        statusLbl.Position = UDim2.new(0, 48, 0, 28)

        -- Stats
        if stats then
            local statsLbl = Theme.Label(card,
                string.format("⛏ %s/hr  📦 %s  🎲 %.0f%%",
                    Utils.FormatNumber(stats.miningRate),
                    Utils.FormatNumber(stats.carryCapacity),
                    stats.luck * 100),
                Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Mono)
            statsLbl.Size = UDim2.new(0.55, 0, 0, 16)
            statsLbl.Position = UDim2.new(0, 48, 0, 48)
        end

        -- Fusion bonus indicator
        if golem.fusionBonus then
            local fusedLbl = Theme.Label(card, "✦ Fused", Theme.TextSize.Small, Theme.Colors.Legendary)
            fusedLbl.Size = UDim2.new(0, 60, 0, 16)
            fusedLbl.Position = UDim2.new(0, 48, 0, 60)
        end

        -- Select button
        local selBtn = Theme.Button(card, "Select", Theme.Colors.PanelAlt,
            Theme.Colors.TextPrimary, "SelectBtn")
        selBtn.Size = UDim2.new(0, 86, 0, 34)
        selBtn.Position = UDim2.new(1, -94, 0.5, -17)
        selBtn.TextSize = 13

        selBtn.MouseButton1Click:Connect(function()
            deselectAll()
            selectedGolemId = golem.id
            card.BackgroundColor3 = Color3.fromRGB(45, 38, 28)
            selBtn.BackgroundColor3 = Theme.Colors.Accent
            selBtn.TextColor3 = Color3.fromRGB(255,255,255)
            selBtn.Text = "OK"
        end)
    end

    if shown == 0 then
        local emptyLbl = Theme.Label(scroll, "No eligible Golems for this action.",
            Theme.TextSize.Body, Theme.Colors.TextDim)
        emptyLbl.Size = UDim2.new(1, 0, 0, 40)
        emptyLbl.TextXAlignment = Enum.TextXAlignment.Center
    end
end

-- Filter button wiring
for elem, fb in pairs(filterBtns) do
    fb.MouseButton1Click:Connect(function()
        activeFilter = elem
        for e, b in pairs(filterBtns) do
            local isActive = e == elem
            b.BackgroundColor3 = isActive and Theme.Colors.Accent or Theme.Colors.PanelAlt
            local ec = e == "All" and Color3.fromRGB(255,255,255) or (ELEMENT_COLORS[e] or Theme.Colors.TextSecondary)
            b.TextColor3 = isActive and Color3.fromRGB(255,255,255) or ec
        end
        RenderGolems(allGolems, currentMode)
    end)
end

-- ── Confirm button ─────────────────────────────────────────────────────────────
local confirmBtn = Theme.Button(container, "Confirm Selection", Theme.Colors.Accent,
    Color3.fromRGB(255,255,255), "ConfirmButton")
confirmBtn.Size = UDim2.new(1, -16, 0, 42)
confirmBtn.Position = UDim2.new(0, 8, 1, -50)
confirmBtn.TextSize = 15

confirmBtn.MouseButton1Click:Connect(function()
    if not selectedGolemId then return end
    gui.Enabled = false
    if currentCallback then
        currentCallback:Fire(selectedGolemId)
    end
end)

-- ── Public API ─────────────────────────────────────────────────────────────────
-- Open(golems, mode, callbackEvent)
--   mode: "deploy" | "fuse" | "recall"
--   callbackEvent: BindableEvent — fired with (golemId) on confirm
local openFn = Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.OnInvoke = function(golems, mode, callbackEvent)
    allGolems = golems or {}
    currentMode = mode or "deploy"
    currentCallback = callbackEvent

    local modeLabels = {
        deploy = "🗿  Select Golem to Deploy",
        fuse   = "🔥  Select Golem to Fuse",
        recall = "↩  Select Golem to Recall",
    }
    titleLabel.Text = modeLabels[currentMode] or "Select a Golem"
    confirmBtn.Text = currentMode == "fuse" and "Fuse Golems" or "Confirm"

    activeFilter = "All"
    for elem, fb in pairs(filterBtns) do
        fb.BackgroundColor3 = elem == "All" and Theme.Colors.Accent or Theme.Colors.PanelAlt
        fb.TextColor3 = elem == "All" and Color3.fromRGB(255,255,255)
            or (ELEMENT_COLORS[elem] or Theme.Colors.TextSecondary)
    end

    RenderGolems(allGolems, currentMode)
    gui.Enabled = true
end
openFn.Parent = gui
