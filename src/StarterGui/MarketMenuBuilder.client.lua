-- Forge Market: browse materials and Golems other players have listed, buy them with Ember
-- Coins, list your own, and manage / cancel your listings. Everything is decided by the server;
-- this window only asks and displays.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local GolemData    = require(game.ReplicatedStorage.Shared.Data.GolemData)
local GameConfig   = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local GolemNames   = require(game.ReplicatedStorage.Shared.Modules.GolemNames)

RemoteEvents.Load()

local W, H = 820, 600
local RARITY = {
    Common = Theme.Colors.Common, Uncommon = Theme.Colors.Uncommon, Rare = Theme.Colors.Rare,
    Epic = Theme.Colors.Epic, Legendary = Theme.Colors.Legendary,
}

local tab = "material"        -- "material" | "golem" | "mine"
local data                     -- my data (coins, inventory, golems)

-- ── Window ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "MarketMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 12
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local scrim = Instance.new("Frame")
scrim.Size = UDim2.new(1, 0, 1, 0)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.5
scrim.BorderSizePixel = 0
scrim.Parent = gui

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, W, 0, H)
container.BackgroundColor3 = Theme.Colors.Background
container.BorderSizePixel = 0
container.Parent = gui
Theme.AddCorner(container, Theme.Corner.Large)
ScaleUI.Apply(container, W, H)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Theme.Colors.Panel
titleBar.BorderSizePixel = 0
titleBar.Parent = container
Theme.AddCorner(titleBar, Theme.Corner.Large)
local tfill = Instance.new("Frame")
tfill.Size = UDim2.new(1, 0, 0, 12)
tfill.Position = UDim2.new(0, 0, 1, -12)
tfill.BackgroundColor3 = Theme.Colors.Panel
tfill.BorderSizePixel = 0
tfill.Parent = titleBar

local title = Theme.Label(titleBar, "Forge Market", Theme.TextSize.Title, Theme.Colors.Gold, Theme.Fonts.Title, "Title")
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(0.4, 0, 1, 0)
local coinsLbl = Theme.Label(titleBar, "", Theme.TextSize.Heading, Theme.Colors.Gold, Theme.Fonts.Heading, "CoinsLabel")
coinsLbl.Position = UDim2.new(0.42, 0, 0, 0)
coinsLbl.Size = UDim2.new(0.4, -50, 1, 0)
coinsLbl.TextXAlignment = Enum.TextXAlignment.Right
local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Tabs + actions
local bar = Instance.new("Frame")
bar.Name = "FilterBar"
bar.Position = UDim2.new(0, 8, 0, 56)
bar.Size = UDim2.new(1, -16, 0, 44)
bar.BackgroundColor3 = Theme.Colors.Panel
bar.BorderSizePixel = 0
bar.Parent = container
Theme.AddCorner(bar, Theme.Corner.Small)

local function TabButton(text, x, name)
    local b = Theme.Button(bar, text, Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, name)
    b.Size = UDim2.new(0, 110, 0, 30)
    b.Position = UDim2.new(0, x, 0.5, -15)
    return b
end
local matTab   = TabButton("Materials", 8,   "MaterialsTab")
local golemTab = TabButton("Golems",    124, "GolemsTab")
local mineTab  = TabButton("My Listings", 240, "MyListingsTab")
mineTab.Size = UDim2.new(0, 130, 0, 30)

local refreshBtn = Theme.Button(bar, "Refresh", Theme.Colors.PanelAlt, Theme.Colors.TextPrimary, "RefreshButton")
refreshBtn.Size = UDim2.new(0, 90, 0, 30)
refreshBtn.Position = UDim2.new(1, -220, 0.5, -15)
local listBtn = Theme.Button(bar, "+ List Item", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "ListItemButton")
listBtn.Size = UDim2.new(0, 120, 0, 30)
listBtn.Position = UDim2.new(1, -124, 0.5, -15)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, -16, 0, 24)
header.Position = UDim2.new(0, 8, 0, 106)
header.BackgroundTransparency = 1
header.Parent = container
local function Col(text, x, w, align)
    local l = Theme.Label(header, text, Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Heading)
    l.Position = UDim2.new(0, x, 0, 0)
    l.Size = UDim2.new(0, w, 1, 0)
    l.TextXAlignment = align or Enum.TextXAlignment.Left
end
Col("Item", 10, 320)
Col("Seller", 340, 160)
Col("Price", 500, 120, Enum.TextXAlignment.Right)

local scroll = Theme.ScrollFrame(container, "ListingScroll")
scroll.Position = UDim2.new(0, 8, 0, 132)
scroll.Size = UDim2.new(1, -16, 1, -140)
Theme.AddListLayout(scroll, Enum.FillDirection.Vertical, 4)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function Clear(parent)
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function SetTabStyle()
    for name, btn in pairs({ material = matTab, golem = golemTab, mine = mineTab }) do
        local on = name == tab
        btn.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary
    end
end

local function RefreshCoins()
    coinsLbl.Text = data and (Utils.FormatNumber(data.EmberCoins or 0) .. " coins") or ""
end

local function RefreshData()
    local fresh = RemoteEvents.GetPlayerData:InvokeServer()
    if fresh then data = fresh end
    RefreshCoins()
end

local function ItemLine(listing)
    local it = listing.item
    if it.type == "material" then
        local def = MaterialData.Get(it.id)
        return string.format("%s  x%d", it.name or (def and def.displayName) or it.id, it.qty),
               RARITY[def and def.rarity or "Common"] or Theme.Colors.TextPrimary, nil
    end
    local g = listing.golem
    local d = g and GolemNames.Describe(g)
    local stats = g and GolemData.ComputeStats(g.element, g.tier, g.fusionBonus, g.quality, g.variant)
    local sub = stats and string.format("%d/hr   carry %d   luck %d%%", stats.miningRate, stats.carryCapacity,
        math.floor(stats.luck * 100 + 0.5)) or nil
    return d and string.format("%s   [%s]", d.name, d.rarity) or it.name or "Golem",
           d and d.rarityColor or Theme.Colors.TextPrimary, sub
end

-- ── Listing rows ──────────────────────────────────────────────────────────────
local function Render(listings)
    Clear(scroll)
    if #listings == 0 then
        local none = Theme.Label(scroll,
            tab == "mine" and "You have nothing listed." or "No listings here yet. Be the first to list something!",
            Theme.TextSize.Body, Theme.Colors.TextDim)
        none.Size = UDim2.new(1, -8, 0, 40)
        none.TextXAlignment = Enum.TextXAlignment.Center
        return
    end
    for _, listing in ipairs(listings) do
        local text, color, sub = ItemLine(listing)
        local row = Instance.new("Frame")
        row.Name = listing.id
        row.Size = UDim2.new(1, -8, 0, 56)
        row.BackgroundColor3 = Theme.Colors.Panel
        row.BorderSizePixel = 0
        row.Parent = scroll
        Theme.AddCorner(row, Theme.Corner.Small)

        local bar2 = Instance.new("Frame")
        bar2.Size = UDim2.new(0, 4, 1, -12)
        bar2.Position = UDim2.new(0, 4, 0, 6)
        bar2.BackgroundColor3 = color
        bar2.BorderSizePixel = 0
        bar2.Parent = row

        local name = Theme.Label(row, text, Theme.TextSize.Heading, color, Theme.Fonts.Heading)
        name.Position = UDim2.new(0, 16, 0, sub and 6 or 0)
        name.Size = UDim2.new(0, 320, 0, sub and 24 or 56)
        if sub then
            local s = Theme.Label(row, sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Mono)
            s.Position = UDim2.new(0, 16, 0, 30)
            s.Size = UDim2.new(0, 320, 0, 18)
        end

        local seller = Theme.Label(row, tostring(listing.sellerName or "?"), Theme.TextSize.Body, Theme.Colors.TextSecondary)
        seller.Position = UDim2.new(0, 340, 0, 0)
        seller.Size = UDim2.new(0, 160, 1, 0)

        local price = Theme.Label(row, Utils.FormatNumber(listing.priceCoins), Theme.TextSize.Heading, Theme.Colors.Gold, Theme.Fonts.Heading)
        price.Position = UDim2.new(0, 500, 0, 0)
        price.Size = UDim2.new(0, 120, 1, 0)
        price.TextXAlignment = Enum.TextXAlignment.Right

        local mine = listing.sellerId == LocalPlayer.UserId
        local btn = Theme.Button(row, mine and "Cancel" or "Buy",
            mine and Theme.Colors.PanelAlt or Theme.Colors.Success,
            mine and Theme.Colors.Danger or Color3.fromRGB(255, 255, 255))
        btn.Size = UDim2.new(0, 84, 0, 32)
        btn.Position = UDim2.new(1, -92, 0.5, -16)
        btn.MouseButton1Click:Connect(function()
            btn.Active = false
            btn.Text = "..."
            if mine then
                RemoteEvents.CancelListing:FireServer(listing.id)
            else
                RemoteEvents.BuyFromMarket:FireServer(listing.id)
            end
        end)
    end
end

local function Reload()
    SetTabStyle()
    RefreshData()
    local listings
    if tab == "mine" then
        listings = RemoteEvents.GetMyListings:InvokeServer() or {}
    else
        listings = RemoteEvents.GetMarketListings:InvokeServer(tab, nil) or {}
    end
    Render(listings)
end

matTab.MouseButton1Click:Connect(function() tab = "material" Reload() end)
golemTab.MouseButton1Click:Connect(function() tab = "golem" Reload() end)
mineTab.MouseButton1Click:Connect(function() tab = "mine" Reload() end)
refreshBtn.MouseButton1Click:Connect(Reload)

-- ── "List an item" dialog ─────────────────────────────────────────────────────
local dlg = Instance.new("Frame")
dlg.Name = "ListDialog"
dlg.Size = UDim2.new(1, 0, 1, 0)
dlg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dlg.BackgroundTransparency = 0.35
dlg.BorderSizePixel = 0
dlg.Visible = false
dlg.ZIndex = 10
dlg.Active = true
dlg.Parent = container

local box = Instance.new("Frame")
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.Position = UDim2.new(0.5, 0, 0.5, 0)
box.Size = UDim2.new(0, 520, 0, 470)
box.BackgroundColor3 = Theme.Colors.Background
box.BorderSizePixel = 0
box.ZIndex = 11
box.Parent = dlg
Theme.AddCorner(box, Theme.Corner.Large)

local dTitle = Theme.Label(box, "List an item", Theme.TextSize.Title, Theme.Colors.Gold, Theme.Fonts.Title)
dTitle.Position = UDim2.new(0, 16, 0, 10)
dTitle.Size = UDim2.new(1, -60, 0, 30)
dTitle.ZIndex = 12
local dClose = Theme.Button(box, "X", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255))
dClose.Size = UDim2.new(0, 32, 0, 32)
dClose.Position = UDim2.new(1, -42, 0, 8)
dClose.ZIndex = 12
dClose.MouseButton1Click:Connect(function() dlg.Visible = false end)

local dScroll = Theme.ScrollFrame(box, "PickList")
dScroll.Position = UDim2.new(0, 10, 0, 48)
dScroll.Size = UDim2.new(1, -20, 0, 250)
dScroll.ZIndex = 12
Theme.AddListLayout(dScroll, Enum.FillDirection.Vertical, 4)

local qtyLbl = Theme.Label(box, "Quantity", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Heading)
qtyLbl.Position = UDim2.new(0, 16, 0, 310)
qtyLbl.Size = UDim2.new(0, 90, 0, 30)
qtyLbl.ZIndex = 12
local qtyBox = Instance.new("TextBox")
qtyBox.Size = UDim2.new(0, 110, 0, 30)
qtyBox.Position = UDim2.new(0, 110, 0, 310)
qtyBox.BackgroundColor3 = Theme.Colors.Panel
qtyBox.TextColor3 = Theme.Colors.TextPrimary
qtyBox.Font = Theme.Fonts.Mono
qtyBox.TextSize = 15
qtyBox.Text = "1"
qtyBox.BorderSizePixel = 0
qtyBox.ZIndex = 12
qtyBox.Parent = box
Theme.AddCorner(qtyBox, Theme.Corner.Small)

local priceLbl = Theme.Label(box, "Price (coins)", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Heading)
priceLbl.Position = UDim2.new(0, 16, 0, 350)
priceLbl.Size = UDim2.new(0, 100, 0, 30)
priceLbl.ZIndex = 12
local priceBox = Instance.new("TextBox")
priceBox.Size = UDim2.new(0, 110, 0, 30)
priceBox.Position = UDim2.new(0, 110, 0, 350)
priceBox.BackgroundColor3 = Theme.Colors.Panel
priceBox.TextColor3 = Theme.Colors.Gold
priceBox.Font = Theme.Fonts.Mono
priceBox.TextSize = 15
priceBox.Text = "100"
priceBox.BorderSizePixel = 0
priceBox.ZIndex = 12
priceBox.Parent = box
Theme.AddCorner(priceBox, Theme.Corner.Small)

local netLbl = Theme.Label(box, "", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body)
netLbl.Position = UDim2.new(0, 240, 0, 340)
netLbl.Size = UDim2.new(0, 270, 0, 50)
netLbl.ZIndex = 12
netLbl.TextYAlignment = Enum.TextYAlignment.Center

local confirm = Theme.Button(box, "List it", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "ConfirmButton")
confirm.Size = UDim2.new(1, -20, 0, 40)
confirm.Position = UDim2.new(0, 10, 1, -50)
confirm.ZIndex = 12
confirm.TextSize = 16

local pick   -- { type, id, max }
local function UpdateNet()
    local price = math.floor(tonumber(priceBox.Text) or 0)
    local net = math.floor(price * (1 - GameConfig.MARKET_LISTING_FEE_PERCENT))
    netLbl.Text = price > 0 and string.format("Fee %d%%  -  you receive %s coins",
        GameConfig.MARKET_LISTING_FEE_PERCENT * 100, Utils.FormatNumber(net)) or "Enter a price"
end
priceBox:GetPropertyChangedSignal("Text"):Connect(UpdateNet)

local function BuildPickList()
    Clear(dScroll)
    pick = nil
    local rows = {}
    local function AddRow(text, color, info)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -6, 0, 40)
        row.BackgroundColor3 = Theme.Colors.Panel
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.ZIndex = 12
        row.Parent = dScroll
        Theme.AddCorner(row, Theme.Corner.Small)
        local l = Theme.Label(row, text, Theme.TextSize.Body, color, Theme.Fonts.Heading)
        l.Position = UDim2.new(0, 12, 0, 0)
        l.Size = UDim2.new(1, -24, 1, 0)
        l.ZIndex = 13
        row.MouseButton1Click:Connect(function()
            for _, r in ipairs(rows) do r.BackgroundColor3 = Theme.Colors.Panel end
            row.BackgroundColor3 = Theme.Colors.PanelAlt
            pick = info
            qtyBox.Text = "1"
            qtyBox.TextEditable = info.type == "material"
        end)
        table.insert(rows, row)
    end

    if tab ~= "golem" then
        local ids = {}
        for id, qty in pairs(data.Inventory or {}) do
            local def = MaterialData.Get(id)
            if qty > 0 and def and def.tradeable ~= false then table.insert(ids, id) end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local def = MaterialData.Get(id)
            AddRow(string.format("%s   (you have %d)", def.displayName, data.Inventory[id]),
                RARITY[def.rarity] or Theme.Colors.TextPrimary, { type = "material", id = id, max = data.Inventory[id] })
        end
    end
    if tab == "golem" or tab == "mine" then
        for _, g in ipairs(data.Golems or {}) do
            if not g.deployed then
                local d = GolemNames.Describe(g)
                AddRow(string.format("%s   [%s]", d.name, d.rarity), d.rarityColor, { type = "golem", id = g.id, max = 1 })
            end
        end
    end
    if #rows == 0 then
        local none = Theme.Label(dScroll, "Nothing available to list here.", Theme.TextSize.Body, Theme.Colors.TextDim)
        none.Size = UDim2.new(1, -6, 0, 40)
        none.ZIndex = 12
    end
end

listBtn.MouseButton1Click:Connect(function()
    RefreshData()
    BuildPickList()
    UpdateNet()
    dlg.Visible = true
end)

confirm.MouseButton1Click:Connect(function()
    if not pick then return end
    local price = math.floor(tonumber(priceBox.Text) or 0)
    if price < 1 then return end
    local item = { type = pick.type, id = pick.id }
    if pick.type == "material" then
        item.qty = math.clamp(math.floor(tonumber(qtyBox.Text) or 1), 1, pick.max)
    end
    RemoteEvents.ListOnMarket:FireServer(item, price)
    dlg.Visible = false
end)

-- ── Server results ────────────────────────────────────────────────────────────
RemoteEvents.PurchaseResult.OnClientEvent:Connect(function()
    if gui.Enabled then task.delay(0.2, Reload) end
end)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then task.spawn(Reload) else dlg.Visible = false end
end)

SetTabStyle()
