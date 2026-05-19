-- Modal for listing an item on the Forge Market.
-- Exposes Open(inventory) via BindableFunction; fires RemoteEvents.ListOnMarket on confirm.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Theme       = require(game.ReplicatedStorage.Shared.Modules.Theme)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

local gui = Instance.new("ScreenGui")
gui.Name            = "MarketListingDialog"
gui.ResetOnSpawn    = false
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Enabled         = false
gui.DisplayOrder    = 22
gui.Parent          = LocalPlayer:WaitForChild("PlayerGui")

Theme.Scrim(gui)

-- Container
local container = Instance.new("Frame")
container.Name             = "Container"
container.Size             = UDim2.new(0, 480, 0, 540)
container.Position         = UDim2.new(0.5, -240, 0.5, -270)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel  = 0
container.Parent           = gui
Theme.AddCorner(container, Theme.Corner.Large)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel  = 0
titleBar.Parent           = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tf = Instance.new("Frame"); tf.Size = UDim2.new(1,0,0,12); tf.Position = UDim2.new(0,0,1,-12)
tf.BackgroundColor3 = Theme.Colors.Panel; tf.BorderSizePixel = 0; tf.Parent = titleBar

local titleLabel = Theme.Label(titleBar, "🏪  List Item on Market", Theme.TextSize.Heading,
    Theme.Colors.Gold, Theme.Fonts.Heading, "TitleLabel")
titleLabel.Size           = UDim2.new(0.8, 0, 1, 0)
titleLabel.Position       = UDim2.new(0, 14, 0, 0)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Theme.Button(titleBar, "✕", Theme.Colors.Danger, Color3.fromRGB(255,255,255), "CloseButton")
closeBtn.Size     = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Material scroll (pick what to list)
local listLabel = Theme.Label(container, "Select Material", Theme.TextSize.Body,
    Theme.Colors.TextSecondary, Theme.Fonts.Heading)
listLabel.Size     = UDim2.new(1, -16, 0, 22)
listLabel.Position = UDim2.new(0, 8, 0, 56)

local scroll = Theme.ScrollFrame(container, "MaterialScroll")
scroll.Size                = UDim2.new(1, -16, 0, 280)
scroll.Position            = UDim2.new(0, 8, 0, 80)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Theme.AddPadding(scroll, 4, 4, 4, 4)

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding       = UDim.new(0, 4)
listLayout.Parent        = scroll

-- Quantity row
local qtyRow = Instance.new("Frame")
qtyRow.Size             = UDim2.new(1, -16, 0, 44)
qtyRow.Position         = UDim2.new(0, 8, 0, 368)
qtyRow.BackgroundColor3 = Theme.Colors.Panel
qtyRow.BorderSizePixel  = 0
qtyRow.Parent           = container
Theme.AddCorner(qtyRow, Theme.Corner.Small)

local qtyLabel = Theme.Label(qtyRow, "Quantity:", Theme.TextSize.Body,
    Theme.Colors.TextSecondary)
qtyLabel.Size     = UDim2.new(0, 90, 1, 0)
qtyLabel.Position = UDim2.new(0, 8, 0, 0)

local minusBtn = Theme.Button(qtyRow, "−", Theme.Colors.PanelAlt, Theme.Colors.TextPrimary, "QtyMinus")
minusBtn.Size     = UDim2.new(0, 32, 0, 30)
minusBtn.Position = UDim2.new(0, 100, 0.5, -15)

local qtyBox = Instance.new("TextBox")
qtyBox.Name             = "QtyBox"
qtyBox.Size             = UDim2.new(0, 60, 0, 30)
qtyBox.Position         = UDim2.new(0, 136, 0.5, -15)
qtyBox.BackgroundColor3 = Theme.Colors.Background
qtyBox.BorderSizePixel  = 0
qtyBox.Text             = "1"
qtyBox.TextColor3       = Theme.Colors.TextPrimary
qtyBox.Font             = Theme.Fonts.Mono
qtyBox.TextSize         = 16
qtyBox.TextXAlignment   = Enum.TextXAlignment.Center
qtyBox.Parent           = qtyRow
Theme.AddCorner(qtyBox, Theme.Corner.Small)

local plusBtn = Theme.Button(qtyRow, "+", Theme.Colors.PanelAlt, Theme.Colors.TextPrimary, "QtyPlus")
plusBtn.Size     = UDim2.new(0, 32, 0, 30)
plusBtn.Position = UDim2.new(0, 200, 0.5, -15)

-- Price row
local priceRow = Instance.new("Frame")
priceRow.Size             = UDim2.new(1, -16, 0, 44)
priceRow.Position         = UDim2.new(0, 8, 0, 420)
priceRow.BackgroundColor3 = Theme.Colors.Panel
priceRow.BorderSizePixel  = 0
priceRow.Parent           = container
Theme.AddCorner(priceRow, Theme.Corner.Small)

local priceLabel = Theme.Label(priceRow, "Price (⚡):", Theme.TextSize.Body,
    Theme.Colors.TextSecondary)
priceLabel.Size     = UDim2.new(0, 90, 1, 0)
priceLabel.Position = UDim2.new(0, 8, 0, 0)

local priceBox = Instance.new("TextBox")
priceBox.Name             = "PriceBox"
priceBox.Size             = UDim2.new(0, 120, 0, 30)
priceBox.Position         = UDim2.new(0, 104, 0.5, -15)
priceBox.BackgroundColor3 = Theme.Colors.Background
priceBox.BorderSizePixel  = 0
priceBox.Text             = "100"
priceBox.TextColor3       = Theme.Colors.Gold
priceBox.Font             = Theme.Fonts.Mono
priceBox.TextSize         = 16
priceBox.TextXAlignment   = Enum.TextXAlignment.Center
priceBox.PlaceholderText  = "Enter price..."
priceBox.Parent           = priceRow
Theme.AddCorner(priceBox, Theme.Corner.Small)

local feeLabel = Theme.Label(priceRow, "5% fee on sale", Theme.TextSize.Small,
    Theme.Colors.TextDim)
feeLabel.Size     = UDim2.new(0, 120, 1, 0)
feeLabel.Position = UDim2.new(0, 234, 0, 0)

-- Confirm button
local confirmBtn = Theme.Button(container, "List Item", Theme.Colors.Accent,
    Color3.fromRGB(255,255,255), "ConfirmButton")
confirmBtn.Size     = UDim2.new(1, -16, 0, 40)
confirmBtn.Position = UDim2.new(0, 8, 1, -48)
confirmBtn.TextSize = 15

-- ── State ─────────────────────────────────────────────────────────────────────
local selectedMaterialId = nil
local currentInventory   = {}
local selectedQtyMax     = 1

local function getQty()
    return math.clamp(tonumber(qtyBox.Text) or 1, 1, selectedQtyMax)
end

local function setQty(n)
    qtyBox.Text = tostring(math.clamp(n, 1, selectedQtyMax))
end

minusBtn.MouseButton1Click:Connect(function() setQty(getQty() - 1) end)
plusBtn.MouseButton1Click:Connect(function()  setQty(getQty() + 1) end)

qtyBox.FocusLost:Connect(function()
    local n = tonumber(qtyBox.Text)
    setQty(n or 1)
end)

-- ── Material picker ───────────────────────────────────────────────────────────
local selectedRow = nil

local function DeselectAll()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then
            child.BackgroundColor3 = Theme.Colors.Panel
        end
    end
    selectedRow = nil
end

local function RenderInventory(inventory)
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    selectedMaterialId = nil

    local RARITY_COLORS = {
        Common    = Theme.Colors.TextSecondary,
        Uncommon  = Theme.Colors.Success,
        Rare      = Color3.fromRGB(80, 140, 255),
        Epic      = Theme.Colors.Legendary,
        Legendary = Theme.Colors.Gold,
    }

    local hasItems = false
    for matId, qty in pairs(inventory) do
        if qty and qty > 0 then
            local matDef = MaterialData.Get(matId)
            -- Only list smeltable raw materials (not refined, not golems)
            if matDef and matDef.type ~= "refined" then
                hasItems = true
                local rarityColor = RARITY_COLORS[matDef.rarity] or Theme.Colors.TextSecondary

                local row = Instance.new("Frame")
                row.Name             = matId
                row.Size             = UDim2.new(1, -8, 0, 44)
                row.BackgroundColor3 = Theme.Colors.Panel
                row.BorderSizePixel  = 0
                row.Parent           = scroll
                Theme.AddCorner(row, Theme.Corner.Small)
                Theme.Stripe(row, rarityColor)

                local nameLbl = Theme.Label(row, matDef.displayName or matId,
                    Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Body)
                nameLbl.Size     = UDim2.new(0.55, 0, 0, 22)
                nameLbl.Position = UDim2.new(0, 12, 0, 5)
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left

                local rarityLbl = Theme.Label(row, matDef.rarity or "",
                    Theme.TextSize.Small, rarityColor)
                rarityLbl.Size     = UDim2.new(0.3, 0, 0, 16)
                rarityLbl.Position = UDim2.new(0, 12, 0, 26)
                rarityLbl.TextXAlignment = Enum.TextXAlignment.Left

                local qtyLbl = Theme.Label(row, "×" .. qty, Theme.TextSize.Body,
                    Theme.Colors.Gold, Theme.Fonts.Mono)
                qtyLbl.Size     = UDim2.new(0, 60, 1, 0)
                qtyLbl.Position = UDim2.new(1, -68, 0, 0)
                qtyLbl.TextXAlignment = Enum.TextXAlignment.Right

                row.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    DeselectAll()
                    selectedMaterialId = matId
                    selectedQtyMax     = qty
                    selectedRow        = row
                    row.BackgroundColor3 = Color3.fromRGB(40, 38, 28)
                    setQty(1)
                end)
            end
        end
    end

    if not hasItems then
        local lbl = Theme.Label(scroll, "No materials to list.", Theme.TextSize.Body,
            Theme.Colors.TextDim)
        lbl.Size = UDim2.new(1, 0, 0, 40)
        lbl.TextXAlignment = Enum.TextXAlignment.Center
    end
end

-- ── Confirm ───────────────────────────────────────────────────────────────────
confirmBtn.MouseButton1Click:Connect(function()
    if not selectedMaterialId then return end
    local qty   = getQty()
    local price = tonumber(priceBox.Text)
    if not price or price < 1 then return end

    local item = { type = "material", id = selectedMaterialId, qty = qty }
    RemoteEvents.ListOnMarket:FireServer(item, price)
    gui.Enabled = false
end)

-- ── Public API ─────────────────────────────────────────────────────────────────
local openFn = Instance.new("BindableFunction")
openFn.Name = "Open"
openFn.OnInvoke = function(inventory)
    currentInventory = inventory or {}
    selectedMaterialId = nil
    selectedQtyMax = 1
    qtyBox.Text  = "1"
    priceBox.Text = "100"
    RenderInventory(currentInventory)
    gui.Enabled = true
end
openFn.Parent = gui
