-- Manages the Forge UI: smelt queue display, golem crafting, and deployment panels.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local RemoteEvents  = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local GolemData     = require(game.ReplicatedStorage.Shared.Data.GolemData)
local Portrait      = require(game.ReplicatedStorage.Shared.Modules.Portrait)
local RecipeData    = require(game.ReplicatedStorage.Shared.Data.RecipeData)
local ForgeData     = require(game.ReplicatedStorage.Shared.Data.ForgeData)
local Utils         = require(game.ReplicatedStorage.Shared.Modules.Utils)
local MaterialData  = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local CraftRules    = require(game.ReplicatedStorage.Shared.Modules.CraftRules)
local GolemNames    = require(game.ReplicatedStorage.Shared.Modules.GolemNames)

local ForgeController = {}

local forgeGui
local smeltQueueDisplay = {}  -- jobId → frame reference

-- ── Init ──────────────────────────────────────────────────────────────────────
function ForgeController.Init(playerData)
    ForgeController._data = playerData

    task.spawn(function()
        forgeGui = PlayerGui:WaitForChild("ForgeMenu", 10)
        if not forgeGui then return end

        ForgeController._BuildBlueprintList()
        ForgeController._BuildSmeltPanel()
        ForgeController._BuildDeployPanel()
        ForgeController._RenderSmeltQueue()
        ForgeController._StartSmeltCountdowns()
        forgeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if forgeGui.Enabled then
                ForgeController.Resync()
                -- a Golem waiting for work (none deployed yet): open straight on the Deploy tab, as the tutorial says
                local golems = ForgeController._data and ForgeController._data.Golems or {}
                local anyDeployed = false
                for _, g in ipairs(golems) do if g.deployed then anyDeployed = true end end
                forgeGui:SetAttribute("OpenTab", nil)
                forgeGui:SetAttribute("OpenTab", (#golems > 0 and not anyDeployed) and "Deploy" or "Blueprints")
            end
        end)
        ForgeController._WireFuseButton()
    end)
end

-- ── Blueprint / Crafting Panel ────────────────────────────────────────────────
function ForgeController._BuildBlueprintList()
    if not forgeGui then return end
    local scrollFrame = forgeGui:FindFirstChild("BlueprintScroll", true)
    if not scrollFrame then return end

    -- Clear existing
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local data = ForgeController._data
    local yOffset = 0

    local events = {}
    for _, id in ipairs(data.AvailableEventBlueprints or {}) do events[id] = true end
    local list = CraftRules.ListBlueprints(data, events)
    table.sort(list, function(a, b)
        local la = CraftRules.GetLockReason(data, a, events) ~= nil
        local lb = CraftRules.GetLockReason(data, b, events) ~= nil
        if la ~= lb then return not la end                    -- craftable-now first
        if a.tier ~= b.tier then return a.tier < b.tier end
        return a.id < b.id
    end)
    for _, bp in ipairs(list) do
        local card = ForgeController._CreateBlueprintCard(bp, data, yOffset, events)
        card.Parent = scrollFrame
        yOffset = yOffset + 120
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
end

function ForgeController._CreateBlueprintCard(bp, data, yOffset, events)
    local card = Instance.new("Frame")
    card.Name = bp.id
    card.Size = UDim2.new(1, -10, 0, 110)
    card.Position = UDim2.new(0, 5, 0, yOffset + 5)
    card.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
    card.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 0, 28)
    title.Position = UDim2.new(0, 8, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = (bp.element or "?") .. " - Tier " .. bp.tier .. (bp.isEventGolem and "  (EVENT)" or "")
    title.TextColor3 = Color3.fromRGB(255, 200, 80)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    -- How many times can this be crafted with the current inventory (0 if a rule blocks it)?
    local lock = CraftRules.GetLockReason(data, bp, events)
    local craftable = lock and 0 or CraftRules.CraftableCount(data, bp)

    -- Requirements list
    local reqText = ""
    for i, req in ipairs(bp.materialsRequired or {}) do
        local have = (data.Inventory or {})[req.id] or 0
        local colour = have >= req.qty and "[OK]" or "[NEED]"
        local matDef = MaterialData.Get(req.id)
        reqText = reqText .. colour .. " " .. (matDef and matDef.displayName or req.id) .. "  " .. have .. "/" .. req.qty
        if i < #bp.materialsRequired then reqText = reqText .. "\n" end
    end
    if lock then reqText = "LOCKED: " .. lock .. "\n" .. reqText end
    local reqs = Instance.new("TextLabel")
    reqs.Size = UDim2.new(1, -110, 0, 68)
    reqs.Position = UDim2.new(0, 8, 0, 32)
    reqs.BackgroundTransparency = 1
    reqs.Text = reqText
    reqs.TextColor3 = Color3.fromRGB(180, 180, 180)
    reqs.Font = Enum.Font.Code
    reqs.TextSize = 11
    reqs.TextXAlignment = Enum.TextXAlignment.Left
    reqs.TextYAlignment = Enum.TextYAlignment.Top
    reqs.TextWrapped = true
    reqs.Parent = card

    -- Craftable badge
    local badge = Instance.new("TextLabel")
    badge.Name = "CraftableBadge"
    badge.Size = UDim2.new(0, 92, 0, 24)
    badge.Position = UDim2.new(1, -98, 0, 8)
    badge.BackgroundColor3 = craftable > 0 and Color3.fromRGB(60, 150, 80) or Color3.fromRGB(70, 60, 55)
    badge.Text = lock and CraftRules.ShortLockReason(lock) or (craftable > 0 and ("Can craft: " .. craftable) or "Need more")
    badge.TextColor3 = craftable > 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 150, 140)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 12
    badge.BorderSizePixel = 0
    badge.Parent = card
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(1, 0)
    badgeCorner.Parent = badge

    -- Craft button
    local craftBtn = Instance.new("TextButton")
    craftBtn.Size = UDim2.new(0, 90, 0, 28)
    craftBtn.Position = UDim2.new(1, -98, 0, 38)
    craftBtn.BackgroundColor3 = craftable > 0 and Color3.fromRGB(200, 120, 40) or Color3.fromRGB(70, 60, 55)
    craftBtn.Text = "Craft"
    craftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    craftBtn.Font = Enum.Font.GothamBold
    craftBtn.TextSize = 14
    craftBtn.BorderSizePixel = 0
    craftBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = craftBtn

    if craftable > 0 then
        craftBtn.MouseButton1Click:Connect(function()
            RemoteEvents.CraftGolem:FireServer(bp.id, "default", 1)
        end)
    else
        craftBtn.AutoButtonColor = false
        craftBtn.TextColor3 = Color3.fromRGB(150, 135, 125)
    end

    -- Craft All (only useful when more than one can be made)
    if craftable > 1 then
        local allBtn = Instance.new("TextButton")
        allBtn.Name = "CraftAllButton"
        allBtn.Size = UDim2.new(0, 90, 0, 28)
        allBtn.Position = UDim2.new(1, -98, 0, 72)
        allBtn.BackgroundColor3 = Color3.fromRGB(60, 150, 80)
        allBtn.Text = "Craft All (" .. craftable .. ")"
        allBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        allBtn.Font = Enum.Font.GothamBold
        allBtn.TextSize = 12
        allBtn.BorderSizePixel = 0
        allBtn.Parent = card
        local allCorner = Instance.new("UICorner")
        allCorner.CornerRadius = UDim.new(0, 4)
        allCorner.Parent = allBtn
        allBtn.MouseButton1Click:Connect(function()
            RemoteEvents.CraftGolem:FireServer(bp.id, "default", craftable)
        end)
    end

    return card
end

function ForgeController._WireFuseButton()
    if not forgeGui then return end
    local btn = forgeGui:FindFirstChild("FuseGolemsButton", true)
    if btn then
        btn.MouseButton1Click:Connect(function()
            ForgeController._OpenGolemFuseDialog()
        end)
    end
end

-- ── Smelt Panel ───────────────────────────────────────────────────────────────
function ForgeController._BuildSmeltPanel()
    if not forgeGui then return end
    local smeltPanel = forgeGui:FindFirstChild("SmeltPanel", true)
    if not smeltPanel then return end
    -- UI pre-built in Studio — we wire up the smelt button
    local smeltBtn = smeltPanel:FindFirstChild("SmeltButton", true)
    if smeltBtn then
        smeltBtn.MouseButton1Click:Connect(function()
            ForgeController._OpenSmeltDialog()
        end)
    end
end

function ForgeController._OpenSmeltDialog()
    local data = ForgeController._data
    if not data then return end
    local pg     = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local dialog = pg:FindFirstChild("SmeltDialog")
    if not dialog then return end
    local openFn = dialog:FindFirstChild("Open")
    if openFn then
        openFn:Invoke(data.Inventory or {})
    end
end

-- ── Smelt countdown timer ─────────────────────────────────────────────────────
function ForgeController._StartSmeltCountdowns()
    task.spawn(function()
        while true do
            task.wait(1)
            local now = Utils.UnixTimestamp()
            for _, entry in pairs(smeltQueueDisplay) do
                if entry.frame.Parent then
                    local remaining = math.max(0, entry.endTime - now)
                    local timeLbl = entry.frame:FindFirstChild("TimeLabel")
                    if timeLbl then
                        timeLbl.Text = remaining > 0 and Utils.FormatTime(remaining) or "Done!"
                    end
                end
            end
        end
    end)
end

-- ── Live data / refresh ───────────────────────────────────────────────────────
-- The server is the source of truth: after any change, pull a fresh copy and redraw.
function ForgeController.Refresh()
    if not forgeGui or not ForgeController._data then return end
    ForgeController._BuildBlueprintList()
    ForgeController._BuildDeployPanel()
    ForgeController._RenderSmeltQueue()
    ForgeController._RenderUpgrades()
    ForgeController._RenderNeon()
end

local resyncQueued = false
function ForgeController.Resync()
    if resyncQueued then return end   -- several events in a row (e.g. Craft All) share one refresh
    resyncQueued = true
    task.delay(0.25, function()
        resyncQueued = false
        local fresh = RemoteEvents.GetPlayerData:InvokeServer()
        if fresh then
            ForgeController._data = fresh
            ForgeController.Refresh()
        end
    end)
end

-- Materials arrive from pads/golems: keep the [OK]/[NEED] counts honest while the menu is open
function ForgeController.OnResourcesCollected(gains)
    local data = ForgeController._data
    if not data then return end
    data.Inventory = data.Inventory or {}
    for matId, qty in pairs(gains or {}) do
        if type(qty) == "number" and matId:sub(1, 12) ~= "__blueprint:" then
            data.Inventory[matId] = (data.Inventory[matId] or 0) + qty
        end
    end
    if forgeGui and forgeGui.Enabled and not ForgeController._bpRefreshQueued then
        ForgeController._bpRefreshQueued = true
        task.delay(0.5, function()
            ForgeController._bpRefreshQueued = false
            if forgeGui and forgeGui.Enabled then ForgeController._BuildBlueprintList() end
        end)
    end
end

-- ── Neon Cave: four identical Golems -> Neon, four Neons -> Mega Neon ──────────
function ForgeController._RenderNeon()
    if not forgeGui then return end
    local scroll = forgeGui:FindFirstChild("NeonScroll", true)
    local data = ForgeController._data
    if not scroll or not data then return end
    local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
    local need = GolemData.NEON_FUSION_COUNT

    if not scroll:FindFirstChildOfClass("UIListLayout") then
        Theme.AddListLayout(scroll, Enum.FillDirection.Vertical, 8)
    end
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    local intro = Instance.new("Frame")
    intro.Size = UDim2.new(1, -8, 0, 84)
    intro.BackgroundColor3 = Theme.Colors.Panel
    intro.BorderSizePixel = 0
    intro.Parent = scroll
    Theme.AddCorner(intro, Theme.Corner.Medium)
    local h = Theme.Label(intro, "Elite Forge", Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading)
    h.Position = UDim2.new(0, 14, 0, 6)
    h.Size = UDim2.new(1, -28, 0, 22)
    local t = Theme.Label(intro, string.format(
        "Fuse %d identical idle Golems (same element and tier) into 1 Elite Golem: bigger, gold-armoured, and %d%% stronger.\nFuse %d Elites into a Supreme: royal cape, wings and halo, and %d%% stronger. Deployed Golems can't be fused.",
        need, math.floor((GolemData.Variants.Neon.statMultiplier - 1) * 100 + 0.5), need,
        math.floor((GolemData.Variants.MegaNeon.statMultiplier - 1) * 100 + 0.5)),
        Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    t.Position = UDim2.new(0, 14, 0, 30)
    t.Size = UDim2.new(1, -28, 0, 50)
    t.TextYAlignment = Enum.TextYAlignment.Top

    -- group idle Golems by (element, tier, variant)
    local groups, order = {}, {}
    for _, g in ipairs(data.Golems or {}) do
        if not g.deployed and g.variant ~= "MegaNeon" then
            local key = g.element .. "|" .. g.tier .. "|" .. (g.variant or "")
            if not groups[key] then
                groups[key] = { element = g.element, tier = g.tier, variant = g.variant, count = 0, sample = g }
                table.insert(order, key)
            end
            groups[key].count += 1
        end
    end
    table.sort(order, function(a, b)
        local ga, gb = groups[a], groups[b]
        local ra, rb = (ga.count >= need) and 0 or 1, (gb.count >= need) and 0 or 1
        if ra ~= rb then return ra < rb end
        if ga.tier ~= gb.tier then return ga.tier > gb.tier end
        return ga.element < gb.element
    end)

    if #order == 0 then
        local none = Theme.Label(scroll, "You have no idle Golems to fuse. Craft more, or recall deployed ones.",
            Theme.TextSize.Body, Theme.Colors.TextDim)
        none.Size = UDim2.new(1, -8, 0, 40)
        return
    end

    for _, key in ipairs(order) do
        local grp = groups[key]
        local d = GolemNames.Describe(grp.sample)
        local ready = grp.count >= need
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -8, 0, 64)
        card.BackgroundColor3 = Theme.Colors.Panel
        card.BorderSizePixel = 0
        card.Parent = scroll
        Theme.AddCorner(card, Theme.Corner.Small)

        local nameL = Theme.Label(card, string.format("%s   [%s]", d.name, d.rarity), Theme.TextSize.Body, d.rarityColor, Theme.Fonts.Heading)
        nameL.Position = UDim2.new(0, 12, 0, 8)
        nameL.Size = UDim2.new(1, -230, 0, 22)
        local countL = Theme.Label(card, string.format("%d of %d idle Golems", grp.count, need), Theme.TextSize.Small,
            ready and Theme.Colors.Success or Theme.Colors.TextSecondary, Theme.Fonts.Heading)
        countL.Position = UDim2.new(0, 12, 0, 34)
        countL.Size = UDim2.new(1, -230, 0, 18)

        local result = grp.variant == "Neon" and "Supreme" or "Elite"
        local btn = Theme.Button(card, "Fuse " .. need .. "  >  " .. result, ready and Theme.Colors.Accent or Theme.Colors.PanelAlt,
            ready and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextDim)
        btn.AnchorPoint = Vector2.new(1, 0.5)
        btn.Position = UDim2.new(1, -10, 0.5, 0)
        btn.Size = UDim2.new(0, 200, 0, 36)
        btn.TextSize = 13
        btn.AutoButtonColor = ready
        btn.MouseButton1Click:Connect(function()
            if ready then RemoteEvents.NeonFuse:FireServer(grp.element, grp.tier, grp.variant) end
        end)
    end
end

-- ── Upgrades: forge level progress + Storage Vault ────────────────────────────
function ForgeController._RenderUpgrades()
    if not forgeGui then return end
    local scroll = forgeGui:FindFirstChild("UpgradesScroll", true)
    local data = ForgeController._data
    if not scroll or not data then return end
    local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
    local ForgeDataM = require(game.ReplicatedStorage.Shared.Data.ForgeData)
    local GameConfigM = require(game.ReplicatedStorage.Shared.Data.GameConfig)

    if not scroll:FindFirstChildOfClass("UIListLayout") then
        Theme.AddListLayout(scroll, Enum.FillDirection.Vertical, 8)
    end
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    local function Card(height)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -8, 0, height)
        f.BackgroundColor3 = Theme.Colors.Panel
        f.BorderSizePixel = 0
        f.Parent = scroll
        Theme.AddCorner(f, Theme.Corner.Medium)
        return f
    end
    local function Text(parent, text, y, size, color, font, h)
        local l = Theme.Label(parent, text, size or Theme.TextSize.Body, color or Theme.Colors.TextPrimary, font or Theme.Fonts.Body)
        l.Position = UDim2.new(0, 14, 0, y)
        l.Size = UDim2.new(1, -28, 0, h or 20)
        l.TextYAlignment = Enum.TextYAlignment.Top
        return l
    end

    -- Forge level
    local level = data.ForgeLevel or 1
    local fd = ForgeDataM.Get(level)
    local nextFd = ForgeDataM.ByLevel[level + 1]
    local card = Card(150)
    Text(card, string.format("Forge Level %d  -  %s", level, fd.displayName), 8, Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading, 24)
    Text(card, fd.unlocks.description, 34, nil, Theme.Colors.TextSecondary, nil, 36)
    if nextFd then
        local xp, need, base = data.ForgeXP or 0, nextFd.xpRequired, fd.xpRequired
        local frac = math.clamp((xp - base) / math.max(1, need - base), 0, 1)
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, -28, 0, 14)
        bg.Position = UDim2.new(0, 14, 0, 74)
        bg.BackgroundColor3 = Theme.Colors.Background
        bg.BorderSizePixel = 0
        bg.Parent = card
        Theme.AddCorner(bg, UDim.new(0, 7))
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(frac, 0, 1, 0)
        fill.BackgroundColor3 = Theme.Colors.Ember
        fill.BorderSizePixel = 0
        fill.Parent = bg
        Theme.AddCorner(fill, UDim.new(0, 7))
        Text(card, string.format("%d / %d Forge XP to level %d", xp - base, need - base, level + 1), 92, Theme.TextSize.Small, Theme.Colors.TextSecondary)
        Text(card, "Next: " .. nextFd.unlocks.description, 112, Theme.TextSize.Small, Theme.Colors.Gold, nil, 32)
    else
        Text(card, "Maximum Forge level reached.", 80, nil, Theme.Colors.Gold)
    end

    -- Level advancements: permanent boosts earned by raising the Forge
    do
        local totals = ForgeDataM.TotalPerks(level)
        local pc = Card(64 + 9 * 24)
        Text(pc, "Forge Boosts", 8, Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading, 22)
        local summary = ForgeDataM.PerkText(totals)
        Text(pc, summary ~= "" and ("Active now: " .. summary) or "No boosts yet. Reach Forge level 2 to start earning them.",
            32, Theme.TextSize.Small, Theme.Colors.Success, nil, 28)
        for l = 2, #ForgeDataM.Levels do
            local lf = ForgeDataM.Get(l)
            local reached = level >= l
            local t = string.format("%s Lv %d  %s:  %s", reached and "[OK]" or "[  ]", l, lf.displayName,
                ForgeDataM.PerkText(ForgeDataM.PerkAt(l)))
            Text(pc, t, 62 + (l - 2) * 24, Theme.TextSize.Small,
                reached and Theme.Colors.TextPrimary or Theme.Colors.TextDim, nil, 22)
        end
    end

    -- Elemental mastery (spec 6.2)
    do
        local thresholds = GameConfigM.MASTERY_XP_THRESHOLDS
        local BONUS = { [5] = "+5% mining rate", [10] = "+10% rare drop luck", [15] = "+15% smelt speed", [20] = "+20% all stats + title" }
        local mc = Card(28 + 5 * 46)
        Text(mc, "Elemental Mastery", 8, Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading, 22)
        for i, element in ipairs({ "Ember", "Stone", "Frost", "Storm", "Void" }) do
            local xp = (data.MasteryLevels or {})[element] or 0
            local lvl = 1
            for l = #thresholds, 1, -1 do
                if xp >= thresholds[l] then lvl = l break end
            end
            local nextXP = thresholds[lvl + 1]
            local frac = nextXP and math.clamp((xp - thresholds[lvl]) / (nextXP - thresholds[lvl]), 0, 1) or 1
            local nextBonus
            for l = lvl + 1, 20 do if BONUS[l] then nextBonus = l break end end

            local y = 32 + (i - 1) * 46
            local n = Theme.Label(mc, string.format("%s  Lv %d", element, lvl), Theme.TextSize.Body, Theme.Colors[element], Theme.Fonts.Heading)
            n.Position = UDim2.new(0, 14, 0, y)
            n.Size = UDim2.new(0, 120, 0, 20)
            local bg = Instance.new("Frame")
            bg.Position = UDim2.new(0, 140, 0, y + 5)
            bg.Size = UDim2.new(0, 220, 0, 10)
            bg.BackgroundColor3 = Theme.Colors.Background
            bg.BorderSizePixel = 0
            bg.Parent = mc
            Theme.AddCorner(bg, UDim.new(0, 5))
            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(frac, 0, 1, 0)
            fill.BackgroundColor3 = Theme.Colors[element]
            fill.BorderSizePixel = 0
            fill.Parent = bg
            Theme.AddCorner(fill, UDim.new(0, 5))
            local t = Theme.Label(mc, lvl >= 20 and "MAX  -  all bonuses unlocked" or
                (nextBonus and string.format("Lv %d: %s", nextBonus, BONUS[nextBonus]) or ""),
                Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
            t.Position = UDim2.new(0, 372, 0, y)
            t.Size = UDim2.new(1, -386, 0, 20)
            local sub = Theme.Label(mc, "Mine with " .. element .. " Golems to raise it", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body)
            sub.Position = UDim2.new(0, 14, 0, y + 20)
            sub.Size = UDim2.new(1, -28, 0, 16)
        end
    end

    -- Storage
    local tier = data.StorageTier or 0
    local hours = tier >= 2 and GameConfigM.OFFLINE_STORAGE_PREMIUM_HOURS or (tier >= 1 and GameConfigM.OFFLINE_STORAGE_UPGRADED_HOURS or GameConfigM.OFFLINE_STORAGE_BASE_HOURS)
    local vault = ForgeDataM.StorageVault
    local sc = Card(tier >= 1 and 90 or 230)
    Text(sc, string.format("Offline storage: %d hours", hours), 8, Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading, 24)
    Text(sc, "Your Golems keep mining while you are away, up to this many hours of production.", 34, Theme.TextSize.Small, Theme.Colors.TextSecondary, nil, 32)
    if tier >= 1 then
        Text(sc, tier >= 2 and "Premium storage active (24h)." or "Storage Vault built. Premium 24h storage is available in the Shop.", 62, nil, Theme.Colors.Success)
    else
        local locked = level < vault.forgeLevelRequired
        Text(sc, "Storage Vault  (8 hours)" .. (locked and ("   -   needs Forge Level " .. vault.forgeLevelRequired) or ""), 66, Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Heading)
        local y, canBuild = 90, not locked
        for _, req in ipairs(vault.materialsRequired) do
            local have = (data.Inventory or {})[req.id] or 0
            local def = MaterialData.Get(req.id)
            if have < req.qty then canBuild = false end
            Text(sc, string.format("%s   %d / %d", def and def.displayName or req.id, have, req.qty), y, nil,
                have >= req.qty and Theme.Colors.Success or Theme.Colors.Danger, Theme.Fonts.Heading)
            y += 22
        end
        local build = Theme.Button(sc, "Build Storage Vault", canBuild and Theme.Colors.Accent or Theme.Colors.PanelAlt,
            canBuild and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextDim, "BuildVaultButton")
        build.Size = UDim2.new(0, 200, 0, 38)
        build.Position = UDim2.new(0, 14, 1, -48)
        build.AutoButtonColor = canBuild
        build.MouseButton1Click:Connect(function()
            if canBuild then RemoteEvents.CraftStorageVault:FireServer() end
        end)
    end
end

-- ── Deployment Panel ──────────────────────────────────────────────────────────
function ForgeController._BuildDeployPanel()
    if not forgeGui then return end
    local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
    local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
    local data = ForgeController._data

    -- Zone buttons (only unlocked zones)
    local strip = forgeGui:FindFirstChild("ZoneStrip", true)
    if strip then
        for _, child in ipairs(strip:GetChildren()) do
            if child:IsA("GuiButton") or child:IsA("TextLabel") then child:Destroy() end
        end
        local unlocked = MiningZoneData.GetUnlocked(data)
        table.sort(unlocked)
        if not (ForgeController._selectedZone and Utils.TableContains(unlocked, ForgeController._selectedZone)) then
            ForgeController._selectedZone = unlocked[1]
        end
        if #unlocked == 0 then
            local lbl = Theme.Label(strip, "Forge a Golem to unlock a mining zone.", Theme.TextSize.Body,
                Theme.Colors.TextSecondary, Theme.Fonts.Body)
            lbl.Size = UDim2.new(0, 360, 1, 0)
        end
        for _, zoneId in ipairs(unlocked) do
            local zone = MiningZoneData.Get(zoneId)
            local selected = ForgeController._zonePicked and zoneId == ForgeController._selectedZone
            local btn = Theme.Button(strip, (selected and "> " or "") .. (zone and zone.displayName or zoneId),
                selected and Theme.Colors.Success or Theme.Colors.PanelAlt,
                selected and Color3.fromRGB(255, 255, 255) or Theme.Colors.AccentBright, zoneId)
            btn.Size = UDim2.new(0, 170, 0, 56)
            btn.TextSize = 14
            btn.MouseButton1Click:Connect(function()
                if ForgeController._selectedZone == zoneId and ForgeController._zonePicked then
                    ForgeController._zonePicked = false      -- click the chosen zone again to go back to "each to its own zone"
                else
                    ForgeController._selectedZone = zoneId
                    ForgeController._zonePicked = true
                end
                ForgeController._BuildDeployPanel()
            end)
        end
    end

    -- Golem list
    local scroll = forgeGui:FindFirstChild("GolemDeployScroll", true)
    if not scroll then return end
    if not scroll:FindFirstChildOfClass("UIListLayout") then
        Theme.AddListLayout(scroll, Enum.FillDirection.Vertical, 6)
    end
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end

    local golems = data and data.Golems or {}
    if #golems == 0 then
        local empty = Theme.Label(scroll, "No Golems yet. Forge one at the Golem Anvil near spawn.",
            Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Body)
        empty.Size = UDim2.new(1, -8, 0, 40)
        return
    end

    for _, g in ipairs(golems) do
        local card = Instance.new("Frame")
        card.Name = g.id
        card.Size = UDim2.new(1, -8, 0, 54)
        card.BackgroundColor3 = Theme.Colors.Panel
        card.BorderSizePixel = 0
        card.Parent = scroll
        Theme.AddCorner(card, Theme.Corner.Small)

        local desc = GolemNames.Describe(g)
        local color = desc.elementColor
        local title = Theme.Label(card, string.format("%s   [%s]", desc.name, desc.rarity),
            Theme.TextSize.Body, desc.rarityColor, Theme.Fonts.Heading)
        title.Size = UDim2.new(0.5, 0, 0, 22)
        title.Position = UDim2.new(0, 60, 0, 6)
        local face = Portrait.Golem(card, g, 42)
        face.Position = UDim2.new(0, 8, 0.5, -21)

        local zone = g.zoneId and MiningZoneData.Get(g.zoneId)
        local status = Theme.Label(card,
            g.deployed and ("⚡ Mining in " .. (zone and zone.displayName or tostring(g.zoneId))) or "💤 Idle",
            Theme.TextSize.Small, g.deployed and Theme.Colors.Success or Theme.Colors.TextSecondary)
        status.Size = UDim2.new(0.5, 0, 0, 18)
        status.Position = UDim2.new(0, 60, 0, 30)

        -- Durability bar (Golems wear out while mining; repairing costs 20% of the craft materials)
        local maxDur = g._maxDurabilitySeconds or (GolemData.Tiers[g.tier] and GolemData.Tiers[g.tier].durabilityHours * 3600) or 1
        local dur = math.max(0, g._durabilitySeconds or maxDur)
        local frac = math.clamp(dur / maxDur, 0, 1)
        local broken = dur <= 0
        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(0.4, 0, 0, 5)
        barBg.Position = UDim2.new(0, 60, 1, -9)
        barBg.BackgroundColor3 = Theme.Colors.Background
        barBg.BorderSizePixel = 0
        barBg.Parent = card
        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(frac, 0, 1, 0)
        barFill.BackgroundColor3 = broken and Color3.fromRGB(220, 60, 50) or (frac < 0.25 and Color3.fromRGB(230, 170, 40) or Theme.Colors.Success)
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg
        if broken then
            status.Text = "BROKEN - repair it to mine again"
            status.TextColor3 = Color3.fromRGB(230, 90, 70)
        end
        if not g.deployed and frac < 1 then
            local repair = Theme.Button(card, broken and "Repair!" or "Repair", broken and Theme.Colors.Danger or Theme.Colors.PanelAlt,
                broken and Color3.fromRGB(255, 255, 255) or Theme.Colors.AccentBright)
            repair.Size = UDim2.new(0, 70, 0, 30)
            repair.Position = UDim2.new(1, -184, 0.5, -15)
            repair.TextSize = 12
            repair.MouseButton1Click:Connect(function() RemoteEvents.RepairGolem:FireServer(g.id) end)
        end

        if not g.deployed then
            -- Golems go to their own element's zone unless you chose a zone yourself
            local zoneId = ForgeController._selectedZone
            if not ForgeController._zonePicked then
                for id, z in pairs(MiningZoneData.Zones) do
                    if z.element == g.element and Utils.TableContains(MiningZoneData.GetUnlocked(data), id) then
                        zoneId = id
                    end
                end
            end
            -- special Golems have no home zone: they mine in any zone you have unlocked
            if not zoneId and GolemData.IsSpecial(g.element) then
                zoneId = MiningZoneData.GetUnlocked(data)[1]
            end
            local zoneData = zoneId and MiningZoneData.Get(zoneId)
            local deploy = Theme.Button(card,
                zoneId and "Deploy ▶" or "No zone",
                zoneId and Theme.Colors.Accent or Theme.Colors.PanelAlt, Color3.fromRGB(255, 255, 255))
            deploy.Size = UDim2.new(0, 96, 0, 30)
            deploy.Position = UDim2.new(1, -106, 0.5, -15)
            if zoneId then
                status.Text = "💤 Idle  →  " .. (zoneData and zoneData.displayName or zoneId)
                deploy.MouseButton1Click:Connect(function()
                    RemoteEvents.DeployGolem:FireServer(g.id, zoneId)
                end)
            end
        else
            local recall = Theme.Button(card, "Recall", Theme.Colors.PanelAlt, Theme.Colors.AccentBright)
            recall.Size = UDim2.new(0, 84, 0, 30)
            recall.Position = UDim2.new(1, -94, 0.5, -15)
            recall.MouseButton1Click:Connect(function()
                RemoteEvents.ReturnGolem:FireServer(g.id)
            end)
            -- walk over to it: teleports you next to this Golem in its mining zone
            local goTo = Theme.Button(card, "Go to", Theme.Colors.Info, Color3.fromRGB(255, 255, 255), "GoToGolem")
            goTo.Size = UDim2.new(0, 70, 0, 30)
            goTo.Position = UDim2.new(1, -172, 0.5, -15)
            goTo.TextSize = 12
            goTo.MouseButton1Click:Connect(function()
                RemoteEvents.TeleportToGolem:FireServer(g.id)
                if forgeGui then forgeGui.Enabled = false end
            end)
        end
    end
end

function ForgeController._OpenGolemSelectForDeploy(zoneId)
    local data = ForgeController._data
    if not data or #(data.Golems or {}) == 0 then return end

    local pg     = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local dialog = pg:FindFirstChild("GolemPickerDialog")
    if not dialog then return end
    local openFn = dialog:FindFirstChild("Open")
    if not openFn then return end

    -- BindableEvent receives the chosen golem id
    local callbackEvent = Instance.new("BindableEvent")
    callbackEvent.Event:Connect(function(golemId)
        RemoteEvents.DeployGolem:FireServer(golemId, zoneId)
        callbackEvent:Destroy()
    end)

    openFn:Invoke(data.Golems, "deploy", callbackEvent)
end

function ForgeController._OpenGolemFuseDialog()
    local data = ForgeController._data
    if not data or #(data.Golems or {}) < 2 then return end

    local pg     = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local dialog = pg:FindFirstChild("GolemPickerDialog")
    if not dialog then return end
    local openFn = dialog:FindFirstChild("Open")
    if not openFn then return end

    -- First pick: the base golem
    local callbackBase = Instance.new("BindableEvent")
    callbackBase.Event:Connect(function(baseId)
        callbackBase:Destroy()
        -- Second pick: the sacrifice
        local callbackSac = Instance.new("BindableEvent")
        callbackSac.Event:Connect(function(sacId)
            callbackSac:Destroy()
            if baseId ~= sacId then
                RemoteEvents.FuseGolems:FireServer(baseId, sacId)
            end
        end)
        openFn:Invoke(data.Golems, "fuse", callbackSac)
    end)
    openFn:Invoke(data.Golems, "fuse", callbackBase)
end

-- ── Server response handlers ──────────────────────────────────────────────────
function ForgeController.OnGolemCrafted(golem)
    ForgeController.Resync()
end

function ForgeController.OnGolemDeployed(ok, golemId, zoneId, err)
    ForgeController.Resync()
end

function ForgeController.OnGolemReturned(result, golemId, err)
    ForgeController.Resync()
end

-- Draws the queue from the server's copy (so jobs that were running before you joined show up too)
function ForgeController._RenderSmeltQueue()
    if not forgeGui then return end
    local scroll = forgeGui:FindFirstChild("SmeltQueueScroll", true)
    local panel  = forgeGui:FindFirstChild("SmeltPanel", true)
    local data   = ForgeController._data
    if not scroll or not data then return end

    local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
    local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
    local ForgeDataM = require(game.ReplicatedStorage.Shared.Data.ForgeData)

    if not scroll:FindFirstChildOfClass("UIListLayout") then
        Theme.AddListLayout(scroll, Enum.FillDirection.Vertical, 6)
    end
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    smeltQueueDisplay = {}

    local jobs = data.SmeltQueue or {}
    local maxSlots = ForgeDataM.Get(data.ForgeLevel or 1).unlocks.smeltSlots

    -- header info: queue usage + speed-ups
    if panel then
        local info = panel:FindFirstChild("QueueInfo")
        if not info then
            info = Theme.Label(panel, "", Theme.TextSize.Body, Theme.Colors.TextSecondary, Theme.Fonts.Heading, "QueueInfo")
            info.Position = UDim2.new(0.4, 0, 0, 66)
            info.Size = UDim2.new(0.6, -16, 0, 24)
            info.TextXAlignment = Enum.TextXAlignment.Right
        end
        info.Text = string.format("Queue %d/%d     Speed-Ups: %d", #jobs, maxSlots, data.SpeedUps or 0)
    end

    if #jobs == 0 then
        local none = Theme.Label(scroll, "Nothing smelting. Use the Smelt button above to turn raw ore into refined materials.",
            Theme.TextSize.Body, Theme.Colors.TextDim)
        none.Size = UDim2.new(1, -8, 0, 44)
        return
    end

    for _, job in ipairs(jobs) do
        local card = Instance.new("Frame")
        card.Name = job.id
        card.Size = UDim2.new(1, -8, 0, 62)
        card.BackgroundColor3 = Theme.Colors.Panel
        card.BorderSizePixel = 0
        card.Parent = scroll
        Theme.AddCorner(card, Theme.Corner.Small)

        local inMat  = MaterialData.Get(job.materialId)
        local outMat = MaterialData.Get(job.outputId)
        local nameLbl = Theme.Label(card,
            string.format("%s  >  %s", inMat and inMat.displayName or job.materialId, outMat and outMat.displayName or job.outputId),
            Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Heading)
        nameLbl.Position = UDim2.new(0, 10, 0, 6)
        nameLbl.Size = UDim2.new(0.55, 0, 0, 22)

        local qtyLbl = Theme.Label(card, string.format("%d in  ->  %d out", job.quantity or 1, job.outputQty or 0),
            Theme.TextSize.Small, Theme.Colors.Gold)
        qtyLbl.Position = UDim2.new(0, 10, 0, 32)
        qtyLbl.Size = UDim2.new(0.55, 0, 0, 18)

        local timeLabel = Theme.Label(card, "...", Theme.TextSize.Body, Theme.Colors.Accent, Theme.Fonts.Mono, "TimeLabel")
        timeLabel.AnchorPoint = Vector2.new(1, 0.5)
        timeLabel.Position = UDim2.new(1, -110, 0.5, 0)
        timeLabel.Size = UDim2.new(0, 110, 0, 22)
        timeLabel.TextXAlignment = Enum.TextXAlignment.Right

        local speed = Theme.Button(card, "Speed Up", (data.SpeedUps or 0) > 0 and Theme.Colors.Accent or Theme.Colors.PanelAlt,
            (data.SpeedUps or 0) > 0 and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextDim, "SpeedUpButton")
        speed.AnchorPoint = Vector2.new(1, 0.5)
        speed.Position = UDim2.new(1, -8, 0.5, 0)
        speed.Size = UDim2.new(0, 92, 0, 30)
        speed.TextSize = 12
        speed.MouseButton1Click:Connect(function()
            if (data.SpeedUps or 0) > 0 then
                RemoteEvents.UseSpeedUp:FireServer(job.id)
            else
                require(script.Parent.HUDController).ShowNotification("No Speed-Ups", "Buy some in the Shop or earn them from the Season Pass.")
            end
        end)

        smeltQueueDisplay[job.id] = { frame = card, endTime = job.endTime }
    end
end

function ForgeController.OnSmeltQueued(job, err)
    if err then
        require(script.Parent.HUDController).ShowNotification("Can't smelt", tostring(err))
        return
    end
    ForgeController.Resync()
end

function ForgeController.OnSmeltCompleted(job)
    ForgeController.Resync()
end

function ForgeController.OnGolemFused(ok, golem1Id, err)
    if ok then ForgeController.Resync() end
end

function ForgeController.OnForgeUpgraded(newLevel)
    local fd = ForgeData.Get(newLevel)
    print("[ForgeController] Forge upgraded to level " .. newLevel ..
        (fd and ": " .. fd.displayName or ""))
    -- Re-render if UI visible
end

return ForgeController
