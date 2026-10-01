-- Rewards menu: your daily login streak, redeem codes, and the seasonal ranked ladder.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local StreakData   = require(game.ReplicatedStorage.Shared.Data.StreakData)
local LadderData   = require(game.ReplicatedStorage.Shared.Data.LadderData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

RemoteEvents.Load()

local W, H = 760, 540
local tab = "Daily"
local typedCode = ""

-- ── Window ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "RewardsMenu"
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
local title = Theme.Label(titleBar, "Rewards", Theme.TextSize.Title, Theme.Colors.AccentBright, Theme.Fonts.Title, "Title")
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
for _, t in ipairs({ { "Daily", "Daily Streak" }, { "Codes", "Codes" }, { "Ranked", "Ranked Ladder" } }) do
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
    local reserve = buttonText and 150 or 30
    local n = Theme.Label(row, name, Theme.TextSize.Heading, Theme.Colors.TextPrimary, Theme.Fonts.Heading)
    n.Position = UDim2.new(0, 22, 0, 4)
    n.Size = UDim2.new(1, -reserve, 0, 22)
    local s = Theme.Label(row, sub, Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Body)
    s.Position = UDim2.new(0, 22, 0, 26)
    s.Size = UDim2.new(1, -reserve, 0, (height or 50) - 28)
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

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    local d, h = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600)
    if d > 0 then return string.format("%dd %dh", d, h) end
    return string.format("%dh %dm", h, math.floor(seconds % 3600 / 60))
end

-- ── Content ───────────────────────────────────────────────────────────────────
local function ShowDaily()
    local ok, s = pcall(function() return RemoteEvents.GetStreakInfo:InvokeServer() end)
    if not ok or not s then Note("Loading...", 30) return end
    local alive = s.lastDay == s.today or s.lastDay == s.today - 1
    local streak = alive and s.count or 0
    local doneToday = s.lastDay == s.today
    Note(string.format("Log in on consecutive days to climb the 7-day reward ladder. Streak: %d day%s (best %d). %s",
        streak, streak == 1 and "" or "s", s.best,
        doneToday and "Today's reward is collected. Come back tomorrow!" or "Log in to collect today's reward."), 56)
    local currentDay = doneToday and StreakData.LadderDay(math.max(1, s.count)) or StreakData.LadderDay(streak + 1)
    for day, r in ipairs(StreakData.Rewards) do
        local state = day < currentDay and "Collected" or day == currentDay and (doneToday and "Collected today" or "Next up") or ""
        Row("Day " .. day, StreakData.Describe(r), day == 7 and Theme.Colors.Legendary or day == currentDay and Theme.Colors.Success or Theme.Colors.Info,
            nil, nil, nil, nil, day == 7 and 50 or 42).Name = "Day" .. day
        if state ~= "" then
            local row = content:FindFirstChild("Day" .. day)
            local lbl = Theme.Label(row, state, Theme.TextSize.Small, Theme.Colors.Success, Theme.Fonts.Heading)
            lbl.AnchorPoint = Vector2.new(1, 0.5)
            lbl.Position = UDim2.new(1, -12, 0.5, 0)
            lbl.Size = UDim2.new(0, 130, 0, 20)
            lbl.TextXAlignment = Enum.TextXAlignment.Right
        end
    end
end

local function ShowCodes()
    Note("Got a code from a creator or an event? Type it here for a reward. Each code works once per player.", 40)
    local boxRow = Instance.new("Frame")
    boxRow.Size = UDim2.new(1, -8, 0, 46)
    boxRow.BackgroundColor3 = Theme.Colors.Panel
    boxRow.BorderSizePixel = 0
    boxRow.Parent = content
    Theme.AddCorner(boxRow, Theme.Corner.Small)
    local box = Instance.new("TextBox")
    box.Name = "CodeBox"
    box.PlaceholderText = "Enter code"
    box.Text = typedCode
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
    box:GetPropertyChangedSignal("Text"):Connect(function() typedCode = box.Text end)
    Row("Redeem", "Press to claim the code above", Theme.Colors.Success, "Redeem", Theme.Colors.Success,
        function() RemoteEvents.RedeemCode:FireServer(typedCode) end, true, 46)
end

local function ShowRanked()
    local ok, info = pcall(function() return RemoteEvents.GetLadderInfo:InvokeServer() end)
    if not ok or not info then Note("Loading...", 30) return end
    Note(string.format("Ranked season %d ends in %s. Everything you mine earns Ladder Points. Climb the tiers, and the top 100 players earn bonus prizes you claim next season.",
        info.season, Clock(info.endsAt - workspace:GetServerTimeNow())), 56)
    Row(string.format("You: %s tier", info.tier), string.format("%s points%s%s", Utils.FormatNumber(info.points),
            info.rank and string.format("   -   rank #%d", info.rank) or "",
            info.nextTier and string.format("   -   %s to reach %s", Utils.FormatNumber(info.pointsToNext), info.nextTier) or "   -   top tier!"),
        info.tierColor, nil, nil, nil, nil, 54)
    if info.prize then
        local p = info.prize.prize
        Row("Last season's prize", string.format("Finished %s tier%s: %d coins%s%s. %s", p.tierName, info.prize.rank and (" (rank #" .. info.prize.rank .. ")") or "", p.coins,
            (p.speedUps or 0) > 0 and (" + " .. p.speedUps .. " Speed-Ups") or "", p.title and (" + the " .. p.title .. " title") or "",
            info.prize.claimed and "Claimed." or "Ready to claim."),
            Theme.Colors.Legendary, info.prize.claimed and "Claimed" or "Claim", info.prize.claimed and Theme.Colors.PanelAlt or Theme.Colors.Success,
            function() RemoteEvents.ClaimLadderPrize:FireServer() end, not info.prize.claimed, 66)
    end
    Note("Tiers", 22, Theme.Colors.AccentBright)
    for _, t in ipairs(LadderData.Tiers) do
        Row(t.name, string.format("%s points   -   season reward %d coins", Utils.FormatNumber(t.points), t.coins), t.color, nil, nil, nil, nil, 40)
    end
    Note("Top players this season", 22, Theme.Colors.AccentBright)
    if #info.top == 0 then Note("Nobody has mined this season yet. Be the first!", 28) end
    for _, e in ipairs(info.top) do
        Row(string.format("#%d  %s", e.rank, e.name), string.format("%s points   -   %s", Utils.FormatNumber(e.points), e.tier),
            e.rank == 1 and Theme.Colors.Legendary or e.rank <= 3 and Theme.Colors.Epic or Theme.Colors.Info, nil, nil, nil, nil, 40)
    end
end

local function Reload()
    for id, b in pairs(tabButtons) do
        local on = id == tab
        b.BackgroundColor3 = on and Theme.Colors.Accent or Theme.Colors.PanelAlt
        b.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Theme.Colors.TextSecondary
    end
    Clear()
    if tab == "Daily" then ShowDaily() elseif tab == "Codes" then ShowCodes() else ShowRanked() end
end

for id, b in pairs(tabButtons) do
    b.MouseButton1Click:Connect(function() tab = id Say("") Reload() end)
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if gui.Enabled then Say("") task.spawn(Reload) end
end)

RemoteEvents.RewardsResult.OnClientEvent:Connect(function(action, ok, message)
    Say(message or "", ok)
    if ok and action == "code" then typedCode = "" end
    task.delay(0.3, function() if gui.Enabled then Reload() end end)
end)
