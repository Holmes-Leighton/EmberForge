-- Manages the inventory/materials panel and Golem collection display.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents   = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local MaterialData   = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local GolemData      = require(game.ReplicatedStorage.Shared.Data.GolemData)
local Utils          = require(game.ReplicatedStorage.Shared.Modules.Utils)

local InventoryController = {}

local inventoryGui
local materialCache = {}   -- materialId → current quantity (local mirror)
local golemCache    = {}   -- golem id → golem object

-- ── Init ──────────────────────────────────────────────────────────────────────
function InventoryController.Init(playerData)
    InventoryController._data = playerData

    -- Build local caches
    for matId, qty in pairs(playerData.Inventory or {}) do
        materialCache[matId] = qty
    end
    for _, g in ipairs(playerData.Golems or {}) do
        golemCache[g.id] = g
    end

    task.spawn(function()
        inventoryGui = PlayerGui:WaitForChild("InventoryMenu", 10)
        if not inventoryGui then return end
        InventoryController._BuildMaterialList()
        InventoryController._BuildGolemList()
    end)
end

-- ── Material List ─────────────────────────────────────────────────────────────
function InventoryController._BuildMaterialList()
    if not inventoryGui then return end
    local scroll = inventoryGui:FindFirstChild("MaterialScroll", true)
    if not scroll then return end

    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local rarity_order = { "Legendary", "Epic", "Rare", "Uncommon", "Common" }
    local sorted = {}
    for matId, qty in pairs(materialCache) do
        if qty > 0 then
            local mat = MaterialData.Get(matId)
            table.insert(sorted, { id = matId, qty = qty, mat = mat })
        end
    end
    -- Sort by rarity then name
    local rarityRank = {}
    for i, r in ipairs(rarity_order) do rarityRank[r] = i end

    table.sort(sorted, function(a, b)
        local ra = rarityRank[(a.mat and a.mat.rarity) or "Common"] or 99
        local rb = rarityRank[(b.mat and b.mat.rarity) or "Common"] or 99
        if ra ~= rb then return ra < rb end
        return a.id < b.id
    end)

    local yOff = 0
    for _, entry in ipairs(sorted) do
        local row = InventoryController._CreateMaterialRow(entry.id, entry.qty, entry.mat, yOff)
        row.Parent = scroll
        yOff = yOff + 44
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, yOff + 5)
end

local RARITY_COLORS = {
    Common    = Color3.fromRGB(180, 180, 180),
    Uncommon  = Color3.fromRGB(80, 200, 100),
    Rare      = Color3.fromRGB(80, 130, 230),
    Epic      = Color3.fromRGB(160, 70, 230),
    Legendary = Color3.fromRGB(255, 180, 30),
}

function InventoryController._CreateMaterialRow(matId, qty, mat, yOff)
    local row = Instance.new("Frame")
    row.Name = matId
    row.Size = UDim2.new(1, -10, 0, 40)
    row.Position = UDim2.new(0, 5, 0, yOff + 2)
    row.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
    row.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = row

    local rarity = (mat and mat.rarity) or "Common"
    local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(180, 180, 180)

    -- Rarity stripe
    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, 0)
    stripe.Position = UDim2.new(0, 0, 0, 0)
    stripe.BackgroundColor3 = rarityColor
    stripe.BorderSizePixel = 0
    stripe.Parent = row

    local stripeCorner = Instance.new("UICorner")
    stripeCorner.CornerRadius = UDim.new(0, 5)
    stripeCorner.Parent = stripe

    -- Name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.65, 0, 0, 40)
    nameLbl.Position = UDim2.new(0, 12, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = (mat and mat.displayName) or matId
    nameLbl.TextColor3 = Color3.fromRGB(220, 210, 200)
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 13
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = row

    -- Quantity
    local qtyLbl = Instance.new("TextLabel")
    qtyLbl.Name = "QtyLabel"
    qtyLbl.Size = UDim2.new(0.3, -5, 0, 40)
    qtyLbl.Position = UDim2.new(0.7, 0, 0, 0)
    qtyLbl.BackgroundTransparency = 1
    qtyLbl.Text = Utils.FormatNumber(qty)
    qtyLbl.TextColor3 = rarityColor
    qtyLbl.Font = Enum.Font.GothamBold
    qtyLbl.TextSize = 14
    qtyLbl.TextXAlignment = Enum.TextXAlignment.Right
    qtyLbl.Parent = row

    return row
end

-- ── Golem List ────────────────────────────────────────────────────────────────
function InventoryController._BuildGolemList()
    if not inventoryGui then return end
    local scroll = inventoryGui:FindFirstChild("GolemScroll", true)
    if not scroll then return end

    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local data = InventoryController._data
    local yOff = 0
    for _, golem in ipairs(data.Golems or {}) do
        local card = InventoryController._CreateGolemCard(golem, yOff)
        card.Parent = scroll
        yOff = yOff + 100
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, yOff + 5)
end

local ELEMENT_COLORS = {
    Ember = Color3.fromRGB(220, 80, 30),
    Stone = Color3.fromRGB(120, 100, 70),
    Frost = Color3.fromRGB(100, 170, 230),
    Storm = Color3.fromRGB(140, 100, 220),
    Void  = Color3.fromRGB(80, 50, 120),
}

function InventoryController._CreateGolemCard(golem, yOff)
    local stats = GolemData.ComputeStats(golem.element, golem.tier, golem.fusionBonus)
    local elemColor = ELEMENT_COLORS[golem.element] or Color3.fromRGB(150, 150, 150)

    local card = Instance.new("Frame")
    card.Name = golem.id
    card.Size = UDim2.new(1, -10, 0, 95)
    card.Position = UDim2.new(0, 5, 0, yOff + 2)
    card.BackgroundColor3 = Color3.fromRGB(35, 30, 25)
    card.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    -- Element banner
    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(1, 0, 0, 28)
    banner.Position = UDim2.new(0, 0, 0, 0)
    banner.BackgroundColor3 = elemColor
    banner.BorderSizePixel = 0
    banner.Parent = card

    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 6)
    bannerCorner.Parent = banner

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -8, 1, 0)
    nameLbl.Position = UDim2.new(0, 8, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = (GolemData.Tiers[golem.tier] and GolemData.Tiers[golem.tier].name or "Golem")
        .. " [" .. golem.element .. "]"
        .. (golem.deployed and " ⚡ DEPLOYED" or "")
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = banner

    -- Stats
    if stats then
        local statsText = string.format(
            "⛏ %s/hr  📦 %s  🎲 %.0f%%  ⚡ %.0f%%",
            Utils.FormatNumber(stats.miningRate),
            Utils.FormatNumber(stats.carryCapacity),
            stats.luck * 100,
            stats.efficiency * 100
        )
        local statsLbl = Instance.new("TextLabel")
        statsLbl.Size = UDim2.new(1, -8, 0, 30)
        statsLbl.Position = UDim2.new(0, 8, 0, 30)
        statsLbl.BackgroundTransparency = 1
        statsLbl.Text = statsText
        statsLbl.TextColor3 = Color3.fromRGB(180, 175, 170)
        statsLbl.Font = Enum.Font.Code
        statsLbl.TextSize = 11
        statsLbl.TextXAlignment = Enum.TextXAlignment.Left
        statsLbl.Parent = card
    end

    -- Return button (if deployed)
    if golem.deployed then
        local returnBtn = Instance.new("TextButton")
        returnBtn.Size = UDim2.new(0, 80, 0, 24)
        returnBtn.Position = UDim2.new(1, -88, 0, 63)
        returnBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 40)
        returnBtn.Text = "Recall"
        returnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        returnBtn.Font = Enum.Font.GothamBold
        returnBtn.TextSize = 12
        returnBtn.BorderSizePixel = 0
        returnBtn.Parent = card

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = returnBtn

        returnBtn.MouseButton1Click:Connect(function()
            local RemoteEvts = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
            RemoteEvts.ReturnGolem:FireServer(golem.id)
        end)
    end

    return card
end

-- ── Event Handlers ────────────────────────────────────────────────────────────
function InventoryController.OnResourcesCollected(gains)
    for matId, qty in pairs(gains) do
        materialCache[matId] = (materialCache[matId] or 0) + qty
        -- Update single row label instead of full rebuild
        if inventoryGui and inventoryGui.Enabled then
            local scroll = inventoryGui:FindFirstChild("MaterialScroll", true)
            if scroll then
                local row = scroll:FindFirstChild(matId)
                if row then
                    local lbl = row:FindFirstChild("QtyLabel")
                    if lbl then
                        lbl.Text = Utils.FormatNumber(materialCache[matId])
                    end
                else
                    InventoryController._BuildMaterialList()  -- new material, rebuild
                end
            end
        end
    end
end

function InventoryController.OnGolemAdded(golem)
    golemCache[golem.id] = golem
    if InventoryController._data then
        table.insert(InventoryController._data.Golems, golem)
    end
    if inventoryGui and inventoryGui.Enabled then
        InventoryController._BuildGolemList()
    end
end

return InventoryController
