-- Trade window: build an offer from your inventory, watch the other player's offer update
-- live, and confirm. Any change to either offer clears both confirmations (anti-scam).
-- Also shows your recent trade history.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local GolemNames   = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
local PetData      = require(game.ReplicatedStorage.Shared.Data.PetData)
local Portrait     = require(game.ReplicatedStorage.Shared.Modules.Portrait)
local MaterialIcon = require(game.ReplicatedStorage.Shared.Modules.MaterialIcon)

RemoteEvents.Load()

local W, H = 940, 580

-- ── State ─────────────────────────────────────────────────────────────────────
local tradeId       -- active trade, or nil
local view          -- latest TradeUpdated payload
local data          -- fresh copy of my data (inventory / golems)
local showingHistory = false

-- ── Frame ─────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "TradeMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 14
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
local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0, 12)
titleFill.Position = UDim2.new(0, 0, 1, -12)
titleFill.BackgroundColor3 = Theme.Colors.Panel
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local titleLbl = Theme.Label(titleBar, "Trade", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "TradeHeader")
titleLbl.Position = UDim2.new(0, 16, 0, 0)
titleLbl.Size = UDim2.new(0.6, 0, 1, 0)

local historyBtn = Theme.Button(titleBar, "History", Theme.Colors.PanelAlt, Theme.Colors.AccentBright, "HistoryButton")
historyBtn.Size = UDim2.new(0, 90, 0, 32)
historyBtn.Position = UDim2.new(1, -146, 0, 9)
historyBtn.TextSize = 13

local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)

-- ── Panes ─────────────────────────────────────────────────────────────────────
local function MakePane(name, title, x, width)
    local pane = Instance.new("Frame")
    pane.Name = name
    pane.Position = UDim2.new(0, x, 0, 60)
    pane.Size = UDim2.new(0, width, 0, 400)
    pane.BackgroundColor3 = Theme.Colors.Panel
    pane.BorderSizePixel = 0
    pane.Parent = container
    Theme.AddCorner(pane, Theme.Corner.Medium)
    local hdr = Theme.Label(pane, title, Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading, "Header")
    hdr.Position = UDim2.new(0, 10, 0, 6)
    hdr.Size = UDim2.new(1, -20, 0, 26)
    local scroll = Theme.ScrollFrame(pane, "List")
    scroll.Position = UDim2.new(0, 6, 0, 36)
    scroll.Size = UDim2.new(1, -12, 1, -42)
    Theme.AddListLayout(scroll, Enum.FillDirection.Vertical, 4)
    return pane, scroll, hdr
end

local yourPane, yourList, yourHdr   = MakePane("YourOffer",  "Your offer", 10, 280)
local theirPane, theirList, theirHdr = MakePane("TheirOffer", "Their offer", 300, 280)
local invPane, invList, invHdr       = MakePane("Inventory",  "Add from your inventory", 590, 340)

-- Confirmation status + buttons
local yourStatus = Theme.Label(container, "", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Heading, "YourConfirmLabel")
yourStatus.Position = UDim2.new(0, 14, 0, 468)
yourStatus.Size = UDim2.new(0, 270, 0, 22)
local theirStatus = Theme.Label(container, "", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Heading, "TheirConfirmLabel")
theirStatus.Position = UDim2.new(0, 304, 0, 468)
theirStatus.Size = UDim2.new(0, 270, 0, 22)

local WARN_DEFAULT = "Check every item carefully. Confirming is final once both players have confirmed. Any change clears both confirmations and locks Confirm for a few seconds."
local lockToken = 0
local warn = Theme.Label(container,
    WARN_DEFAULT,
    Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, "ConfirmLabel")
warn.Position = UDim2.new(0, 14, 0, 494)
warn.Size = UDim2.new(0, 566, 0, 40)
warn.TextYAlignment = Enum.TextYAlignment.Top

local acceptBtn = Theme.Button(container, "Confirm Trade", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "AcceptButton")
acceptBtn.Size = UDim2.new(0, 170, 0, 44)
acceptBtn.Position = UDim2.new(0, 590, 0, 470)
acceptBtn.TextSize = 15
local declineBtn = Theme.Button(container, "Cancel Trade", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "DeclineButton")
declineBtn.Size = UDim2.new(0, 160, 0, 44)
declineBtn.Position = UDim2.new(0, 770, 0, 470)
declineBtn.TextSize = 15

-- Empty state (opened from the sidebar with no trade running)
local idleLbl = Theme.Label(container,
    "No active trade.\nVisit another player's forge and press \"Request Trade\", or open History to see past trades.",
    Theme.TextSize.Heading, Theme.Colors.TextSecondary, Theme.Fonts.Body, "IdleLabel")
idleLbl.Position = UDim2.new(0, 60, 0, 200)
idleLbl.Size = UDim2.new(1, -120, 0, 120)
idleLbl.TextXAlignment = Enum.TextXAlignment.Center

-- History overlay
local historyFrame = Instance.new("Frame")
historyFrame.Name = "HistoryFrame"
historyFrame.Position = UDim2.new(0, 10, 0, 60)
historyFrame.Size = UDim2.new(1, -20, 1, -70)
historyFrame.BackgroundColor3 = Theme.Colors.Background
historyFrame.BorderSizePixel = 0
historyFrame.Visible = false
historyFrame.ZIndex = 5
historyFrame.Parent = container
local historyScroll = Theme.ScrollFrame(historyFrame, "HistoryList")
historyScroll.Size = UDim2.new(1, 0, 1, 0)
historyScroll.ZIndex = 5
Theme.AddListLayout(historyScroll, Enum.FillDirection.Vertical, 6)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function Clear(scroll)
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function ItemText(it)
    if it.type == "material" then return string.format("%s  x%d", it.name or it.id, it.qty) end
    return it.name or it.id
end

local function ItemColor(it)
    if it.rarity then return Theme.Colors[it.rarity] or Theme.Colors.TextPrimary end
    return Theme.Colors[it.element or ""] or Theme.Colors.TextPrimary
end

local function Row(parent, text, color, height, item)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, item and 46 or (height or 34))
    row.BackgroundColor3 = Theme.Colors.PanelAlt
    row.BorderSizePixel = 0
    row.Parent = parent
    Theme.AddCorner(row, Theme.Corner.Small)
    local lbl = Theme.Label(row, text, Theme.TextSize.Body, color or Theme.Colors.TextPrimary, Theme.Fonts.Heading)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Size = UDim2.new(1, -90, 1, 0)
    lbl.TextWrapped = false
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    -- a picture of what it is: the material mesh, or the Golem's face
    if item then
        local pic
        if item.type == "golem" then
            pic = Portrait.Golem(row, item, 36)
            pic.Position = UDim2.new(0, 6, 0.5, -18)
        elseif item.type == "pet" then
            pic = Portrait.Pet(row, { type = item.petType, variant = item.variant, grown = item.grown }, 36)
            pic.Position = UDim2.new(0, 6, 0.5, -18)
        else
            pic = Instance.new("Frame")
            pic.Size, pic.Position = UDim2.new(0, 36, 0, 36), UDim2.new(0, 6, 0.5, -18)
            pic.BackgroundColor3, pic.BackgroundTransparency, pic.BorderSizePixel = color or Theme.Colors.TextPrimary, 0.55, 0
            pic.Parent = row
            Theme.AddCorner(pic, Theme.Corner.Small)
            MaterialIcon.Overlay(pic, item.id)
        end
        lbl.Position = UDim2.new(0, 50, 0, 0)
        lbl.Size = UDim2.new(1, -130, 1, 0)
    end
    return row
end

-- What I could still add: inventory minus what I've already put in the offer
local function AvailableMaterials()
    local offered = {}
    for _, it in ipairs(view and view.yourItems or {}) do
        if it.type == "material" then offered[it.id] = (offered[it.id] or 0) + it.qty end
    end
    local list = {}
    for id, qty in pairs(data and data.Inventory or {}) do
        local def = MaterialData.Get(id)
        local free = qty - (offered[id] or 0)
        if free > 0 and def and def.tradeable ~= false then
            table.insert(list, { id = id, name = def.displayName, free = free, element = def.element })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function AvailableGolems()
    local offered = {}
    for _, it in ipairs(view and view.yourItems or {}) do
        if it.type == "golem" then offered[it.id] = true end
    end
    local list = {}
    for _, g in ipairs(data and data.Golems or {}) do
        if not g.deployed and not offered[g.id] then table.insert(list, g) end
    end
    return list
end

local function AvailablePets()
    local offered = {}
    for _, it in ipairs(view and view.yourItems or {}) do
        if it.type == "pet" then offered[it.id] = true end
    end
    local worn = {}
    for _, id in ipairs(data and data.EquippedPets or {}) do worn[id] = true end
    local list = {}
    for _, p in ipairs(data and data.OwnedPets or {}) do
        if not worn[p.id] and not offered[p.id] then table.insert(list, p) end
    end
    return list
end

-- ── Rendering ─────────────────────────────────────────────────────────────────
local function RenderInventory()
    Clear(invList)
    if not tradeId then return end

    for _, m in ipairs(AvailableMaterials()) do
        local row = Row(invList, string.format("%s  (%d)", m.name, m.free), Theme.Colors[m.element or ""] or Theme.Colors.TextPrimary, 36, { type = "material", id = m.id })
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0, 56, 0, 24)
        box.Position = UDim2.new(1, -140, 0.5, -12)
        box.BackgroundColor3 = Theme.Colors.Background
        box.TextColor3 = Theme.Colors.TextPrimary
        box.Font = Theme.Fonts.Mono
        box.TextSize = 13
        box.Text = "1"
        box.ClearTextOnFocus = true
        box.BorderSizePixel = 0
        box.Parent = row
        Theme.AddCorner(box, Theme.Corner.Small)
        local add = Theme.Button(row, "Add", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255))
        add.Size = UDim2.new(0, 60, 0, 24)
        add.Position = UDim2.new(1, -76, 0.5, -12)
        add.TextSize = 12
        add.MouseButton1Click:Connect(function()
            local qty = math.floor(tonumber(box.Text) or 0)
            if qty >= 1 and tradeId then
                RemoteEvents.AddTradeItem:FireServer(tradeId, { type = "material", id = m.id, qty = math.min(qty, m.free) })
            end
        end)
    end

    for _, p in ipairs(AvailablePets()) do
        local def = PetData.Get(p.type)
        local row = Row(invList, string.format("%s  [%s]", PetData.DisplayName(p), PetData.StageOf(p).id),
            def and Theme.Colors[def.rarity] or Theme.Colors.TextPrimary, 36,
            { type = "pet", petType = p.type, variant = p.variant, grown = p.grown })
        local add = Theme.Button(row, "Add", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255))
        add.Size = UDim2.new(0, 60, 0, 24)
        add.Position = UDim2.new(1, -76, 0.5, -12)
        add.TextSize = 12
        add.MouseButton1Click:Connect(function()
            if tradeId then RemoteEvents.AddTradeItem:FireServer(tradeId, { type = "pet", id = p.id }) end
        end)
    end

    for _, g in ipairs(AvailableGolems()) do
        local d = GolemNames.Describe(g)
        local row = Row(invList, string.format("%s  [%s]", d.name, d.rarity), d.rarityColor, 36, { type = "golem", element = g.element, tier = g.tier, variant = g.variant })
        local add = Theme.Button(row, "Add", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255))
        add.Size = UDim2.new(0, 60, 0, 24)
        add.Position = UDim2.new(1, -76, 0.5, -12)
        add.TextSize = 12
        add.MouseButton1Click:Connect(function()
            if tradeId then RemoteEvents.AddTradeItem:FireServer(tradeId, { type = "golem", id = g.id }) end
        end)
    end

    if #invList:GetChildren() <= 1 then   -- only the layout object
        local none = Theme.Label(invList, "Nothing tradeable in your inventory.", Theme.TextSize.Body, Theme.Colors.TextDim)
        none.Size = UDim2.new(1, -6, 0, 30)
    end
end

local function Render()
    local active = tradeId ~= nil and view ~= nil
    idleLbl.Visible = not active and not showingHistory
    for _, f in ipairs({ yourPane, theirPane, invPane, yourStatus, theirStatus, warn, acceptBtn, declineBtn }) do
        f.Visible = active and not showingHistory
    end
    historyFrame.Visible = showingHistory
    historyBtn.Text = showingHistory and "Back" or "History"
    if not active then
        titleLbl.Text = "Trade"
        return
    end

    titleLbl.Text = "Trade with " .. tostring(view.partnerName)
    theirHdr.Text = tostring(view.partnerName) .. "'s offer"

    Clear(yourList)
    for i, it in ipairs(view.yourItems) do
        local row = Row(yourList, ItemText(it), ItemColor(it), nil, it)
        local rm = Theme.Button(row, "Remove", Theme.Colors.PanelAlt, Theme.Colors.Danger)
        rm.Size = UDim2.new(0, 66, 0, 22)
        rm.Position = UDim2.new(1, -72, 0.5, -11)
        rm.TextSize = 11
        rm.MouseButton1Click:Connect(function() RemoteEvents.RemoveTradeItem:FireServer(tradeId, i) end)
    end
    if #view.yourItems == 0 then
        local e = Theme.Label(yourList, "Add items from the right.", Theme.TextSize.Body, Theme.Colors.TextDim)
        e.Size = UDim2.new(1, -6, 0, 28)
    end

    Clear(theirList)
    for _, it in ipairs(view.theirItems) do Row(theirList, ItemText(it), ItemColor(it), nil, it) end
    if #view.theirItems == 0 then
        local e = Theme.Label(theirList, "Waiting for them to add items.", Theme.TextSize.Body, Theme.Colors.TextDim)
        e.Size = UDim2.new(1, -6, 0, 28)
    end

    yourStatus.Text = view.youConfirmed and "You: CONFIRMED" or "You: not confirmed"
    yourStatus.TextColor3 = view.youConfirmed and Theme.Colors.Success or Theme.Colors.TextSecondary
    theirStatus.Text = view.theyConfirmed and (tostring(view.partnerName) .. ": CONFIRMED") or (tostring(view.partnerName) .. ": reviewing")
    theirStatus.TextColor3 = view.theyConfirmed and Theme.Colors.Success or Theme.Colors.TextSecondary

    -- the Confirm button is locked for a few seconds after ANY change to an offer, so nothing can be swapped under your finger
    lockToken += 1
    local myToken = lockToken
    local lockEnd = os.clock() + (view.lockSeconds or 0)
    local function paintConfirm()
        local left = math.ceil(lockEnd - os.clock())
        if view.youConfirmed then
            acceptBtn.Text = "Waiting for them..."
            acceptBtn.BackgroundColor3 = Theme.Colors.PanelAlt
        elseif left > 0 then
            acceptBtn.Text = string.format("Check the offer... %d", left)
            acceptBtn.BackgroundColor3 = Theme.Colors.PanelAlt
        else
            acceptBtn.Text = view.warning and "Confirm anyway" or "Confirm Trade"
            acceptBtn.BackgroundColor3 = view.warning and Theme.Colors.Danger or Theme.Colors.Success
        end
        acceptBtn.Active = not view.youConfirmed and left <= 0
        acceptBtn.AutoButtonColor = acceptBtn.Active
    end
    paintConfirm()
    if (view.lockSeconds or 0) > 0 and not view.youConfirmed then
        task.spawn(function()
            while lockToken == myToken and os.clock() < lockEnd do task.wait(0.25) paintConfirm() end
            if lockToken == myToken then paintConfirm() end
        end)
    end
    -- a warning about THIS trade (giving for nothing / lopsided) in red under the lists; otherwise the usual reminder
    warn.Text = view.warning and ("WARNING: " .. view.warning .. " Confirming twice means you are sure.") or WARN_DEFAULT
    warn.TextColor3 = view.warning and Theme.Colors.Danger or Theme.Colors.TextDim

    RenderInventory()
end

local function RenderHistory()
    Clear(historyScroll)
    local history = RemoteEvents.GetTradeHistory:InvokeServer() or {}
    if #history == 0 then
        local none = Theme.Label(historyScroll, "No trades yet.", Theme.TextSize.Heading, Theme.Colors.TextDim)
        none.Size = UDim2.new(1, -10, 0, 40)
    end
    for _, h in ipairs(history) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -10, 0, 64)
        row.BackgroundColor3 = Theme.Colors.Panel
        row.BorderSizePixel = 0
        row.Parent = historyScroll
        Theme.AddCorner(row, Theme.Corner.Small)
        local head = Theme.Label(row, string.format("%s  -  %s %s", os.date("%d %b %H:%M", h.time), h.market and "Market:" or "with", tostring(h.partner)),
            Theme.TextSize.Body, Theme.Colors.AccentBright, Theme.Fonts.Heading)
        head.Position = UDim2.new(0, 10, 0, 4)
        head.Size = UDim2.new(1, -20, 0, 20)
        local body = Theme.Label(row,
            "You gave: " .. (#h.gave > 0 and table.concat(h.gave, ", ") or "nothing")
            .. "\nYou got: " .. (#h.got > 0 and table.concat(h.got, ", ") or "nothing"),
            Theme.TextSize.Small, Theme.Colors.TextPrimary, Theme.Fonts.Body)
        body.Position = UDim2.new(0, 10, 0, 26)
        body.Size = UDim2.new(1, -20, 0, 34)
        body.TextYAlignment = Enum.TextYAlignment.Top
    end
end

local function RefreshData()
    local fresh = RemoteEvents.GetPlayerData:InvokeServer()
    if fresh then data = fresh end
end

-- ── Buttons ───────────────────────────────────────────────────────────────────
local function CloseWindow()
    gui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(function()
    if tradeId then RemoteEvents.DeclineTrade:FireServer(tradeId) end   -- closing mid-trade cancels it
    CloseWindow()
end)
declineBtn.MouseButton1Click:Connect(function()
    if tradeId then RemoteEvents.DeclineTrade:FireServer(tradeId) end
end)
acceptBtn.MouseButton1Click:Connect(function()
    if tradeId and view and not view.youConfirmed then RemoteEvents.AcceptTrade:FireServer(tradeId) end
end)
historyBtn.MouseButton1Click:Connect(function()
    showingHistory = not showingHistory
    if showingHistory then RenderHistory() end
    Render()
end)

-- ── Server events ─────────────────────────────────────────────────────────────
RemoteEvents.TradeOffer.OnClientEvent:Connect(function(id, err)
    if err or not id then return end
    tradeId = id
    view = nil
    showingHistory = false
    task.spawn(RefreshData)
    gui.Enabled = true
    Render()
end)

RemoteEvents.TradeUpdated.OnClientEvent:Connect(function(v)
    if not v or (tradeId and v.tradeId ~= tradeId) then return end
    tradeId = v.tradeId
    view = v
    Render()
end)

RemoteEvents.TradeClosed.OnClientEvent:Connect(function(id, reason)
    if tradeId and (id == "" or id == tradeId) then
        tradeId, view = nil, nil
        Render()
        task.spawn(RefreshData)
    end
end)

RemoteEvents.TradeCompleted.OnClientEvent:Connect(function()
    tradeId, view = nil, nil
    Render()
    task.spawn(RefreshData)
    CloseWindow()
end)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then
        task.spawn(function()
            RefreshData()
            if showingHistory then RenderHistory() end
            Render()
        end)
    end
end)

Render()
