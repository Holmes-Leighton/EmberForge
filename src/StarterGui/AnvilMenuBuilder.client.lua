-- Golem Anvil menu: pick a Golem from the list, see its preview, stats and required
-- components, then forge one (or as many as you can afford).
-- Opens when the player uses the Golem Anvil's proximity prompt.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LocalPlayer = Players.LocalPlayer

local Theme          = require(game.ReplicatedStorage.Shared.Modules.Theme)
local RemoteEvents   = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local GolemModel     = require(game.ReplicatedStorage.Shared.Modules.GolemModel)
local ScaleUI        = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local MaterialIcon   = require(game.ReplicatedStorage.Shared.Modules.MaterialIcon)
local Portrait       = require(game.ReplicatedStorage.Shared.Modules.Portrait)
local CraftRules     = require(game.ReplicatedStorage.Shared.Modules.CraftRules)
local GolemData      = require(game.ReplicatedStorage.Shared.Data.GolemData)
local RecipeData     = require(game.ReplicatedStorage.Shared.Data.RecipeData)
local MaterialData   = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)

RemoteEvents.Load()

local ELEMENT_ORDER = { Ember = 1, Stone = 2, Frost = 3, Storm = 4, Void = 5 }
local BOX_W, BOX_H = 920, 580

-- ── State ─────────────────────────────────────────────────────────────────────
local data
local selectedId
local rows = {}          -- blueprintId → row button
local previewModel
local previewPivot = Vector3.new(0, 5, 0)
local refreshQueued = false

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function MaterialName(id)
    local def = (MaterialData.Raw and MaterialData.Raw[id]) or (MaterialData.Refined and MaterialData.Refined[id])
    return def and def.displayName or id
end

local function EventSet()
    local set = {}
    for _, id in ipairs(data and data.AvailableEventBlueprints or {}) do set[id] = true end
    return set
end

local function CraftableCount(bp)
    return CraftRules.CraftableCount(data, bp)
end

-- nil when forging is allowed right now, otherwise the reason (server enforces the same rules)
local function LockReason(bp)
    return CraftRules.GetLockReason(data, bp, EventSet())
end

local function SortedBlueprints()
    local list = CraftRules.ListBlueprints(data, EventSet())
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.element ~= b.element then return (ELEMENT_ORDER[a.element] or 9) < (ELEMENT_ORDER[b.element] or 9) end
        return a.id < b.id
    end)
    return list
end

local function ZonesFor(element)
    local names = {}
    for _, zone in pairs(MiningZoneData.Zones) do
        local r = zone.unlockRequirement
        if r.type == "craft_golem" and r.element == element then
            table.insert(names, zone.displayName)
        end
    end
    table.sort(names)
    return names
end

-- ── GUI ───────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "AnvilMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 15
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scrim = Instance.new("TextButton")
scrim.Size = UDim2.new(1, 0, 1, 0)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.45
scrim.BorderSizePixel = 0
scrim.Text = ""
scrim.AutoButtonColor = false
scrim.Parent = gui
scrim.MouseButton1Click:Connect(function() gui.Enabled = false end)

local box = Instance.new("Frame")
box.Name = "Container"
box.Size = UDim2.new(0, BOX_W, 0, BOX_H)
box.BackgroundColor3 = Theme.Colors.Background
box.BorderSizePixel = 0
box.Parent = gui
Theme.AddCorner(box, Theme.Corner.Large)
ScaleUI.Apply(box, BOX_W, BOX_H)

-- swallow clicks on the box so they don't hit the scrim
local shield = Instance.new("TextButton")
shield.Size = UDim2.new(1, 0, 1, 0)
shield.BackgroundTransparency = 1
shield.Text = ""
shield.AutoButtonColor = false
shield.ZIndex = 0
shield.Parent = box

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = box
Theme.AddCorner(titleBar, Theme.Corner.Large)
local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0, 12)
titleFill.Position = UDim2.new(0, 0, 1, -12)
titleFill.BackgroundColor3 = Theme.Colors.Panel
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar
local title = Theme.Label(titleBar, "Golem Anvil", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(0.6, 0, 1, 0)
local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Left: list of Golems
local listHeader = Theme.Label(box, "Choose a Golem", Theme.TextSize.Heading, Theme.Colors.TextSecondary, Theme.Fonts.Heading)
listHeader.Position = UDim2.new(0, 14, 0, 58)
listHeader.Size = UDim2.new(0, 290, 0, 24)
local listScroll = Theme.ScrollFrame(box, "GolemList")
listScroll.Position = UDim2.new(0, 10, 0, 86)
listScroll.Size = UDim2.new(0, 300, 1, -96)
Theme.AddListLayout(listScroll, Enum.FillDirection.Vertical, 6)

-- Right: details
local detail = Instance.new("Frame")
detail.Name = "Detail"
detail.Position = UDim2.new(0, 324, 0, 58)
detail.Size = UDim2.new(1, -336, 1, -68)
detail.BackgroundColor3 = Theme.Colors.Panel
detail.BorderSizePixel = 0
detail.Parent = box
Theme.AddCorner(detail, Theme.Corner.Large)

local viewport = Instance.new("ViewportFrame")
viewport.Name = "Preview"
viewport.Position = UDim2.new(0, 12, 0, 12)
viewport.Size = UDim2.new(0, 230, 0, 230)
viewport.BackgroundColor3 = Theme.Colors.Background
viewport.BorderSizePixel = 0
viewport.Ambient = Color3.fromRGB(150, 150, 150)
viewport.LightColor = Color3.fromRGB(255, 240, 220)
viewport.LightDirection = Vector3.new(-1, -1, -1)
viewport.Parent = detail
Theme.AddCorner(viewport, Theme.Corner.Small)
local camera = Instance.new("Camera")
camera.FieldOfView = 40
camera.CFrame = CFrame.lookAt(Vector3.new(0, 7.5, -19), Vector3.new(0, 5, 0))
viewport.CurrentCamera = camera
camera.Parent = viewport

local nameLbl = Theme.Label(detail, "", 22, Theme.Colors.AccentBright, Theme.Fonts.Title, "Name")
nameLbl.Position = UDim2.new(0, 256, 0, 12)
nameLbl.Size = UDim2.new(1, -268, 0, 28)
local subLbl = Theme.Label(detail, "", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Heading, "Sub")
subLbl.Position = UDim2.new(0, 256, 0, 42)
subLbl.Size = UDim2.new(1, -268, 0, 20)
local descLbl = Theme.Label(detail, "", Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Body, "Desc")
descLbl.Position = UDim2.new(0, 256, 0, 68)
descLbl.Size = UDim2.new(1, -268, 0, 60)
descLbl.TextYAlignment = Enum.TextYAlignment.Top
local zoneLbl = Theme.Label(detail, "", Theme.TextSize.Body, Theme.Colors.Success, Theme.Fonts.Heading, "Zone")
zoneLbl.Position = UDim2.new(0, 256, 0, 132)
zoneLbl.Size = UDim2.new(1, -268, 0, 40)
zoneLbl.TextYAlignment = Enum.TextYAlignment.Top
local craftInfoLbl = Theme.Label(detail, "", Theme.TextSize.Body, Theme.Colors.Gold, Theme.Fonts.Heading, "CraftInfo")
craftInfoLbl.Position = UDim2.new(0, 256, 0, 184)
craftInfoLbl.Size = UDim2.new(1, -268, 0, 56)
craftInfoLbl.TextYAlignment = Enum.TextYAlignment.Top

local statsHeader = Theme.Label(detail, "What it does", Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading)
statsHeader.Position = UDim2.new(0, 14, 0, 252)
statsHeader.Size = UDim2.new(0, 260, 0, 22)
local statsLbl = Theme.Label(detail, "", Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Body, "Stats")
statsLbl.Position = UDim2.new(0, 14, 0, 278)
statsLbl.Size = UDim2.new(0, 270, 0, 130)
statsLbl.TextYAlignment = Enum.TextYAlignment.Top

local compHeader = Theme.Label(detail, "Components", Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading)
compHeader.Position = UDim2.new(0, 300, 0, 252)
compHeader.Size = UDim2.new(0, 260, 0, 22)
local compFrame = Instance.new("Frame")
compFrame.Name = "Components"
compFrame.Position = UDim2.new(0, 300, 0, 278)
compFrame.Size = UDim2.new(1, -312, 0, 130)
compFrame.BackgroundTransparency = 1
compFrame.Parent = detail
Theme.AddListLayout(compFrame, Enum.FillDirection.Vertical, 4)

local forgeBtn = Theme.Button(detail, "Forge", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "ForgeButton")
forgeBtn.Size = UDim2.new(0, 180, 0, 44)
forgeBtn.Position = UDim2.new(1, -384, 1, -58)
forgeBtn.TextSize = 18
local forgeAllBtn = Theme.Button(detail, "Forge All", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "ForgeAllButton")
forgeAllBtn.Size = UDim2.new(0, 180, 0, 44)
forgeAllBtn.Position = UDim2.new(1, -192, 1, -58)
forgeAllBtn.TextSize = 18
local statusLbl = Theme.Label(detail, "", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body, "Status")
statusLbl.Position = UDim2.new(0, 14, 1, -58)
statusLbl.Size = UDim2.new(1, -420, 0, 44)
statusLbl.TextYAlignment = Enum.TextYAlignment.Center

-- ── Rendering ─────────────────────────────────────────────────────────────────
local function ShowPreview(bp)
    if previewModel then previewModel:Destroy() end
    previewModel = GolemModel.Build(bp.element, bp.tier)
    previewModel.Parent = viewport
    previewPivot = previewModel:GetPivot().Position       -- spin on the spot, don't drift to the origin
    -- Frame whatever was built (a 13-stud Dragonbone, a high tier, wings and a halo ...): the camera backs off
    -- far enough that a sphere around the model, however it spins, fits inside the view.
    local box, size = previewModel:GetBoundingBox()
    local reach = size.Magnitude / 2 + 2 * (box.Position - previewPivot).Magnitude
    local dist = reach / math.sin(math.rad(camera.FieldOfView / 2)) * 1.05
    camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, reach * 0.12, -dist), box.Position)
end

local function RenderDetail()
    local bp = selectedId and RecipeData.Get(selectedId)
    if not bp then return end

    local tierDef  = GolemData.Tiers[bp.tier]
    local elemDef  = GolemData.Elements[bp.element]
    local stats    = GolemData.ComputeStats(bp.element, bp.tier)
    local craftable = CraftableCount(bp)
    local lock      = LockReason(bp)

    local elemName = elemDef and elemDef.displayName or bp.element
    nameLbl.Text = bp.isEventGolem and string.format("%s Golem (Event)", elemName) or string.format("%s Golem", elemName)
    nameLbl.TextColor3 = Theme.Colors[bp.element] or Theme.Colors.AccentBright
    local rarityName = GolemData.RarityForTier(bp.tier)
    subLbl.Text = string.format("Tier %d  -  %s  -  %s", bp.tier, tierDef and tierDef.name or "", rarityName)
    subLbl.TextColor3 = Theme.Colors[rarityName] or Theme.Colors.TextSecondary
    descLbl.Text = (elemDef and elemDef.description or "")
        .. ((elemDef and elemDef.skill) and ("\nSkill - " .. elemDef.skill.name .. ": " .. elemDef.skill.text) or "")
    local zones = ZonesFor(bp.element)
    zoneLbl.Text = #zones > 0 and ("Unlocks mining zone: " .. table.concat(zones, ", ")) or ""

    if lock then
        craftInfoLbl.Text = lock
        craftInfoLbl.TextColor3 = Theme.Colors.Danger
    else
        craftInfoLbl.Text = craftable > 0 and ("You can forge " .. craftable .. " right now") or "Not enough components yet"
        craftInfoLbl.TextColor3 = craftable > 0 and Theme.Colors.Gold or Theme.Colors.TextSecondary
    end

    if stats then
        local bias = elemDef and elemDef.statBias or ""
        statsLbl.Text = table.concat({
            string.format("Mining rate:  %d / hr", stats.miningRate),
            string.format("Carry capacity:  %d", stats.carryCapacity),
            string.format("Efficiency:  x%.2f", stats.efficiency),
            string.format("Luck:  %d%%", math.floor(stats.luck * 100 + 0.5)),
            string.format("Lasts:  %d hours", stats.durabilityHours or 0),
            bias ~= "" and ("Best at:  " .. tostring(bias):gsub("(%l)(%u)", "%1 %2"):lower()) or "",       -- "MiningRate" -> "mining rate"
        }, "\n")
    end

    for _, child in ipairs(compFrame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    for _, req in ipairs(bp.materialsRequired or {}) do
        local have = (data.Inventory or {})[req.id] or 0
        local ok = have >= req.qty
        local row = Theme.Label(compFrame,
            string.format("%s   %d / %d", MaterialName(req.id), have, req.qty),
            Theme.TextSize.Body + 1, ok and Theme.Colors.Success or Theme.Colors.Danger, Theme.Fonts.Heading)
        row.Size = UDim2.new(1, 0, 0, 26)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 30)
        pad.Parent = row
        local icon = MaterialIcon.Make(row, req.id, 24)
        if icon then icon.Position = UDim2.new(0, -28, 0, 1) else pad:Destroy() end
    end

    local canForge = craftable > 0 and not lock
    forgeBtn.Active = canForge
    forgeBtn.AutoButtonColor = canForge
    forgeBtn.BackgroundColor3 = canForge and Theme.Colors.Accent or Theme.Colors.PanelAlt
    forgeBtn.TextColor3 = canForge and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextDim
    forgeAllBtn.Visible = canForge and craftable > 1
    forgeAllBtn.Text = "Forge All (" .. craftable .. ")"
    statusLbl.Text = canForge and "" or (lock or "Gather more components on the mining pads.")
end

local function RenderList()
    for _, row in pairs(rows) do row:Destroy() end
    rows = {}
    local list = SortedBlueprints()
    if not selectedId or not RecipeData.Get(selectedId) then
        selectedId = list[1] and list[1].id
    end
    for i, bp in ipairs(list) do
        local craftable = CraftableCount(bp)
        local selected = bp.id == selectedId

        local row = Instance.new("TextButton")
        row.Name = bp.id
        row.LayoutOrder = i
        row.Size = UDim2.new(1, -6, 0, 54)
        row.BackgroundColor3 = selected and Theme.Colors.PanelAlt or Theme.Colors.Panel
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Parent = listScroll
        Theme.AddCorner(row, Theme.Corner.Small)

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 5, 1, -12)
        bar.Position = UDim2.new(0, 6, 0, 6)
        bar.BackgroundColor3 = Theme.Colors[bp.element] or Theme.Colors.Accent
        bar.BorderSizePixel = 0
        bar.Parent = row
        Theme.AddCorner(bar, UDim.new(0, 3))

        local rowElem = GolemData.Elements[bp.element]
        -- Tier 1 is just "Storm Golem"; stronger tiers carry their tier name so two Storm Golems are never confused
        local tierName = GolemData.Tiers[bp.tier] and GolemData.Tiers[bp.tier].name or "Golem"
        local rowName = (rowElem and rowElem.displayName or bp.element) .. " " .. ((bp.tier or 1) > 1 and tierName or "Golem")
        local nameL = Theme.Label(row, rowName, Theme.TextSize.Heading,
            selected and Theme.Colors.AccentBright or Theme.Colors.TextPrimary, Theme.Fonts.Heading)
        local face = Portrait.Golem(row, { element = bp.element, tier = bp.tier }, 42)
        face.Position = UDim2.new(0, 18, 0.5, -21)
        bar.Visible = false
        nameL.Position = UDim2.new(0, 68, 0, 6)
        nameL.Size = UDim2.new(1, -160, 0, 22)
        local rarityName = GolemData.RarityForTier(bp.tier)
        local tierL = Theme.Label(row, "Tier " .. bp.tier .. "  -  " .. rarityName, Theme.TextSize.Small,
            Theme.Colors[rarityName] or Theme.Colors.TextSecondary)
        tierL.Position = UDim2.new(0, 68, 0, 30)
        tierL.Size = UDim2.new(1, -160, 0, 18)

        local lock = LockReason(bp)
        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.new(0, 80, 0, 24)
        badge.Position = UDim2.new(1, -88, 0.5, -12)
        badge.BackgroundColor3 = (craftable > 0 and not lock) and Theme.Colors.Success or Theme.Colors.PanelAlt
        badge.Text = lock and CraftRules.ShortLockReason(lock) or (craftable > 0 and ("x" .. craftable) or "Need more")
        badge.TextColor3 = lock and Color3.fromRGB(255, 214, 120) or ((craftable > 0) and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary)
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 12
        badge.BorderSizePixel = 0
        badge.Parent = row
        Theme.AddCorner(badge, UDim.new(1, 0))

        row.MouseButton1Click:Connect(function()
            selectedId = bp.id
            ShowPreview(bp)
            RenderList()
            RenderDetail()
        end)
        rows[bp.id] = row
    end
end

local function Refresh(fetch)
    if fetch then
        local fresh = RemoteEvents.GetPlayerData:InvokeServer()
        if fresh then data = fresh end
    end
    if not data then return end
    RenderList()
    local bp = selectedId and RecipeData.Get(selectedId)
    if bp then
        if not previewModel then ShowPreview(bp) end
        RenderDetail()
    end
end

local function QueueRefresh()
    if refreshQueued or not gui.Enabled then return end
    refreshQueued = true
    task.delay(0.3, function()
        refreshQueued = false
        if gui.Enabled then Refresh(true) end
    end)
end

-- ── Actions ───────────────────────────────────────────────────────────────────
forgeBtn.MouseButton1Click:Connect(function()
    local bp = selectedId and RecipeData.Get(selectedId)
    if bp and CraftableCount(bp) > 0 and not LockReason(bp) then
        RemoteEvents.CraftGolem:FireServer(bp.id, "default", 1)
    end
end)
forgeAllBtn.MouseButton1Click:Connect(function()
    local bp = selectedId and RecipeData.Get(selectedId)
    if bp then
        local n = CraftableCount(bp)
        if n > 0 and not LockReason(bp) then
            RemoteEvents.CraftGolem:FireServer(bp.id, "default", n)
        end
    end
end)

RemoteEvents.GolemCrafted.OnClientEvent:Connect(QueueRefresh)
RemoteEvents.ResourcesCollected.OnClientEvent:Connect(QueueRefresh)

-- ── Opening ───────────────────────────────────────────────────────────────────
local function Open()
    gui.Enabled = true
    Refresh(true)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    if player == LocalPlayer and prompt.Name == "AnvilPrompt" then
        Open()
    end
end)

-- Slowly spin the preview
RunService.RenderStepped:Connect(function()
    if gui.Enabled and previewModel and previewModel.PrimaryPart then
        previewModel:PivotTo(CFrame.new(previewPivot) * CFrame.Angles(0, os.clock() * 0.8, 0))
    end
end)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not gui.Enabled and previewModel then
        previewModel:Destroy()
        previewModel = nil
    end
end)
