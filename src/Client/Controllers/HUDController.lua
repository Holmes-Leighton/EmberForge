-- Manages the persistent heads-up display: resource counters, level, notifications.

local Players     = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MaterialData = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local MaterialIcon = require(game.ReplicatedStorage.Shared.Modules.MaterialIcon)
local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local Utils      = require(game.ReplicatedStorage.Shared.Modules.Utils)
local GameConfig = require(game.ReplicatedStorage.Shared.Data.GameConfig)

local HUDController = {}

local hudGui     -- main ScreenGui reference
local StartBoostCountdowns   -- forward declaration (defined below)

-- ── Init ──────────────────────────────────────────────────────────────────────
function HUDController.Init(playerData)
    HUDController._data = playerData
    -- the list of mined items comes back when a climb ends
    Players.LocalPlayer:GetAttributeChangedSignal("TowerLevel"):Connect(function()
        if hudGui then HUDController.SetPending(HUDController._pending) end
    end)
    Players.LocalPlayer:GetAttributeChangedSignal("MazeSection"):Connect(function()
        if hudGui then HUDController.SetPending(HUDController._pending) end
    end)

    -- The HUD ScreenGui is created in StarterGui
    -- We reference it here once the player's GUI loads
    task.spawn(function()
        hudGui = PlayerGui:WaitForChild("HUD", 10)
        if not hudGui then
            warn("[HUDController] HUD ScreenGui not found")
            return
        end
        HUDController._SetupElements()
        HUDController.Refresh(playerData)
        HUDController.SetPending(HUDController._pending or playerData.Pending)
        HUDController.StartResync()
        StartBoostCountdowns(playerData)
    end)
end

function HUDController._SetupElements()
    if not hudGui then return end

    -- (nothing to wire up in the HUD itself yet)
end

-- Re-read the server's copy now and then (and after events) so slot counts, durability and the
-- smelter countdown never drift from the truth.
function HUDController.Resync()
    local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
    local ok, fresh = pcall(function() return RemoteEvents.GetPlayerData:InvokeServer() end)
    if ok and fresh then
        HUDController._data = fresh
        HUDController.Refresh(fresh)
    end
end

local resyncQueued = false
function HUDController.QueueResync()
    if resyncQueued then return end
    resyncQueued = true
    task.delay(0.6, function()
        resyncQueued = false
        HUDController.Resync()
    end)
end

function HUDController.StartResync()
    if HUDController._resyncRunning then return end
    HUDController._resyncRunning = true
    task.spawn(function()
        while hudGui and hudGui.Parent do
            task.wait(15)
            HUDController.Resync()
        end
    end)
end

-- ── Pending mined resources (per type) ────────────────────────────────────────
-- The server banks what the Golems mine every few seconds (CollectService), so there is no Collect button or list any more: this just keeps the count the badge on the Bag shows.
function HUDController.SetPending(pending)
    pending = pending or {}
    HUDController._pending = pending
    require(script.Parent.BadgeController).SetPending(pending)
end

-- ── Data Refresh ──────────────────────────────────────────────────────────────
-- (total XP at which a level begins; level 1 begins at 0, which is where everyone starts)
local function XPForLevel(level)
    if level <= 1 then return 0 end
    return math.floor(100 * level ^ 1.8)
end

-- The player card's rows, top to bottom, and their heights. Rows a new player does not need yet are hidden and the rest close up (FeatureGates.CardRows).
local CARD_ROWS = { { "ForgeRow", 30 }, { "MasteryRow", 30 }, { "GolemRow", 56 }, { "SmeltRow", 32 }, { "SpeedRow", 40, 4 }, { "GoalRow", 48 } }
local CARD_TOP, CARD_GAP = 122, 6

function HUDController.LayoutCard(data)
    local mainFrame = hudGui and hudGui:FindFirstChild("MainFrame")
    if not mainFrame then return end
    local show = require(game.ReplicatedStorage.Shared.Data.FeatureGates).CardRows(data)
    local y = CARD_TOP
    for _, r in ipairs(CARD_ROWS) do
        local row = mainFrame:FindFirstChild(r[1])
        if row then
            local visible = show[r[1]] ~= false
            row.Visible = visible
            if visible then
                row.Position = UDim2.new(0, 10, 0, y)
                y += r[2] + (r[3] or CARD_GAP)
            end
        end
    end
    mainFrame.Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset, 0, y + 4)
end

function HUDController.Refresh(data)
    if not hudGui then return end
    local mainFrame = hudGui:FindFirstChild("MainFrame")
    if not mainFrame then return end
    HUDController.LayoutCard(data)

    local function setLabel(name, text)
        local lbl = mainFrame:FindFirstChild(name, true)
        if lbl and lbl:IsA("TextLabel") then
            lbl.Text = text
        end
    end

    setLabel("GoalLabel", "🎯 " .. require(game.ReplicatedStorage.Shared.Modules.NextGoal).For(data))
    setLabel("PlayerLevelLabel", tostring(data.PlayerLevel or 1))           -- sits in the gold level badge
    setLabel("ForgeLevelLabel",  "Forge " .. (data.ForgeLevel or 1))
    setLabel("CoinsLabel",       Utils.FormatNumber(data.EmberCoins or 0))   -- "EMBER COINS" is the caption under it
    -- coins went up: fly coins to the purse and count the number up (not on the first refresh, nor when coins were spent)
    local coinsNow = data.EmberCoins or 0
    if HUDController._coins and coinsNow > HUDController._coins then
        require(script.Parent.RewardFx).CoinBurst(coinsNow - HUDController._coins, hudGui, HUDController._coins, coinsNow)
    end
    HUDController._coins = coinsNow
    -- Golems: deployed / usable slots, flagging any that have worn out
    local deployed, broken = 0, 0
    for _, g in ipairs(data.Golems or {}) do
        if g.deployed then
            deployed += 1
            if g._durabilitySeconds ~= nil and g._durabilitySeconds <= 0 then broken += 1 end
        end
    end
    local slots = data.EffectiveGolemSlots or data.GolemSlots or 3
    setLabel("GolemSlotsLabel", string.format("Golems %d/%d", deployed, slots))
    local slotLbl = mainFrame:FindFirstChild("GolemSlotsLabel", true)
    if slotLbl then
        slotLbl.TextColor3 = broken > 0 and Color3.fromRGB(230, 90, 70) or Theme.Colors.TextSecondary
        if broken > 0 then slotLbl.Text = string.format("Golems %d/%d (%d broken!)", deployed, slots, broken) end
    end
    -- one pip per slot: green = working, red = broken, hollow = free
    for i = 1, 12 do
        local pip = mainFrame:FindFirstChild("Pip" .. i, true)
        if pip then
            pip.Visible = i <= slots
            if i <= deployed - broken then
                pip.BackgroundTransparency, pip.BackgroundColor3 = 0, Color3.fromRGB(90, 200, 110)
            elseif i <= deployed then
                pip.BackgroundTransparency, pip.BackgroundColor3 = 0, Color3.fromRGB(230, 80, 60)
            else
                pip.BackgroundTransparency = 1
            end
        end
    end

    require(script.Parent.BadgeController).Update(data)
    require(script.Parent.GateController).Update(data)

    -- Smelter: how many jobs and when the next one finishes
    local jobs = data.SmeltQueue or {}
    local nextEnd
    for _, j in ipairs(jobs) do
        if not nextEnd or j.endTime < nextEnd then nextEnd = j.endTime end
    end
    if #jobs == 0 then
        setLabel("SmeltStatusLabel", "Smelter idle")
    else
        local remaining = math.max(0, nextEnd - Utils.UnixTimestamp())
        setLabel("SmeltStatusLabel", string.format("Smelting %d  (%s)", #jobs, remaining > 0 and Utils.FormatTime(remaining) or "done"))
    end

    -- Mastery: find highest mastery level across all elements
    local thresholds = GameConfig.MASTERY_XP_THRESHOLDS
    local maxLevel = data.MasteryLevels and (function()
        local best = 0
        for _, xp in pairs(data.MasteryLevels) do
            for lvl = #thresholds, 1, -1 do
                if xp >= (thresholds[lvl] or 0) then
                    if lvl > best then best = lvl end
                    break
                end
            end
        end
        return best
    end)() or 0
    setLabel("MasteryLabel", "Mastery Lv " .. maxLevel)

    -- the smelter row's stripe lights up while it is working
    local smeltRow = mainFrame:FindFirstChild("SmeltRow", true)
    local stripe = smeltRow and smeltRow:FindFirstChild("Stripe")
    if stripe then stripe.BackgroundColor3 = #jobs > 0 and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(150, 140, 125) end
    local smeltLbl = mainFrame:FindFirstChild("SmeltStatusLabel", true)
    if smeltLbl then smeltLbl.TextColor3 = #jobs > 0 and Color3.fromRGB(255, 190, 120) or Theme.Colors.TextSecondary end

    -- Animate XP bar
    local xpBarBg = hudGui:FindFirstChild("XPBarBg", true)
    if xpBarBg then
        local fill = xpBarBg:FindFirstChild("XPBarFill")
        if fill then
            local level     = data.PlayerLevel or 1
            local xp        = data.PlayerXP or 0
            local prevXP    = XPForLevel(level)
            local nextXP    = XPForLevel(level + 1)
            local ratio     = math.clamp((xp - prevXP) / math.max(nextXP - prevXP, 1), 0, 1)
            TweenService:Create(fill,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(ratio, 0, 1, 0) }
            ):Play()
            -- the same progress on the player card
            local cardFill = mainFrame:FindFirstChild("PanelXPFill", true)
            if cardFill then
                TweenService:Create(cardFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
            end
            setLabel("PanelXPText", string.format("%s / %s XP", Utils.FormatNumber(math.max(0, xp - prevXP)), Utils.FormatNumber(math.max(1, nextXP - prevXP))))
        end
    end
end

-- ── Active boost countdowns ───────────────────────────────────────────────────
function StartBoostCountdowns(data)
    task.spawn(function()
        while hudGui and hudGui.Parent do
            task.wait(5)
            local now = tick()

            local magnetLbl  = hudGui:FindFirstChild("MagnetBoostLabel", true)
            local slotLbl    = hudGui:FindFirstChild("SlotBoostLabel", true)

            if magnetLbl then
                local expiry  = data.MaterialMagnetExpiry or 0
                local remaining = math.max(0, expiry - now)
                magnetLbl.Visible = remaining > 0
                if remaining > 0 then
                    magnetLbl.Text = "🧲 Magnet " .. Utils.FormatTime(remaining)
                end
            end

            if slotLbl then
                local expiry  = data.TempSlotBoostExpiry or 0
                local remaining = math.max(0, expiry - now)
                slotLbl.Visible = remaining > 0
                if remaining > 0 then
                    slotLbl.Text = "⬆ +Slot " .. Utils.FormatTime(remaining)
                end
            end
        end
    end)
end

-- ── Resource update (called on tick) ──────────────────────────────────────────
-- Pad pickups: every material pops out of your character in its own random direction (an arc up and out, then it drops a little and fades), in
-- the material's rarity colour, like the loot bursts in other games. Several pickups at once never sit in a column.
local popGui
local activePops = 0
local MAX_POPS = 16
local popRandom = Random.new()

function HUDController.PadPop(gains)
    if not popGui or not popGui.Parent then
        popGui = Instance.new("ScreenGui")
        popGui.Name = "PadPops"
        popGui.ResetOnSpawn = false
        popGui.IgnoreGuiInset = true
        popGui.DisplayOrder = 8
        popGui.Parent = PlayerGui
    end
    local cam = workspace.CurrentCamera
    local origin = Vector2.new(popGui.AbsoluteSize.X / 2, popGui.AbsoluteSize.Y * 0.55)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and cam then
        local v, onScreen = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 2.5, 0))
        if onScreen then origin = Vector2.new(v.X, v.Y) end
    end
    local ids = {}
    for matId, qty in pairs(gains) do
        if qty >= 1 and not tostring(matId):find("^__") then table.insert(ids, matId) end
    end
    table.sort(ids)
    for _, matId in ipairs(ids) do
        if activePops >= MAX_POPS then return end
        local mat = MaterialData.Get(matId)
        local lbl = Instance.new("TextLabel")
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.Size = UDim2.new(0, 190, 0, 26)
        lbl.Position = UDim2.new(0, origin.X + popRandom:NextNumber(-12, 12), 0, origin.Y + popRandom:NextNumber(-8, 8))
        lbl.BackgroundTransparency = 1
        lbl.Text = "+" .. Utils.FormatNumber(gains[matId]) .. " " .. (mat and mat.displayName or matId)
        local colour = MaterialData.Color(matId) or (mat and Theme.Colors[mat.rarity]) or Color3.fromRGB(255, 220, 60)
        lbl.TextColor3 = colour
        -- a dark material (coal) gets a light outline so it still reads against the cavern
        local h, s, v = colour:ToHSV()
        lbl.TextStrokeColor3 = v < 0.5 and Color3.fromRGB(235, 235, 240) or Color3.fromRGB(10, 6, 4)
        lbl.TextStrokeTransparency = 0.15
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextSize = popRandom:NextInteger(18, 24)
        lbl.Rotation = popRandom:NextNumber(-8, 8)
        lbl.Parent = popGui
        activePops += 1
        -- mostly up and out to either side, sometimes sideways or down-and-out: a random direction every time
        local angle = popRandom:NextNumber(0, 1) < 0.8 and math.rad(popRandom:NextNumber(205, 335)) or math.rad(popRandom:NextNumber(0, 360))
        local reach = popRandom:NextNumber(70, 190)
        local peak = UDim2.new(0, origin.X + math.cos(angle) * reach, 0, origin.Y + math.sin(angle) * reach)
        local fall = UDim2.new(0, origin.X + math.cos(angle) * reach * 1.15, 0, origin.Y + math.sin(angle) * reach + popRandom:NextNumber(18, 40))
        local out = TweenService:Create(lbl, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = peak })
        local away = TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = fall, TextTransparency = 1, TextStrokeTransparency = 1 })
        out.Completed:Connect(function() away:Play() end)
        away.Completed:Connect(function()
            activePops -= 1
            lbl:Destroy()
        end)
        out:Play()
    end
end

function HUDController.OnResourceUpdate(gains, elapsed)
    if not hudGui then return end
    if elapsed == 0 then              -- a mining pad (0), as opposed to what the Golems mined being banked (-1 asked for, -2 by itself) or the coin refresh (nothing)
        HUDController.PadPop(gains)
        return
    end
    -- Animate +N resource counters floating up (visual only)
    -- one label per update (a line per material, by display name) so several pickups never print on top of each other
    local lines = {}
    for matId, qty in pairs(gains) do
        if qty >= 1 and not tostring(matId):find("^__") then
            local mat = MaterialData.Get(matId)
            local text = "+" .. Utils.FormatNumber(qty) .. " " .. (mat and mat.displayName or matId)
            local colour = MaterialData.Color(matId) or (mat and Theme.Colors[mat.rarity])
            if colour then text = string.format('<font color="#%s">%s</font>', colour:ToHex(), text) end   -- each line in its material's colour
            table.insert(lines, text)
        end
    end
    table.sort(lines)
    if #lines > 0 then HUDController._FloatText(table.concat(lines, "\n"), #lines) end
end

function HUDController._FloatText(text, lineCount)
    lineCount = lineCount or 1
    -- Creates a brief floating text label on screen
    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "FloatText_" .. tick()
    screenGui.Parent = PlayerGui

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 260, 0, 30 * lineCount)
    lbl.Position = UDim2.new(0.5, -130, 0.6, 0)
    lbl.BackgroundTransparency = 1
    lbl.RichText = true
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 220, 60)
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 22
    lbl.Parent = screenGui

    local tween = TweenService:Create(lbl,
        TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -130, 0.42, 0), TextTransparency = 1, TextStrokeTransparency = 1 }
    )
    tween:Play()
    tween.Completed:Connect(function()
        screenGui:Destroy()
    end)
end

-- ── Notifications: stacking, colour-coded toasts ──────────────────────────────
local toastHolder
local MAX_TOASTS = 4
local TOAST_SECONDS = 3.6

local function ToastKind(title)
    local t = tostring(title):lower()
    if t:find("can't") or t:find("cannot") or t:find("fail") or t:find("error") or t:find("not enough") or t:find("no free") then
        return Theme.Colors.Danger, "!"
    elseif t:find("level") or t:find("complete") or t:find("crafted") or t:find("upgrade") or t:find("neon") or t:find("unlock") or t:find("!") then
        return Theme.Colors.Gold, "★"
    end
    return Theme.Colors.Info, "i"
end

local ScreenMode = require(game.ReplicatedStorage.Shared.Modules.ScreenMode)

local function EnsureToastHolder()
    if toastHolder and toastHolder.Parent then return toastHolder end
    local sg = Instance.new("ScreenGui")
    sg.Name = "Toasts"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 50
    sg.Parent = PlayerGui
    toastHolder = Instance.new("Frame")
    toastHolder.Name = "Stack"
    toastHolder.AnchorPoint = Vector2.new(1, 0)
    toastHolder.Position = UDim2.new(1, -108, 0, 16)           -- clear of the button column on the right
    toastHolder.Size = UDim2.new(0, 320, 1, -32)
    if ScreenMode.Compact() then                               -- a phone: a slim strip of small toasts in the top corner, never a wall over the game
        toastHolder.Position = UDim2.new(1, -92, 0, 6)
        toastHolder.Size = UDim2.new(0, 210, 0, 110)
    end
    toastHolder.BackgroundTransparency = 1
    toastHolder.Parent = sg
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Parent = toastHolder
    return toastHolder
end

local toastOrder = 0
-- The material a toast is about (its display name appears in the text, longest name first so "Refined Ore" beats "Ore"), or nil
local materialNames
function HUDController.MaterialInText(text)
    if not materialNames then
        materialNames = {}
        for id, mat in pairs(MaterialData.All) do
            if mat.displayName then table.insert(materialNames, { id = id, name = mat.displayName:lower() }) end
        end
        table.sort(materialNames, function(a, b) return #a.name > #b.name end)
    end
    local lower = tostring(text):lower()
    for _, m in ipairs(materialNames) do
        if lower:find(m.name, 1, true) then return m.id end
    end
    return nil
end

function HUDController.ShowNotification(title, message)
    local holder = EnsureToastHolder()
    title, message = tostring(title), tostring(message or "")

    -- The same message again: bump a counter on the existing toast instead of stacking copies
    for _, t in ipairs(holder:GetChildren()) do
        if t:IsA("Frame") and t:GetAttribute("Key") == title .. "|" .. message then
            local n = (t:GetAttribute("Count") or 1) + 1
            t:SetAttribute("Count", n)
            t:SetAttribute("Expires", os.clock() + TOAST_SECONDS)
            local lbl = t:FindFirstChild("Title")
            if lbl then lbl.Text = title .. "  x" .. n end
            return
        end
    end

    local compact = ScreenMode.Compact()
    local color, glyph = ToastKind(title)
    toastOrder += 1
    local toast = Instance.new("Frame")
    toast.Name = "Toast"
    toast.LayoutOrder = toastOrder
    toast.Size = UDim2.new(1, 0, 0, compact and 40 or 76)           -- room for a two-line message (one slim line on a phone)
    toast.BackgroundColor3 = Theme.Colors.Panel
    toast.BorderSizePixel = 0
    toast:SetAttribute("Key", title .. "|" .. message)
    toast:SetAttribute("Expires", os.clock() + (compact and 2.6 or TOAST_SECONDS))
    toast.Parent = holder
    Theme.AddCorner(toast, Theme.Corner.Medium)
    Theme.AddStroke(toast, color, 2)

    local badge = Instance.new("TextLabel")
    badge.Size = compact and UDim2.new(0, 24, 0, 24) or UDim2.new(0, 38, 0, 38)
    badge.Position = compact and UDim2.new(0, 6, 0.5, -12) or UDim2.new(0, 10, 0.5, -19)
    badge.BackgroundColor3 = color
    badge.Text = glyph
    badge.TextColor3 = Color3.fromRGB(30, 20, 14)
    badge.Font = Enum.Font.GothamBlack
    badge.TextSize = 22
    badge.BorderSizePixel = 0
    badge.Parent = toast
    Theme.AddCorner(badge, UDim.new(1, 0))
    local matId = HUDController.MaterialInText(message)
    if matId then MaterialIcon.Overlay(badge, matId) end        -- a toast about a material shows that material's spinning mesh

    local titleLbl = Theme.Label(toast, title, Theme.TextSize.Heading, color, Theme.Fonts.Heading, "Title")
    titleLbl.Position = compact and UDim2.new(0, 36, 0, 2) or UDim2.new(0, 58, 0, 6)
    titleLbl.Size = compact and UDim2.new(1, -42, 0, 16) or UDim2.new(1, -66, 0, 24)
    if compact then titleLbl.TextSize = 12 end
    titleLbl.TextWrapped = false
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    local msgLbl = Theme.Label(toast, message, Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Body, "Message")
    msgLbl.Position = compact and UDim2.new(0, 36, 0, 18) or UDim2.new(0, 58, 0, 30)
    msgLbl.Size = compact and UDim2.new(1, -42, 0, 18) or UDim2.new(1, -66, 0, 40)
    if compact then msgLbl.TextSize = 10 end
    msgLbl.TextWrapped = true
    msgLbl.TextYAlignment = Enum.TextYAlignment.Top
    msgLbl.TextTruncate = Enum.TextTruncate.AtEnd

    -- Pop in
    local scale = Instance.new("UIScale")
    scale.Scale = 0.6
    scale.Parent = toast
    pcall(function()
        TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    end)

    -- Keep at most MAX_TOASTS on screen: retire the oldest early
    local kids = {}
    for _, t in ipairs(holder:GetChildren()) do
        if t:IsA("Frame") then table.insert(kids, t) end
    end
    table.sort(kids, function(x, y) return x.LayoutOrder < y.LayoutOrder end)
    for i = 1, #kids - (compact and 2 or MAX_TOASTS) do
        if compact then kids[i]:Destroy() else kids[i]:SetAttribute("Expires", 0) end        -- (on a phone an extra toast goes at once)
    end

    task.spawn(function()
        while toast.Parent and os.clock() < (toast:GetAttribute("Expires") or 0) do task.wait(0.2) end
        if not toast.Parent then return end
        pcall(function()
            local tw = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
            tw:Play()
            task.wait(0.2)
        end)
        toast:Destroy()
    end)
end

-- ── Level up banner ───────────────────────────────────────────────────────────
function HUDController.ShowLevelUp(newLevel)
    HUDController.ShowNotification("Level Up!", "You are now Player Level " .. newLevel)
end

-- ── Achievement toast ─────────────────────────────────────────────────────────
function HUDController.ShowAchievement(achievementId)
    local ChallengeData = require(game.ReplicatedStorage.Shared.Data.ChallengeData)
    local ach = ChallengeData.Get(achievementId)
    local name = ach and ach.displayName or achievementId
    HUDController.ShowNotification("Achievement Unlocked!", name)
end

return HUDController
