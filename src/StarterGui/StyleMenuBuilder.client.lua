-- Style menu: choose what your forge and Golems look like, pick a title, set who can visit your
-- forge, jump back to it, and browse the cosmetic store. Cosmetics are purely visual (spec 3.3).

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer        = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local CosmeticData = require(game.ReplicatedStorage.Shared.Data.CosmeticData)
local ProductData  = require(game.ReplicatedStorage.Shared.Data.ProductData)

RemoteEvents.Load()

local W, H = 840, 580
local TABS = {
    { id = "ForgeSkin",       label = "Forge Skin" },
    { id = "ForgeDecoration", label = "Decoration" },
    { id = "GolemAccessory",  label = "Golem Gear" },
    { id = "GolemSkin",       label = "Golem Skins" },
    { id = "ParticleEffect",  label = "Effects" },
    { id = "ForgeEffect",     label = "Forge Effects" },
    { id = "Title",           label = "Titles" },
    { id = "Access",          label = "Forge Access" },
    { id = "Store",           label = "Store" },
}
local tab = "ForgeSkin"
local data

-- ── Window ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "StyleMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 11
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
local title = Theme.Label(titleBar, "Style", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(0.6, 0, 1, 0)
local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

-- Tab column
local tabCol = Instance.new("Frame")
tabCol.Position = UDim2.new(0, 8, 0, 58)
tabCol.Size = UDim2.new(0, 170, 1, -66)
tabCol.BackgroundColor3 = Theme.Colors.Panel
tabCol.BorderSizePixel = 0
tabCol.Parent = container
Theme.AddCorner(tabCol, Theme.Corner.Medium)
Theme.AddPadding(tabCol, 8, 8, 8, 8)
Theme.AddListLayout(tabCol, Enum.FillDirection.Vertical, 6)
local tabButtons = {}
for _, t in ipairs(TABS) do
    local b = Theme.Button(tabCol, t.label, Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, t.id .. "Tab")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.TextSize = 14
    tabButtons[t.id] = b
end

-- Content
local content = Theme.ScrollFrame(container, "Content")
content.Position = UDim2.new(0, 188, 0, 58)
content.Size = UDim2.new(1, -196, 1, -66)
Theme.AddListLayout(content, Enum.FillDirection.Vertical, 6)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function Clear()
    for _, c in ipairs(content:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function Note(text, height)
    local l = Theme.Label(content, text, Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    l.Size = UDim2.new(1, -8, 0, height or 40)
    l.TextYAlignment = Enum.TextYAlignment.Top
    return l
end

local function Row(name, sub, color, buttonText, buttonColor, onClick, enabled)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 54)
    row.BackgroundColor3 = Theme.Colors.Panel
    row.BorderSizePixel = 0
    row.Parent = content
    Theme.AddCorner(row, Theme.Corner.Small)

    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.new(0, 6, 1, -14)
    swatch.Position = UDim2.new(0, 6, 0, 7)
    swatch.BackgroundColor3 = color
    swatch.BorderSizePixel = 0
    swatch.Parent = row
    Theme.AddCorner(swatch, UDim.new(0, 3))

    local n = Theme.Label(row, name, Theme.TextSize.Heading, Theme.Colors.TextPrimary, Theme.Fonts.Heading)
    n.Position = UDim2.new(0, 22, 0, 6)
    n.Size = UDim2.new(1, -170, 0, 22)
    local s = Theme.Label(row, sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    s.Position = UDim2.new(0, 22, 0, 30)
    s.Size = UDim2.new(1, -170, 0, 18)

    if buttonText then
        local b = Theme.Button(row, buttonText, buttonColor, Color3.fromRGB(255, 255, 255))
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, -10, 0.5, 0)
        b.Size = UDim2.new(0, 120, 0, 32)
        b.TextSize = 13
        b.AutoButtonColor = enabled ~= false
        b.MouseButton1Click:Connect(function()
            if enabled ~= false and onClick then onClick() end
        end)
    end
    return row
end

local function Reload()
    local fresh = RemoteEvents.GetPlayerData:InvokeServer()
    if fresh then data = fresh end
    for id, b in pairs(tabButtons) do
        local on = id == tab
        b.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        b.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary
    end
    Clear()
    if not data then return end
    local equipped = data.Equipped or {}

    if tab == "Access" then
        local friendsOnly = data.Settings and data.Settings.ForgeFriendsOnly or false
        Row("Who can visit your forge", friendsOnly and "Friends only" or "Everyone", Theme.Colors.Info,
            friendsOnly and "Open to all" or "Friends only", Theme.Colors.Accent, function()
                RemoteEvents.SetForgeAccess:FireServer(not friendsOnly)
                task.delay(0.4, Reload)
            end)
        Row("Go to my forge", "Teleport your character to your forge plot", Theme.Colors.Ember, "Teleport", Theme.Colors.Success, function()
            RemoteEvents.GoToMyForge:FireServer()
            gui.Enabled = false
        end)
        Note("Visitors can always see your forge level and Golems. Friends-only forges turn strangers away at the edge of the plot.", 50)
        return
    end

    if tab == "Store" then
        Note("Cosmetics are visual only: they never change stats. Everything here is optional.", 30)
        local keys = {}
        for key, p in pairs(ProductData.Products) do
            if p.cosmeticId then table.insert(keys, key) end
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local p = ProductData.Products[key]
            local d = CosmeticData.Describe(p.cosmeticId)
            local owned = false
            for _, id in ipairs(data.OwnedCosmetics or {}) do if id == p.cosmeticId then owned = true end end
            Row(p.displayName, d.label .. ": " .. CosmeticData.Blurb(p.cosmeticId) .. "  -  " .. p.robux .. " Robux", d.color,
                owned and "Owned" or (ProductData.IsAvailable(key) and "Buy" or "Coming soon"),
                owned and Theme.Colors.PanelAlt or Theme.Colors.Accent,
                function() pcall(function() MarketplaceService:PromptProductPurchase(LocalPlayer, p.id) end) end,
                not owned and ProductData.IsAvailable(key))
        end
        return
    end

    -- Owned items for this slot (+ "None" to clear it)
    local items = {}
    if tab == "Title" then
        local seen = {}
        for _, t in ipairs(data.Titles or {}) do
            if not seen[t] then seen[t] = true table.insert(items, { key = "T:" .. t, name = t, sub = "Earned title. " .. CosmeticData.Blurb("TitleBadge_x"), color = Theme.Colors.Gold, text = t }) end
        end
        for _, id in ipairs(data.OwnedCosmetics or {}) do
            local d = CosmeticData.Describe(id)
            if d.slot == "Title" and not seen[d.name] then
                seen[d.name] = true
                table.insert(items, { key = id, name = d.name, sub = CosmeticData.Blurb(id), color = d.color, text = d.name })
            end
        end
    else
        for _, id in ipairs(data.OwnedCosmetics or {}) do
            local d = CosmeticData.Describe(id)
            if d.slot == tab then table.insert(items, { key = id, name = d.name, sub = CosmeticData.Blurb(id), color = d.color, text = id }) end
        end
    end
    table.sort(items, function(a, b) return a.name < b.name end)

    local current = equipped[tab]
    Row("None", "Use the default look (nothing equipped)", Theme.Colors.TextDim, current and "Equip" or "Equipped",
        current and Theme.Colors.Accent or Theme.Colors.PanelAlt, function()
            RemoteEvents.EquipCosmetic:FireServer(tab, nil)
            task.delay(0.4, Reload)
        end, current ~= nil)

    for _, it in ipairs(items) do
        local isOn = current == it.text
        Row(it.name, it.sub, it.color, isOn and "Equipped" or "Equip",
            isOn and Theme.Colors.PanelAlt or Theme.Colors.Accent, function()
                RemoteEvents.EquipCosmetic:FireServer(tab, it.key)
                task.delay(0.4, Reload)
            end, not isOn)
    end
    if #items == 0 then
        Note("You don't own any yet. Earn them from levels, the Season Pass and achievements, or find them in the Store.", 50)
    end
end

for id, b in pairs(tabButtons) do
    b.MouseButton1Click:Connect(function()
        tab = id
        Reload()
    end)
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then
        task.spawn(Reload)
        RemoteEvents.MarkCosmeticsSeen:FireServer()     -- clears the NEW badge on the sidebar
    end
end)
