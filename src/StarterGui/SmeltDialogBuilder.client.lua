-- Modal dialog for selecting a raw material to smelt and choosing a quantity.
-- Opened programmatically; fires RemoteEvents.StartSmelt on confirm.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)

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
container.Position = UDim2.new(0.5, -260, 0.5, -270)
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
scroll.Size = UDim2.new(1, -16, 0, 360)
scroll.Position = UDim2.new(0, 8, 0, 58)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scroll
Theme.AddPadding(scroll, 4, 4, 4, 4)

-- Selected state
local selectedMaterialId = nil
local selectedCard = nil

local RARITY_COLORS = {
    Common    = Theme.Colors.Common,
    Uncommon  = Theme.Colors.Uncommon,
    Rare      = Theme.Colors.Rare,
    Epic      = Theme.Colors.Epic,
    Legendary = Theme.Colors.Legendary,
}

local function deselectAll()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then
            child.BackgroundColor3 = Theme.Colors.Panel
        end
    end
    selectedMaterialId = nil
    selectedCard = nil
end

-- Populate is called by SmeltDialog.Open(inventory)
local function Populate(inventory)
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    selectedMaterialId = nil
    selectedCard = nil

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

        selBtn.MouseButton1Click:Connect(function()
            deselectAll()
            selectedMaterialId = item.id
            selectedCard = card
            card.BackgroundColor3 = Color3.fromRGB(50, 40, 28)
            selBtn.BackgroundColor3 = Theme.Colors.Accent
            selBtn.TextColor3 = Color3.fromRGB(255,255,255)
            selBtn.Text = "OK"
            -- Update qty spinner to max
            qtyInput.Text = tostring(item.qty)
            maxQtyLbl.Text = "/ " .. item.qty
        end)
    end
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

local qtyInput = Instance.new("TextBox")
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

local maxQtyLbl = Theme.Label(qtyRow, "/ ?", Theme.TextSize.Body, Theme.Colors.TextDim,
    Theme.Fonts.Body, "MaxQtyLabel")
maxQtyLbl.Size = UDim2.new(0, 50, 0, 30)
maxQtyLbl.Position = UDim2.new(0, 198, 0, 8)
maxQtyLbl.TextXAlignment = Enum.TextXAlignment.Left

local plusBtn = Theme.Button(qtyRow, "+", Theme.Colors.PanelAlt, Theme.Colors.TextPrimary, "PlusBtn")
plusBtn.Size = UDim2.new(0, 34, 0, 30)
plusBtn.Position = UDim2.new(0, 250, 0, 8)
plusBtn.TextSize = 18

local function getQty()   return math.max(1, tonumber(qtyInput.Text) or 1) end
minusBtn.MouseButton1Click:Connect(function() qtyInput.Text = tostring(math.max(1, getQty() - 1)) end)
plusBtn.MouseButton1Click:Connect(function()  qtyInput.Text = tostring(getQty() + 1) end)

-- ── Confirm button ────────────────────────────────────────────────────────────
local confirmBtn = Theme.Button(container, "⚗  Start Smelting", Theme.Colors.Accent,
    Color3.fromRGB(255,255,255), "ConfirmButton")
confirmBtn.Size = UDim2.new(1, -16, 0, 42)
confirmBtn.Position = UDim2.new(0, 8, 1, -50)
confirmBtn.TextSize = 15

confirmBtn.MouseButton1Click:Connect(function()
    if not selectedMaterialId then return end
    local qty = getQty()
    local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
    RemoteEvents.StartSmelt:FireServer(selectedMaterialId, qty)
    gui.Enabled = false
end)

-- ── Public API via BindableFunction ───────────────────────────────────────────
local openFn = Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.OnInvoke = function(inventory)
    Populate(inventory)
    gui.Enabled = true
end
openFn.Parent = gui
