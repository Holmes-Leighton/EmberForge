-- Quarry menu: found your Quarry, see what it mines, collect the silo, buy and place nodes and helpers, and upgrade the Core.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local QuarryData   = require(game.ReplicatedStorage.Shared.Data.QuarryData)
local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

RemoteEvents.Load()

local W, H = 760, 540
local tab = "Overview"
local info

local gui = Instance.new("ScreenGui")
gui.Name = "QuarryMenu"
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
local title = Theme.Label(titleBar, "Quarry", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
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
for _, t in ipairs({ { "Overview", "Overview" }, { "Build", "Build" }, { "Layout", "My Layout" }, { "Core", "Upgrade Core" } }) do
    local b = Theme.Button(tabCol, t[2], Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, t[1] .. "Tab")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.TextSize = 13
    tabButtons[t[1]] = b
end
local goBtn = Theme.Button(tabCol, "Go to my Quarry", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "GoToQuarryButton")
goBtn.Size = UDim2.new(1, 0, 0, 38)
goBtn.TextSize = 13
goBtn.MouseButton1Click:Connect(function() RemoteEvents.GoToQuarry:FireServer() gui.Enabled = false end)

local content = Theme.ScrollFrame(container, "Content")
content.Position = UDim2.new(0, 166, 0, 58)
content.Size = UDim2.new(1, -174, 1, -92)
Theme.AddListLayout(content, Enum.FillDirection.Vertical, 6)

local statusLbl = Theme.Label(container, "", Theme.TextSize.Body, Theme.Colors.Danger, Theme.Fonts.Heading, "Status")
statusLbl.AnchorPoint = Vector2.new(0, 1)
statusLbl.Position = UDim2.new(0, 170, 1, -8)
statusLbl.Size = UDim2.new(1, -182, 0, 22)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
local function Say(text, good) statusLbl.Text = text or "" statusLbl.TextColor3 = good and Theme.Colors.Success or Theme.Colors.Danger end

local function Clear() for _, c in ipairs(content:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
local function Note(text, height, color)
    local l = Theme.Label(content, text, Theme.TextSize.Body, color or Theme.Colors.TextSecondary, Theme.Fonts.Body)
    l.Size = UDim2.new(1, -8, 0, height or 40)
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    return l
end
local Portrait = require(game.ReplicatedStorage.Shared.Modules.Portrait)
local function Row(name, sub, color, buttons, height, golem)
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
    local reserve = 140 * math.max(1, #buttons) + 20
    local textX = 22
    if golem then
        swatch.Visible = false
        local face = Portrait.Golem(row, golem, 42)
        face.Position = UDim2.new(0, 8, 0.5, -21)
        textX = 58
        reserve += 36
    end
    local n = Theme.Label(row, name, Theme.TextSize.Heading, Theme.Colors.TextPrimary, Theme.Fonts.Heading)
    n.Position = UDim2.new(0, textX, 0, 4)
    n.Size = UDim2.new(1, -reserve, 0, 22)
    local s = Theme.Label(row, sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    s.Position = UDim2.new(0, textX, 0, 26)
    s.Size = UDim2.new(1, -reserve, 0, (height or 58) - 28)
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
end

local function Mat(id) local m = MaterialData.Get(id) return m and m.displayName or id end
local function RatesText(rates)
    local bits = {}
    for m, r in pairs(rates or {}) do table.insert(bits, string.format("%d/hr %s", math.floor(r + 0.5), Mat(m))) end
    table.sort(bits)
    return #bits > 0 and table.concat(bits, ",  ") or "nothing yet: build some nodes"
end

local function Reload()
    local ok, fresh = pcall(function() return RemoteEvents.GetQuarryInfo:InvokeServer() end)
    if ok and fresh then info = fresh end
    for id, b in pairs(tabButtons) do
        local on = id == tab
        b.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        b.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary
    end
    Clear()
    if not info then Note("Loading...", 30) return end
    coinsLbl.Text = Utils.FormatNumber(info.coins) .. " coins"

    if not info.founded then
        Note("Your Quarry is a second plot behind your forge where you build nodes and helper buildings that mine for you, even while you are away. "
            .. "Place pieces next to each other to make materials only a Quarry can make (Tempered Ember, Stormglass, Frostfire Gems, Voidstone and Prismatic Shards), then trade them or use them to upgrade your Core.", 110)
        local can = info.forgeLevel >= info.unlockLevel and info.coins >= info.foundCost
        Row("Found your Quarry", string.format("Needs Forge Level %d (you are %d) and %s coins.", info.unlockLevel, info.forgeLevel, Utils.FormatNumber(info.foundCost)),
            Theme.Colors.Gold, { { text = can and "Found" or "Not ready", color = can and Theme.Colors.Success or Theme.Colors.PanelAlt, enabled = can,
                onClick = function() RemoteEvents.QuarryAction:FireServer("found") end } }, 62)
        return
    end

    if tab == "Overview" then
        Row(string.format("Silo: %s / %s", Utils.FormatNumber(info.storedTotal), Utils.FormatNumber(info.capacity)),
            "It stops mining when the silo is full, and after 12 hours away. Empty it from here.", Theme.Colors.Info,
            { { text = info.storedTotal > 0 and "Collect all" or "Empty", color = info.storedTotal > 0 and Theme.Colors.Success or Theme.Colors.PanelAlt,
                enabled = info.storedTotal > 0, onClick = function() RemoteEvents.QuarryAction:FireServer("collect") end } }, 62)
        local stored = {}
        for m, n in pairs(info.stored) do if n > 0 then table.insert(stored, n .. " " .. Mat(m)) end end
        table.sort(stored)
        Note("In the silo: " .. (#stored > 0 and table.concat(stored, ",  ") or "nothing yet"), 36)
        Note("Mining now: " .. RatesText(info.rates), 50, Theme.Colors.AccentBright)
        Note(string.format("Core level %d: up to %d nodes. Your Quarry materials: %s", info.level, info.nodeLimit, (function()
            local bits = {}
            for _, m in ipairs({ "TemperedEmber", "Stormglass", "FrostfireGem", "Voidstone", "PrismaticShard" }) do
                if (info.inventory[m] or 0) > 0 then table.insert(bits, info.inventory[m] .. " " .. Mat(m)) end
            end
            return #bits > 0 and table.concat(bits, ", ") or "none" end)()), 40)
        -- the crew: idle Golems working the Quarry
        local GolemNames = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
        local function Name(g) local d = GolemNames.Describe(g) return d and d.name or (g.element .. " Golem") end
        Note(string.format("Crew: %d / %d Golems working here (+%d%% output). Golems that are not mining in a zone can work the Quarry instead.",
            #info.crew, info.crewSlots, math.floor((info.crewBoost - 1) * 100 + 0.5)), 40, Theme.Colors.AccentBright)
        for _, g in ipairs(info.crew) do
            Row(Name(g), string.format("Tier %d, working in the Quarry", g.tier), Theme.Colors.Success,
                { { text = "Call back", color = Theme.Colors.PanelAlt, onClick = function() RemoteEvents.QuarryAction:FireServer("crewremove", g.id) end } }, 56, g)
        end
        if #info.crew < info.crewSlots then
            local shown = 0
            table.sort(info.idleGolems, function(a, b) return (a.tier or 1) > (b.tier or 1) end)
            for _, g in ipairs(info.idleGolems) do
                if shown >= 12 then Note(string.format("...and %d more idle Golems (best tiers shown first).", #info.idleGolems - 12), 24, Theme.Colors.TextDim) break end
                shown += 1
                Row(Name(g), string.format("Tier %d, idle: +%d%% if it works here", g.tier, math.floor(QuarryData.CREW_PER_TIER * (g.tier or 1) * (QuarryData.CREW_VARIANT[g.variant] or 1) * 100 + 0.5)),
                    Theme.Colors.Info, { { text = "Send to work", color = Theme.Colors.Accent, onClick = function() RemoteEvents.QuarryAction:FireServer("crewadd", g.id) end } }, 56, g)
            end
            if shown == 0 then Note("You have no idle Golems. Recall one from its zone in the Forge menu, or craft another.", 30, Theme.Colors.TextDim) end
        end
        Note("Tip: put a Cooling Pool next to an Ember node, a Sky Spire next to a Storm node, an Ember node next to a Frost node, a Void Geode next to a Granite Vein, "
            .. "or a Prism Cluster among three different nodes. Pieces count as 'next to' each other within " .. QuarryData.LINK_RANGE .. " studs.", 76, Theme.Colors.TextDim)
    elseif tab == "Build" then
        Note("Go to your Quarry, stand where you want a piece (it appears just in front of you), then press Place. It is bought when you place it.", 46)
        for _, id in ipairs(QuarryData.PieceOrder) do
            local def = QuarryData.Pieces[id]
            local own = info.owned[id] or 0
            local full = own >= def.max
            local afford = info.coins >= def.price
            local detail = def.kind == "node" and ("Mines " .. Mat(def.makes) .. " (" .. def.rate .. "/hr). Grows Budding, then Mature (x1.3) after a day, then Prime (x1.6) after three.") or def.blurb
            Row(string.format("%s   (%d / %d)", def.name, own, def.max), detail, def.color or Theme.Colors.Info,
                { { text = full and "Max built" or (Utils.FormatNumber(def.price) .. " coins"), color = (not full and afford) and Theme.Colors.Success or Theme.Colors.PanelAlt,
                    enabled = not full and afford, onClick = function() RemoteEvents.QuarryAction:FireServer("place", id) end } }, 58)
        end
    elseif tab == "Layout" then
        Note(string.format("%d pieces built. Removing one refunds half its price (a replacement node starts small again).", #info.placed), 40)
        for i, p in ipairs(info.placed) do
            local def = QuarryData.Pieces[p.id]
            if def and p.id ~= "Core" then
                local where = string.format("%d studs east, %d studs south of the Core", p.x, p.z)
                if def.kind == "node" then
                    local stage, _, progress, hoursLeft = QuarryData.NodeStageAt(p, os.time())
                    where = string.format("%s (x%.1f output)", stage.id, stage.mult)
                        .. (hoursLeft and string.format("  -  %d%% to the next stage, %s to go", math.floor(progress * 100), Utils.FormatTime(hoursLeft * 3600)) or "  -  fully grown")
                        .. "   -   " .. where
                end
                Row(def.name, where, def.color or Theme.Colors.Info,
                    { { text = "Remove", color = Theme.Colors.Danger, onClick = function() RemoteEvents.QuarryAction:FireServer("remove", i) end } }, 50)
            end
        end
    else
        local nl = info.nextLevel
        if not nl then Note("Your Core is at its highest level.", 30, Theme.Colors.Success) return end
        local needs, can = {}, true
        for m, n in pairs(nl.cost) do
            local have = info.inventory[m] or 0
            if have < n then can = false end
            table.insert(needs, string.format("%s %d / %d", Mat(m), have, n))
        end
        table.sort(needs)
        Row(string.format("Upgrade the Core to level %d", nl.level),
            string.format("Supports %d nodes and +%d storage.  Needs: %s", nl.nodes, nl.storage, table.concat(needs, ",  ")), Theme.Colors.Legendary,
            { { text = can and "Upgrade" or "Not enough", color = can and Theme.Colors.Success or Theme.Colors.PanelAlt, enabled = can,
                onClick = function() RemoteEvents.QuarryAction:FireServer("upgrade") end } }, 76)
        Note("Quarry materials can only be made in a Quarry, so upgrading is how your Quarry grows. You can also trade them in the Market.", 40)
    end
end

for id, b in pairs(tabButtons) do b.MouseButton1Click:Connect(function() tab = id Say("") Reload() end) end
gui:GetPropertyChangedSignal("Enabled"):Connect(function() if gui.Enabled then Say("") task.spawn(Reload) end end)
RemoteEvents.QuarryResult.OnClientEvent:Connect(function(action, ok, message)
    Say(message or "", ok)
    if ok and action == "place" then gui.Enabled = false end
    task.delay(0.2, function() if gui.Enabled then Reload() end end)
end)
