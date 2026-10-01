-- Forge Builder menu: buy pieces (mine cart, racks, furnaces ...) from the shop that restocks every few minutes,
-- place them on your own forge plot where you are standing, and pick them up again. Coins only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Theme          = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI        = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents   = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local ForgeBuildData = require(game.ReplicatedStorage.Shared.Data.ForgeBuildData)
local AscensionData  = require(game.ReplicatedStorage.Shared.Data.AscensionData)
local Utils          = require(game.ReplicatedStorage.Shared.Modules.Utils)

RemoteEvents.Load()

local W, H = 760, 540
local tab = "Shop"
local info

local RARITY_COLOR = {
    Common = Theme.Colors.TextSecondary, Uncommon = Theme.Colors.Success, Rare = Theme.Colors.Info, Epic = Theme.Colors.Epic,
}

local STAT_NAMES = { rate = "mining speed", carry = "carry capacity", eff = "efficiency", wear = "less wear", luck = "luck" }
local ForgeBuildStatNames = { mining = "mining speed", carry = "carry capacity", luck = "luck", coins = "daily coins" }

-- ── Window ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "BuildMenu"
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
local title = Theme.Label(titleBar, "Build", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(0.4, 0, 1, 0)
local coinsLbl = Theme.Label(titleBar, "", Theme.TextSize.Heading, Theme.Colors.Gold, Theme.Fonts.Heading, "Coins")
coinsLbl.AnchorPoint = Vector2.new(1, 0)
coinsLbl.Position = UDim2.new(1, -60, 0, 0)
coinsLbl.Size = UDim2.new(0.4, 0, 1, 0)
coinsLbl.TextXAlignment = Enum.TextXAlignment.Right
local closeBtn = Theme.Button(titleBar, "X", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "CloseButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

local tabCol = Instance.new("Frame")
tabCol.Position = UDim2.new(0, 8, 0, 58)
tabCol.Size = UDim2.new(0, 150, 1, -66)
tabCol.BackgroundColor3 = Theme.Colors.Panel
tabCol.BorderSizePixel = 0
tabCol.Parent = container
Theme.AddCorner(tabCol, Theme.Corner.Medium)
Theme.AddPadding(tabCol, 8, 8, 8, 8)
Theme.AddListLayout(tabCol, Enum.FillDirection.Vertical, 6)
local tabButtons = {}
for _, t in ipairs({ { "Shop", "Shop" }, { "Mine", "My Pieces" }, { "Placed", "On My Forge" }, { "Ascend", "Ascension" } }) do
    local b = Theme.Button(tabCol, t[2], Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, t[1] .. "Tab")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.TextSize = 13
    tabButtons[t[1]] = b
end
local homeBtn = Theme.Button(tabCol, "Go to my forge", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "GoHome")
homeBtn.Size = UDim2.new(1, 0, 0, 38)
homeBtn.TextSize = 13
homeBtn.MouseButton1Click:Connect(function() RemoteEvents.GoToMyForge:FireServer() gui.Enabled = false end)

local content = Theme.ScrollFrame(container, "Content")
content.Position = UDim2.new(0, 166, 0, 58)
content.Size = UDim2.new(1, -174, 1, -92)
Theme.AddListLayout(content, Enum.FillDirection.Vertical, 6)

local statusLbl = Theme.Label(container, "", Theme.TextSize.Body, Theme.Colors.Danger, Theme.Fonts.Heading, "Status")
statusLbl.AnchorPoint = Vector2.new(0, 1)
statusLbl.Position = UDim2.new(0, 170, 1, -8)
statusLbl.Size = UDim2.new(1, -182, 0, 22)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local function Say(text, good)
    statusLbl.Text = text or ""
    statusLbl.TextColor3 = good and Theme.Colors.Success or Theme.Colors.Danger
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function Clear()
    for _, c in ipairs(content:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function Note(text, height, color)
    local l = Theme.Label(content, text, Theme.TextSize.Body, color or Theme.Colors.TextSecondary, Theme.Fonts.Body)
    l.Size = UDim2.new(1, -8, 0, height or 40)
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    return l
end

local function Row(name, sub, color, buttons, height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, height or 58)
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
    n.Position = UDim2.new(0, 22, 0, 4)
    n.Size = UDim2.new(1, -140 * math.max(1, #buttons) - 20, 0, 22)
    local s = Theme.Label(row, sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    s.Position = UDim2.new(0, 22, 0, 26)
    s.Size = UDim2.new(1, -140 * math.max(1, #buttons) - 20, 0, (height or 58) - 28)
    s.TextWrapped = true
    s.TextYAlignment = Enum.TextYAlignment.Top
    for i, spec in ipairs(buttons) do
        local b = Theme.Button(row, spec.text, spec.color, Color3.fromRGB(255, 255, 255))
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, -10 - (i - 1) * 124, 0.5, 0)
        b.Size = UDim2.new(0, 114, 0, 32)
        b.TextSize = 13
        b.AutoButtonColor = spec.enabled ~= false
        b.MouseButton1Click:Connect(function() if spec.enabled ~= false then spec.onClick() end end)
    end
    return row
end

local function PerkText(it)
    if not it.perk then return it.blurb end
    local bits = {}
    for stat, v in pairs(it.perk) do table.insert(bits, string.format("+%d%% %s", math.floor(v * 100 + 0.5), STAT_NAMES[stat] or stat)) end
    table.sort(bits)
    return table.concat(bits, ", ") .. (it.category == "fire" and "  (only your best fire counts)" or "")
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- ── Content ───────────────────────────────────────────────────────────────────
local function Reload()
    local ok, fresh = pcall(function() return RemoteEvents.GetBuildInfo:InvokeServer() end)
    if ok and fresh then info = fresh end
    for id, b in pairs(tabButtons) do
        local on = id == tab
        b.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        b.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary
    end
    Clear()
    if not info then Note("Loading...", 30) return end
    coinsLbl.Text = Utils.FormatNumber(info.coins) .. " coins"

    if tab == "Shop" then
        Note(string.format("The shop restocks in %s. Rarer pieces are not always in stock, so check back often. You can buy up to %d of a piece per restock.",
            Clock(info.restockAt - workspace:GetServerTimeNow()), ForgeBuildData.BUY_PER_RESTOCK), 54)
        local inStock = {}
        for _, id in ipairs(info.stock) do inStock[id] = true end
        for _, it in ipairs(ForgeBuildData.Items) do
            if inStock[it.id] then
                local own = info.owned[it.id] and info.owned[it.id].total or 0
                local bought = info.boughtThisRestock[it.id] or 0
                local full = own >= it.maxOwned
                local capped = bought >= ForgeBuildData.BUY_PER_RESTOCK
                local afford = info.coins >= it.price
                local label = full and "Max owned" or capped and "Sold out for you" or (Utils.FormatNumber(it.price) .. " coins")
                Row(string.format("%s   (%s)", it.name, it.rarity), PerkText(it) .. string.format("   -   you own %d / %d", own, it.maxOwned),
                    RARITY_COLOR[it.rarity] or Theme.Colors.Info,
                    { { text = label, color = (not full and not capped and afford) and Theme.Colors.Success or Theme.Colors.PanelAlt,
                        enabled = not full and not capped and afford, onClick = function() RemoteEvents.BuildAction:FireServer("buy", it.id) end } }, 58)
            end
        end
        return
    end

    if tab == "Mine" then
        Note("Pieces you own that are not on your forge. Go to your forge, stand where you want the piece (it appears just in front of you), then press Place.", 54)
        local any = false
        for _, it in ipairs(ForgeBuildData.Items) do
            local o = info.owned[it.id]
            local spare = o and (o.total - o.placed) or 0
            if spare > 0 then
                any = true
                Row(string.format("%s  x%d", it.name, spare), PerkText(it), RARITY_COLOR[it.rarity] or Theme.Colors.Info, {
                    { text = "Place", color = Theme.Colors.Success, onClick = function() RemoteEvents.BuildAction:FireServer("place", it.id) end },
                    { text = string.format("Sell %d", math.floor(it.price * ForgeBuildData.SELL_BACK)), color = Theme.Colors.Danger,
                      onClick = function() RemoteEvents.BuildAction:FireServer("sell", it.id) end },
                }, 58)
            end
        end
        if not any then Note("Nothing waiting to be placed. Buy something in the Shop.", 30) end
        return
    end

    if tab == "Ascend" then
        local a = info.ascension
        if not a then Note("Loading...", 30) return end
        Note("Ascension is the endgame. At Forge Level " .. AscensionData.FORGE_LEVEL .. " you can spend coins to Ascend (up to "
            .. AscensionData.MAX .. " times). Each Ascension is a permanent bonus and a title shown on your forge sign and the Ascended leaderboard. "
            .. "Nothing is reset: you keep everything.", 84)
        local function Bonus(b)
            local bits = {}
            for _, stat in ipairs({ "mining", "carry", "luck", "coins" }) do
                if (b[stat] or 0) > 0 then table.insert(bits, string.format("+%d%% %s", math.floor(b[stat] * 100 + 0.5), ForgeBuildStatNames[stat])) end
            end
            return #bits > 0 and table.concat(bits, ", ") or "none yet"
        end
        Row(a.count > 0 and AscensionData.Title(a.count) or "Not yet Ascended", "Your permanent bonus: " .. Bonus(a.bonus),
            Theme.Colors.Legendary, {}, 54)
        if a.maxed then
            Note("You have reached the highest Ascension. Congratulations!", 30, Theme.Colors.Success)
        else
            local ready = a.forgeLevel >= a.needLevel and a.coins >= a.nextCost
            Row("Ascend to " .. AscensionData.Roman(a.count + 1),
                string.format("Costs %s coins. Gives: %s.%s", Utils.FormatNumber(a.nextCost), Bonus(AscensionData.PER),
                    a.forgeLevel < a.needLevel and string.format("  Needs Forge Level %d (you are %d).", a.needLevel, a.forgeLevel) or ""),
                Theme.Colors.Gold, { { text = ready and "Ascend" or "Not ready", color = ready and Theme.Colors.Success or Theme.Colors.PanelAlt,
                    enabled = ready, onClick = function() RemoteEvents.BuildAction:FireServer("ascend") end } }, 66)
        end
        return
    end

    -- Placed
    local p = info.perks
    local bits = {}
    for _, stat in ipairs({ "rate", "carry", "eff", "wear", "luck" }) do
        if (p[stat] or 0) > 0 then table.insert(bits, string.format("+%d%% %s", math.floor(p[stat] * 100 + 0.5), STAT_NAMES[stat])) end
    end
    Note(string.format("%d / %d pieces placed.   Forge bonuses: %s   (each bonus is capped at %d%%)",
        #info.placed, ForgeBuildData.MAX_PLACED, #bits > 0 and table.concat(bits, ", ") or "none yet", ForgeBuildData.BUILD_CAP * 100), 54)
    if #info.placed == 0 then Note("Nothing placed yet.", 30) return end
    for i, placed in ipairs(info.placed) do
        local it = ForgeBuildData.Get(placed.id)
        if it then
            Row(it.name, PerkText(it), RARITY_COLOR[it.rarity] or Theme.Colors.Info,
                { { text = "Pick up", color = Theme.Colors.Accent, onClick = function() RemoteEvents.BuildAction:FireServer("pickup", i) end } }, 50)
        end
    end
end

for id, b in pairs(tabButtons) do
    b.MouseButton1Click:Connect(function() tab = id Say("") Reload() end)
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then Say("") task.spawn(Reload) end
end)

RemoteEvents.BuildResult.OnClientEvent:Connect(function(action, ok, message)
    Say(message or "", ok)
    if ok and action == "place" then gui.Enabled = false end      -- get out of the way so you can see it
    task.delay(0.2, function() if gui.Enabled then Reload() end end)
end)
