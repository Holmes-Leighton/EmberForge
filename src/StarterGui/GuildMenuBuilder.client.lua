-- Guild menu: found or join a guild, see your members and this week's challenge, claim the reward, and
-- browse the top guilds. Guild names are filtered on the server (they are written by players).

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local GuildData    = require(game.ReplicatedStorage.Shared.Data.GuildData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

RemoteEvents.Load()

local W, H = 760, 540
local tab = "Mine"
local info                     -- { mine, top } from the server
local typedName = ""

-- ── Window ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "GuildMenu"
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
local title = Theme.Label(titleBar, "Guild", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
title.Position = UDim2.new(0, 16, 0, 0)
title.Size = UDim2.new(0.6, 0, 1, 0)
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
for _, t in ipairs({ { "Mine", "My Guild" }, { "Find", "Find / Create" }, { "Top", "Top Guilds" } }) do
    local b = Theme.Button(tabCol, t[2], Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, t[1] .. "Tab")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.TextSize = 13
    tabButtons[t[1]] = b
end

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

local function Row(name, sub, color, buttonText, buttonColor, onClick, enabled, height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, height or 50)
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
    n.Size = UDim2.new(1, -150, 0, 22)
    local s = Theme.Label(row, sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    s.Position = UDim2.new(0, 22, 0, 26)
    s.Size = UDim2.new(1, -150, 0, (height or 50) - 28)
    s.TextWrapped = true
    s.TextYAlignment = Enum.TextYAlignment.Top
    if buttonText then
        local b = Theme.Button(row, buttonText, buttonColor, Color3.fromRGB(255, 255, 255))
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, -10, 0.5, 0)
        b.Size = UDim2.new(0, 110, 0, 32)
        b.TextSize = 13
        b.AutoButtonColor = enabled ~= false
        b.MouseButton1Click:Connect(function() if enabled ~= false and onClick then onClick() end end)
    end
    return row
end

local function ProgressBar(fraction, label)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -8, 0, 30)
    bar.BackgroundColor3 = Theme.Colors.PanelAlt
    bar.BorderSizePixel = 0
    bar.Parent = content
    Theme.AddCorner(bar, UDim.new(0, 15))
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = fraction >= 1 and Theme.Colors.Success or Theme.Colors.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Theme.AddCorner(fill, UDim.new(0, 15))
    local t = Theme.Label(bar, label, Theme.TextSize.Body, Color3.fromRGB(255, 255, 255), Theme.Fonts.Heading)
    t.Size = UDim2.new(1, 0, 1, 0)
    t.TextXAlignment = Enum.TextXAlignment.Center
    t.ZIndex = 3
    return bar
end

-- ── Content ───────────────────────────────────────────────────────────────────
local Reload
local function Reload_()
    local ok, fresh = pcall(function() return RemoteEvents.GetGuildInfo:InvokeServer() end)
    if ok and fresh then info = fresh end
    for id, b in pairs(tabButtons) do
        local on = id == tab
        b.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        b.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary
    end
    Clear()
    if not info then Note("Guilds are loading...", 30) return end
    local mine = info.mine

    if tab == "Top" then
        Note("This week's top guilds, ranked by everything their members mined together. Resets every week.", 40)
        if #(info.top or {}) == 0 then Note("No guild has mined anything this week yet. Be the first!", 30) return end
        for _, g in ipairs(info.top) do
            Row(string.format("#%d  %s", g.rank, g.name), string.format("%s mined this week   -   %d members", Utils.FormatNumber(g.weekly), g.members),
                g.rank == 1 and Theme.Colors.Legendary or g.rank <= 3 and Theme.Colors.Epic or Theme.Colors.Info, nil, nil, nil, nil, 50)
        end
        return
    end

    if tab == "Find" then
        if mine then
            Note("You're already in " .. mine.name .. ". Leave it first to join or found another guild.", 40)
            return
        end
        Note(string.format("A guild is up to %d players who work toward a weekly goal together. Join one by its exact name, or found your own for %d coins.",
            GuildData.MAX_MEMBERS, GuildData.CREATE_COST), 54)
        local boxRow = Instance.new("Frame")
        boxRow.Size = UDim2.new(1, -8, 0, 46)
        boxRow.BackgroundColor3 = Theme.Colors.Panel
        boxRow.BorderSizePixel = 0
        boxRow.Parent = content
        Theme.AddCorner(boxRow, Theme.Corner.Small)
        local box = Instance.new("TextBox")
        box.Name = "GuildName"
        box.PlaceholderText = "Guild name (letters, numbers, spaces)"
        box.Text = typedName
        box.ClearTextOnFocus = false
        box.TextColor3 = Theme.Colors.TextPrimary
        box.PlaceholderColor3 = Theme.Colors.TextDim
        box.BackgroundColor3 = Theme.Colors.PanelAlt
        box.BorderSizePixel = 0
        box.Font = Enum.Font.GothamMedium
        box.TextSize = 15
        box.Size = UDim2.new(1, -16, 0, 34)
        box.Position = UDim2.new(0, 8, 0, 6)
        box.Parent = boxRow
        Theme.AddCorner(box, Theme.Corner.Small)
        box:GetPropertyChangedSignal("Text"):Connect(function() typedName = box.Text end)
        Row("Join a guild", "Type its exact name above", Theme.Colors.Info, "Join", Theme.Colors.Accent,
            function() RemoteEvents.JoinGuild:FireServer(typedName) end)
        local canAfford = info.coins == nil or info.coins >= GuildData.CREATE_COST
        Row("Found a new guild", string.format("Costs %d coins. You become its leader.", GuildData.CREATE_COST), Theme.Colors.Success,
            "Found", Theme.Colors.Success, function() RemoteEvents.CreateGuild:FireServer(typedName) end, canAfford)
        return
    end

    -- My Guild
    if not mine then
        Note("You're not in a guild yet. Open the Find / Create tab to join one or found your own.", 40)
        return
    end
    Row(mine.name, string.format("%d / %d members   -   %s mined all-time", mine.memberCount, mine.maxMembers, Utils.FormatNumber(mine.total)),
        Theme.Colors.Gold, "Leave", Theme.Colors.Danger, function() RemoteEvents.LeaveGuild:FireServer() end, true, 56)
    Note("Weekly challenge: everyone's mining adds up. When the bar fills, every member who added at least "
        .. mine.minContribution .. " resources can claim " .. mine.reward.coins .. " coins and " .. mine.reward.speedUps .. " Speed-Up.", 56)
    ProgressBar(mine.weekly / math.max(1, mine.target),
        string.format("%s / %s", Utils.FormatNumber(mine.weekly), Utils.FormatNumber(mine.target)))
    if mine.complete then
        Row("Challenge complete!", mine.claimed and "You claimed this week's reward." or (mine.canClaim and "Your reward is ready." or ("Add " .. mine.minContribution .. "+ resources to share in it next time.")),
            Theme.Colors.Success, mine.claimed and "Claimed" or "Claim", mine.canClaim and Theme.Colors.Success or Theme.Colors.PanelAlt,
            function() RemoteEvents.ClaimGuildReward:FireServer() end, mine.canClaim, 54)
    end
    Note("Members (this week)", 24, Theme.Colors.AccentBright)
    for _, m in ipairs(mine.members) do
        Row(m.name .. (m.leader and "  (leader)" or ""), Utils.FormatNumber(m.weekly) .. " mined this week",
            m.leader and Theme.Colors.Gold or Theme.Colors.Info, nil, nil, nil, nil, 44)
    end
end
Reload = Reload_

for id, b in pairs(tabButtons) do
    b.MouseButton1Click:Connect(function() tab = id Say("") Reload() end)
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then Say("") task.spawn(Reload) end
end)

RemoteEvents.GuildResult.OnClientEvent:Connect(function(action, ok, message)
    Say(message or "", ok)
    if ok then
        if action == "create" or action == "join" then tab = "Mine" end
        typedName = ""
    end
    task.delay(0.3, Reload)
end)
