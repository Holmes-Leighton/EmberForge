-- Modal dialog for selecting a raw material to smelt and choosing a quantity.
-- Opened programmatically; fires RemoteEvents.StartSmelt on confirm.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)

local gui = Instance.new("ScreenGui")
gui.Name = "SmeltDialog"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.DisplayOrder = 20          -- above ForgeMenu
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Scrim
local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1,0,1,0)
scrim.BackgroundColor3 = Color3.fromRGB(0,0,0)
scrim.BackgroundTransparency = 0.6
scrim.BorderSizePixel = 0
scrim.Parent = gui

-- Container (narrower, modal style)
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 520, 0, 540)
ScaleUI.Apply(container, 520, 540)
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
local tf=Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,12); tf.Position=UDim2.new(0,0,1,-12)
tf.BackgroundColor3=Theme.Colors.Panel; tf.BorderSizePixel=0; tf.Parent=titleBar

Theme.Label(titleBar, "⚗  Choose Material to Smelt", Theme.TextSize.Heading,
    Theme.Colors.AccentBright, Theme.Fonts.Heading).Size = UDim2.new(0.85, 0, 1, 0)

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Material list scroll
local scroll = Theme.ScrollFrame(container, "MaterialScroll")
scroll.Size = UDim2.new(1, -16, 0, 326)
scroll.Position = UDim2.new(0, 8, 0, 92)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scroll
Theme.AddPadding(scroll, 4, 4, 4, 4)

-- Select all / clear row (handlers wired up below, once the helpers exist)
local selectAllBtn = Theme.Button(container, "Select All", Theme.Colors.PanelAlt,
    Theme.Colors.TextPrimary, "SelectAllButton")
selectAllBtn.Size = UDim2.new(0.5, -12, 0, 28)
selectAllBtn.Position = UDim2.new(0, 8, 0, 58)
selectAllBtn.TextSize = 13

local clearBtn = Theme.Button(container, "Clear Selection", Theme.Colors.PanelAlt,
    Theme.Colors.TextPrimary, "ClearSelectionButton")
clearBtn.Size = UDim2.new(0.5, -12, 0, 28)
clearBtn.Position = UDim2.new(0.5, 4, 0, 58)
clearBtn.TextSize = 13

-- Selected state
local qtyInput, maxQtyLbl   -- created further down; declared here so the material buttons can reach them
local selected = {}       -- materialId → owned qty (multi-select)
local selectionRows = {}  -- materialId → { card, btn, qty }
local selectionOrder = {} -- materialIds in display order
local confirmBtn
local slotLimit = nil      -- free smelter slots (each material takes one); nil = no limit known
local limitLbl

local RARITY_COLORS = {
    Common    = Theme.Colors.Common,
    Uncommon  = Theme.Colors.Uncommon,
    Rare      = Theme.Colors.Rare,
    Epic      = Theme.Colors.Epic,
    Legendary = Theme.Colors.Legendary,
}

local function selectedCount()
    local n = 0
    for _ in pairs(selected) do n += 1 end
    return n
end

-- Refresh card visuals, quantity row and confirm button from the selection
local function refreshSelection()
    for id, row in pairs(selectionRows) do
        local on = selected[id] ~= nil
        row.card.BackgroundColor3 = on and Color3.fromRGB(50, 40, 28) or Theme.Colors.Panel
        row.btn.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        row.btn.TextColor3 = on and Color3.fromRGB(255,255,255) or Theme.Colors.TextPrimary
        row.btn.Text = on and "Selected" or "Select"
    end
    local n = selectedCount()
    if n == 1 then
        local _, q = next(selected)
        qtyInput.Text = tostring(q)
        maxQtyLbl.Text = "/ " .. q
        qtyInput.TextEditable = true
    elseif n > 1 then
        qtyInput.Text = "All"
        maxQtyLbl.Text = n .. " items"
        qtyInput.TextEditable = false
    else
        qtyInput.Text = "1"
        maxQtyLbl.Text = "/ ?"
        qtyInput.TextEditable = true
    end
    if confirmBtn then
        confirmBtn.Text = n > 1 and ("⚗  Smelt " .. n .. " Materials") or "⚗  Start Smelting"
    end
end

local function deselectAll()
    selected = {}
    refreshSelection()
end

-- Shows how many slots are free, or why a pick was refused
local function showLimit(warn)
    if not limitLbl or not slotLimit then return end
    limitLbl.TextColor3 = warn and Theme.Colors.Danger or Theme.Colors.TextSecondary
    limitLbl.Text = warn or string.format("Free smelter slots: %d", slotLimit)
end

-- Select All stops at the free smelter slots (the first ones in the list, rarest first)
local function selectAll()
    selected = {}
    local taken = 0
    for _, id in ipairs(selectionOrder) do
        if slotLimit and taken >= slotLimit then break end
        selected[id] = selectionRows[id].qty
        taken += 1
    end
    refreshSelection()
    if slotLimit and taken < #selectionOrder then
        showLimit(string.format("Only %d free slot%s: picked the first %d", slotLimit, slotLimit == 1 and "" or "s", taken))
    else
        showLimit()
    end
end

selectAllBtn.MouseButton1Click:Connect(selectAll)
clearBtn.MouseButton1Click:Connect(deselectAll)

-- Populate is called by SmeltDialog.Open(inventory, freeSlots)
local function Populate(inventory, freeSlots)
    slotLimit = freeSlots
    showLimit()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    selected = {}
    selectionRows = {}
    selectionOrder = {}

    local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
    local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

    -- Only show raw materials the player has that have a smelt output
    local items = {}
    for matId, qty in pairs(inventory) do
        if qty > 0 then
            local mat = MaterialData.Raw[matId]
            if mat and mat.smeltOutput and mat.smeltTime > 0 then
                table.insert(items, { id = matId, qty = qty, mat = mat })
            end
        end
    end

    if #items == 0 then
        local emptyLbl = Theme.Label(scroll, "No smeltable materials in inventory.",
            Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body)
        emptyLbl.Size = UDim2.new(1, 0, 0, 40)
        emptyLbl.TextXAlignment = Enum.TextXAlignment.Center
        return
    end

    -- Sort: Legendary first
    local rarityOrder = { Legendary=1, Epic=2, Rare=3, Uncommon=4, Common=5 }
    table.sort(items, function(a, b)
        local ra = rarityOrder[(a.mat and a.mat.rarity) or "Common"] or 5
        local rb = rarityOrder[(b.mat and b.mat.rarity) or "Common"] or 5
        return ra < rb
    end)

    for _, item in ipairs(items) do
        local mat    = item.mat
        local rColor = RARITY_COLORS[mat.rarity] or Theme.Colors.Common
        local smeltOut = MaterialData.Refined[mat.smeltOutput] or MaterialData.All[mat.smeltOutput]

        local card = Instance.new("Frame")
        card.Name = item.id
        card.Size = UDim2.new(1, -8, 0, 64)
        card.BackgroundColor3 = Theme.Colors.Panel
        card.BorderSizePixel = 0
        card.Parent = scroll
        Theme.AddCorner(card, Theme.Corner.Small)

        Theme.Stripe(card, rColor)

        -- Material name + rarity
        local nameLbl = Theme.Label(card, mat.displayName,
            Theme.TextSize.Heading, rColor, Theme.Fonts.Heading)
        nameLbl.Size = UDim2.new(0.45, 0, 0, 22)
        nameLbl.Position = UDim2.new(0, 10, 0, 6)

        local rarLbl = Theme.Label(card, mat.rarity, Theme.TextSize.Small, Theme.Colors.TextDim)
        rarLbl.Size = UDim2.new(0.3, 0, 0, 16)
        rarLbl.Position = UDim2.new(0, 10, 0, 28)

        -- Quantity owned
        local qtyLbl = Theme.Label(card, "Owned: " .. Utils.FormatNumber(item.qty),
            Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body)
        qtyLbl.Size = UDim2.new(0.28, 0, 0, 22)
        qtyLbl.Position = UDim2.new(0, 10, 0, 38)

        -- Output info
        local outName = smeltOut and smeltOut.displayName or mat.smeltOutput
        local ratio   = mat.smeltRatio or 1
        local outLbl = Theme.Label(card,
            "→ " .. outName .. (ratio > 1 and "  (" .. ratio .. ":1)" or ""),
            Theme.TextSize.Small, Theme.Colors.AccentBright, Theme.Fonts.Body)
        outLbl.Size = UDim2.new(0.35, 0, 0, 22)
        outLbl.Position = UDim2.new(0.42, 0, 0, 6)

        -- Smelt time
        local timeStr = Utils.FormatTime(mat.smeltTime)
        local timeLbl = Theme.Label(card, "⏱ " .. timeStr .. " / item",
            Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Mono)
        timeLbl.Size = UDim2.new(0.35, 0, 0, 16)
        timeLbl.Position = UDim2.new(0.42, 0, 0, 28)

        -- Select button
        local selBtn = Theme.Button(card, "Select", Theme.Colors.PanelAlt,
            Theme.Colors.TextPrimary, "SelectBtn")
        selBtn.Size = UDim2.new(0, 80, 0, 34)
        selBtn.Position = UDim2.new(1, -88, 0.5, -17)
        selBtn.TextSize = 13

        selectionRows[item.id] = { card = card, btn = selBtn, qty = item.qty }
        table.insert(selectionOrder, item.id)

        -- Toggle: click again to unselect
        selBtn.MouseButton1Click:Connect(function()
            if selected[item.id] then
                selected[item.id] = nil
                showLimit()
            elseif slotLimit and selectedCount() >= slotLimit then
                showLimit(slotLimit == 0 and "No free smelter slots" or string.format("Only %d free smelter slot%s", slotLimit, slotLimit == 1 and "" or "s"))
                return
            else
                selected[item.id] = item.qty
                showLimit()
            end
            refreshSelection()
        end)
    end
    refreshSelection()
end

-- ── Quantity row ──────────────────────────────────────────────────────────────
local qtyRow = Instance.new("Frame")
qtyRow.Name = "QuantityRow"
qtyRow.Size = UDim2.new(1, -16, 0, 46)
qtyRow.Position = UDim2.new(0, 8, 0, 426)
qtyRow.BackgroundColor3 = Theme.Colors.Panel
qtyRow.BorderSizePixel = 0
qtyRow.Parent = container
Theme.AddCorner(qtyRow, Theme.Corner.Small)

Theme.Label(qtyRow, "Quantity:", Theme.TextSize.Body, Theme.Colors.TextSecondary,
    Theme.Fonts.Heading).Size = UDim2.new(0, 80, 1, 0)
Theme.Label(qtyRow, "Quantity:").Position = UDim2.new(0, 10, 0, 0)

local minusBtn = Theme.Button(qtyRow, "−", Theme.Colors.PanelAlt, Theme.Colors.TextPrimary, "MinusBtn")
minusBtn.Size = UDim2.new(0, 34, 0, 30)
minusBtn.Position = UDim2.new(0, 92, 0, 8)
minusBtn.TextSize = 18

qtyInput = Instance.new("TextBox")
qtyInput.Name = "QtyInput"
qtyInput.Size = UDim2.new(0, 60, 0, 30)
qtyInput.Position = UDim2.new(0, 132, 0, 8)
qtyInput.BackgroundColor3 = Theme.Colors.PanelAlt
qtyInput.BorderSizePixel = 0
qtyInput.Text = "1"
qtyInput.Font = Enum.Font.GothamBold
qtyInput.TextSize = 16
qtyInput.TextColor3 = Theme.Colors.TextPrimary
qtyInput.PlaceholderText = "1"
qtyInput.Parent = qtyRow
Theme.AddCorner(qtyInput, Theme.Corner.Small)

maxQtyLbl = Theme.Label(qtyRow, "/ ?", Theme.TextSize.Body, Theme.Colors.TextDim,
    Theme.Fonts.Body, "MaxQtyLabel")
maxQtyLbl.Size = UDim2.new(0, 50, 0, 30)
maxQtyLbl.Position = UDim2.new(0, 198, 0, 8)
maxQtyLbl.TextXAlignment = Enum.TextXAlignment.Left

limitLbl = Theme.Label(qtyRow, "", Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body, "SlotLimitLabel")
limitLbl.Size = UDim2.new(0, 190, 1, 0)
limitLbl.Position = UDim2.new(1, -200, 0, 0)
limitLbl.TextXAlignment = Enum.TextXAlignment.Right

local plusBtn = Theme.Button(qtyRow, "+", Theme.Colors.PanelAlt, Theme.Colors.TextPrimary, "PlusBtn")
plusBtn.Size = UDim2.new(0, 34, 0, 30)
plusBtn.Position = UDim2.new(0, 250, 0, 8)
plusBtn.TextSize = 18

local function getQty()   return math.max(1, tonumber(qtyInput.Text) or 1) end
minusBtn.MouseButton1Click:Connect(function()
    if selectedCount() > 1 then return end
    qtyInput.Text = tostring(math.max(1, getQty() - 1))
end)
plusBtn.MouseButton1Click:Connect(function()
    if selectedCount() > 1 then return end
    local _, owned = next(selected)
    qtyInput.Text = tostring(math.min(getQty() + 1, owned or math.huge))
end)

-- ── Confirm button ────────────────────────────────────────────────────────────
confirmBtn = Theme.Button(container, "⚗  Start Smelting", Theme.Colors.Accent,
    Color3.fromRGB(255,255,255), "ConfirmButton")
confirmBtn.Size = UDim2.new(1, -16, 0, 42)
confirmBtn.Position = UDim2.new(0, 8, 1, -50)
confirmBtn.TextSize = 15

confirmBtn.MouseButton1Click:Connect(function()
    local n = selectedCount()
    if n == 0 then return end
    if slotLimit and n > slotLimit then showLimit("Pick fewer: not enough free smelter slots") return end
    local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
    if n == 1 then
        local id, owned = next(selected)
        RemoteEvents.StartSmelt:FireServer(id, math.min(getQty(), owned))
    else
        -- Several materials: smelt everything owned of each, one job per material
        for _, id in ipairs(selectionOrder) do
            if selected[id] then
                RemoteEvents.StartSmelt:FireServer(id, selected[id])
            end
        end
    end
    gui.Enabled = false
end)

-- ── Public API via BindableFunction ───────────────────────────────────────────
local openFn = Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.OnInvoke = function(inventory, freeSlots)
    Populate(inventory, freeSlots)
    gui.Enabled = true
end
openFn.Parent = gui
