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
local typedInvite = ""
local lastChatKey = ""

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
for _, t in ipairs({ { "Mine", "My Guild" }, { "Chat", "Guild Chat" }, { "Find", "Find / Create" }, { "Top", "Top Guilds" } }) do
    local b = Theme.Button(tabCol, t[2], Theme.Colors.PanelAlt, Theme.Colors.TextSecondary, t[1] .. "Tab")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.TextSize = 13
    tabButtons[t[1]] = b
end

local content = Theme.ScrollFrame(container, "Content")
content.Position = UDim2.new(0, 166, 0, 58)
content.Size = UDim2.new(1, -174, 1, -92)
Theme.AddListLayout(content, Enum.FillDirection.Vertical, 6)

-- chat input: lives outside the scrolling list so refreshing the messages never steals the keyboard
local chatBar = Instance.new("Frame")
chatBar.Name = "ChatBar"
chatBar.Position = UDim2.new(0, 166, 1, -72)
chatBar.Size = UDim2.new(1, -174, 0, 40)
chatBar.BackgroundColor3 = Theme.Colors.Panel
chatBar.BorderSizePixel = 0
chatBar.Visible = false
chatBar.Parent = container
Theme.AddCorner(chatBar, Theme.Corner.Small)
local chatBox = Instance.new("TextBox")
chatBox.Name = "ChatBox"
chatBox.PlaceholderText = "Message your guild..."
chatBox.Text = ""
chatBox.ClearTextOnFocus = false
chatBox.TextColor3 = Theme.Colors.TextPrimary
chatBox.PlaceholderColor3 = Theme.Colors.TextDim
chatBox.BackgroundColor3 = Theme.Colors.PanelAlt
chatBox.BorderSizePixel = 0
chatBox.Font = Enum.Font.GothamMedium
chatBox.TextSize = 14
chatBox.TextXAlignment = Enum.TextXAlignment.Left
chatBox.Size = UDim2.new(1, -100, 0, 30)
chatBox.Position = UDim2.new(0, 6, 0, 5)
chatBox.Parent = chatBar
Theme.AddCorner(chatBox, Theme.Corner.Small)
local sendBtn = Theme.Button(chatBar, "Send", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "SendButton")
sendBtn.Size = UDim2.new(0, 80, 0, 30)
sendBtn.AnchorPoint = Vector2.new(1, 0)
sendBtn.Position = UDim2.new(1, -6, 0, 5)
sendBtn.TextSize = 13

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

local function Row(name, sub, color, buttonText, buttonColor, onClick, enabled, height, b2Text, b2Color, b2Click)
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
    if b2Text then      -- a second button to the left of the first (the leader's member tools)
        n.Size = UDim2.new(1, -270, 0, 22)
        s.Size = UDim2.new(1, -270, 0, (height or 50) - 28)
        local b2 = Theme.Button(row, b2Text, b2Color, Color3.fromRGB(255, 255, 255))
        b2.AnchorPoint = Vector2.new(1, 0.5)
        b2.Position = UDim2.new(1, -128, 0.5, 0)
        b2.Size = UDim2.new(0, 110, 0, 32)
        b2.TextSize = 13
        b2.MouseButton1Click:Connect(function() if b2Click then b2Click() end end)
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
    chatBar.Visible = (tab == "Chat")
    content.Size = UDim2.new(1, -174, 1, tab == "Chat" and -138 or -92)
    if not info then Note("Guilds are loading...", 30) return end
    local mine = info.mine

    if tab == "Chat" then
        if not mine then Note("Join a guild to use its chat.", 30) chatBar.Visible = false return end
        local okC, list = pcall(function() return RemoteEvents.GetGuildChat:InvokeServer() end)
        list = okC and list or {}
        lastChatKey = #list .. ":" .. tostring(list[#list] and list[#list].t)
        if #list == 0 then Note("No messages yet. Say hello!", 30) end
        for _, m in ipairs(list) do
            local own = tostring(m.userId) == tostring(LocalPlayer.UserId)
            local l = Theme.Label(content, (own and "You" or m.name) .. ":  " .. m.text, Theme.TextSize.Body,
                own and Theme.Colors.AccentBright or Theme.Colors.TextPrimary, Theme.Fonts.Body)
            l.Size = UDim2.new(1, -8, 0, 0)
            l.AutomaticSize = Enum.AutomaticSize.Y
            l.TextWrapped = true
            l.TextYAlignment = Enum.TextYAlignment.Top
        end
        task.defer(function() content.CanvasPosition = Vector2.new(0, 1e6) end)      -- jump to the newest message
        return
    end

    if tab == "Top" then
        local pl = {}
        for _, p in ipairs(GuildData.Prizes) do
            table.insert(pl, string.format("%s: %d coins + %d Speed-Up%s", p.label, p.coins, p.speedUps, p.title and (" + " .. p.title .. " title") or ""))
        end
        Note("This week's top guilds, ranked by everything their members mined together. When the week ends, the top 10 win prizes that every contributing member can claim:\n"
            .. table.concat(pl, "\n"), 100)
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
    local nextLine = mine.nextLevelTotal and string.format("Next level at %s mined together.", Utils.FormatNumber(mine.nextLevelTotal)) or "Maximum level!"
    Row(string.format("Guild Level %d", mine.level), string.format("Every member gets +%d%% mining speed. %s", math.floor(mine.levelBonus * 100 + 0.5), nextLine),
        Theme.Colors.Epic, "Guild Hall", Theme.Colors.Success, function() RemoteEvents.GoToGuildHall:FireServer() gui.Enabled = false end, true, 54)
    local inviteRow = Instance.new("Frame")
    inviteRow.Size = UDim2.new(1, -8, 0, 46)
    inviteRow.BackgroundColor3 = Theme.Colors.Panel
    inviteRow.BorderSizePixel = 0
    inviteRow.Parent = content
    Theme.AddCorner(inviteRow, Theme.Corner.Small)
    local inviteBox = Instance.new("TextBox")
    inviteBox.Name = "InviteBox"
    inviteBox.PlaceholderText = "Invite a player on this server (their name)"
    inviteBox.Text = typedInvite
    inviteBox.ClearTextOnFocus = false
    inviteBox.TextColor3 = Theme.Colors.TextPrimary
    inviteBox.PlaceholderColor3 = Theme.Colors.TextDim
    inviteBox.BackgroundColor3 = Theme.Colors.PanelAlt
    inviteBox.BorderSizePixel = 0
    inviteBox.Font = Enum.Font.GothamMedium
    inviteBox.TextSize = 14
    inviteBox.TextXAlignment = Enum.TextXAlignment.Left
    inviteBox.Size = UDim2.new(1, -130, 0, 34)
    inviteBox.Position = UDim2.new(0, 8, 0, 6)
    inviteBox.Parent = inviteRow
    Theme.AddCorner(inviteBox, Theme.Corner.Small)
    inviteBox:GetPropertyChangedSignal("Text"):Connect(function() typedInvite = inviteBox.Text end)
    local inviteBtn = Theme.Button(inviteRow, "Invite", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255), "InviteButton")
    inviteBtn.AnchorPoint = Vector2.new(1, 0.5)
    inviteBtn.Position = UDim2.new(1, -8, 0.5, 0)
    inviteBtn.Size = UDim2.new(0, 100, 0, 32)
    inviteBtn.TextSize = 13
    inviteBtn.MouseButton1Click:Connect(function() RemoteEvents.InviteToGuild:FireServer(typedInvite) end)
    Note("Weekly challenge: everyone's mining adds up. When the bar fills, every member who added at least "
        .. mine.minContribution .. " resources can claim " .. mine.reward.coins .. " coins and " .. mine.reward.speedUps .. " Speed-Up.", 56)
    ProgressBar(mine.weekly / math.max(1, mine.target),
        string.format("%s / %s", Utils.FormatNumber(mine.weekly), Utils.FormatNumber(mine.target)))
    if mine.complete then
        Row("Challenge complete!", mine.claimed and "You claimed this week's reward." or (mine.canClaim and "Your reward is ready." or ("Add " .. mine.minContribution .. "+ resources to share in it next time.")),
            Theme.Colors.Success, mine.claimed and "Claimed" or "Claim", mine.canClaim and Theme.Colors.Success or Theme.Colors.PanelAlt,
            function() RemoteEvents.ClaimGuildReward:FireServer() end, mine.canClaim, 54)
    end
    local pz = mine.prize
    if pz then
        Row(string.format("Last week: your guild finished #%d!", pz.rank),
            string.format("Prize: %d coins + %d Speed-Up%s. %s", pz.prize.coins, pz.prize.speedUps, pz.prize.title and (" + the " .. pz.prize.title .. " title") or "",
                pz.claimed and "You claimed it." or (pz.canClaim and "Your prize is ready." or ("You needed " .. mine.minContribution .. "+ resources last week."))),
            Theme.Colors.Legendary, pz.claimed and "Claimed" or "Claim", pz.canClaim and Theme.Colors.Success or Theme.Colors.PanelAlt,
            function() RemoteEvents.ClaimGuildPrize:FireServer() end, pz.canClaim, 64)
    end
    Note("Members (this week)", 24, Theme.Colors.AccentBright)
    for _, m in ipairs(mine.members) do
        local label = m.name .. (m.leader and "  (leader)" or "")
        local sub = Utils.FormatNumber(m.weekly) .. " mined this week"
        local color = m.leader and Theme.Colors.Gold or Theme.Colors.Info
        if mine.isLeader and not m.leader then       -- the leader can remove a member or hand over the guild
            Row(label, sub, color, "Remove", Theme.Colors.Danger, function() RemoteEvents.ManageGuild:FireServer("kick", m.userId) end, true, 44,
                "Make leader", Theme.Colors.Accent, function() RemoteEvents.ManageGuild:FireServer("promote", m.userId) end)
        else
            Row(label, sub, color, nil, nil, nil, nil, 44)
        end
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
        if action == "invite" then typedInvite = "" end
        typedName = ""
    end
    if gui.Enabled then task.delay(0.3, Reload) end
end)

-- ── Guild chat ────────────────────────────────────────────────────────────────
local function SendChat()
    local text = chatBox.Text
    if text:gsub("%s", "") == "" then return end
    chatBox.Text = ""
    RemoteEvents.SendGuildChat:FireServer(text)
    task.delay(0.6, function() if gui.Enabled and tab == "Chat" then Reload() end end)
end
sendBtn.MouseButton1Click:Connect(SendChat)
chatBox.FocusLost:Connect(function(enter) if enter then SendChat() end end)

-- while the chat tab is open, pull new messages every few seconds (only redraws when something changed)
task.spawn(function()
    while true do
        task.wait(4)
        if gui.Enabled and tab == "Chat" then
            local ok, list = pcall(function() return RemoteEvents.GetGuildChat:InvokeServer() end)
            if ok and type(list) == "table" then
                local key = #list .. ":" .. tostring(list[#list] and list[#list].t)
                if key ~= lastChatKey then Reload() end
            end
        end
    end
end)

-- ── Invite popup: shows who invited you, with their avatar ────────────────────
local inviteGui = Instance.new("ScreenGui")
inviteGui.Name = "GuildInvitePopup"
inviteGui.ResetOnSpawn = false
inviteGui.DisplayOrder = 40
inviteGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
inviteGui.Enabled = false
inviteGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 70)
card.Size = UDim2.new(0, 380, 0, 120)
card.BackgroundColor3 = Theme.Colors.Panel
card.BorderSizePixel = 0
card.Parent = inviteGui
Theme.AddCorner(card, Theme.Corner.Large)
Theme.AddStroke(card, Theme.Colors.Accent, 2, 0.1)
ScaleUI.ApplyHud(card)
local avatar = Instance.new("ImageLabel")
avatar.Name = "Avatar"
avatar.Size = UDim2.new(0, 72, 0, 72)
avatar.Position = UDim2.new(0, 14, 0, 14)
avatar.BackgroundColor3 = Theme.Colors.PanelAlt
avatar.BorderSizePixel = 0
avatar.Parent = card
Theme.AddCorner(avatar, UDim.new(0, 36))
local inviteTitle = Theme.Label(card, "", Theme.TextSize.Heading, Theme.Colors.AccentBright, Theme.Fonts.Heading, "InviteTitle")
inviteTitle.Position = UDim2.new(0, 98, 0, 12)
inviteTitle.Size = UDim2.new(1, -110, 0, 24)
local inviteText = Theme.Label(card, "", Theme.TextSize.Body, Theme.Colors.TextPrimary, Theme.Fonts.Body, "InviteText")
inviteText.Position = UDim2.new(0, 98, 0, 38)
inviteText.Size = UDim2.new(1, -110, 0, 44)
inviteText.TextWrapped = true
inviteText.TextYAlignment = Enum.TextYAlignment.Top
local acceptBtn = Theme.Button(card, "Accept", Theme.Colors.Success, Color3.fromRGB(255, 255, 255), "Accept")
acceptBtn.Size = UDim2.new(0, 110, 0, 30)
acceptBtn.Position = UDim2.new(1, -240, 1, -40)
acceptBtn.TextSize = 14
local declineBtn = Theme.Button(card, "Decline", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "Decline")
declineBtn.Size = UDim2.new(0, 110, 0, 30)
declineBtn.Position = UDim2.new(1, -120, 1, -40)
declineBtn.TextSize = 14

local inviteToken = 0
acceptBtn.MouseButton1Click:Connect(function() inviteGui.Enabled = false RemoteEvents.RespondGuildInvite:FireServer(true) end)
declineBtn.MouseButton1Click:Connect(function() inviteGui.Enabled = false RemoteEvents.RespondGuildInvite:FireServer(false) end)

RemoteEvents.GuildInvite.OnClientEvent:Connect(function(guildName, fromName, fromUserId)
    inviteToken += 1
    local mine = inviteToken
    inviteTitle.Text = "Guild invite"
    inviteText.Text = string.format("%s invited you to join %s.", tostring(fromName), tostring(guildName))
    avatar.Image = ""
    if type(fromUserId) == "number" then
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(fromUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            end)
            if ok and mine == inviteToken then avatar.Image = img end
        end)
    end
    inviteGui.Enabled = true
    task.delay(110, function() if mine == inviteToken then inviteGui.Enabled = false end end)      -- the server forgets it after 2 minutes
end)
