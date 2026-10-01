-- The admin panel: a small "Admin" button (only for admins, see AdminService: the EFAdmin player attribute) that opens a tool window to
-- gift coins / materials, start or clear XP and drop events, announce to the server, and look a player up (trade / market log, reports,
-- recent admin actions). Everything is checked again on the server; this is only the front end.

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI      = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)

RemoteEvents.Load()

local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local toggle = Theme.Button(gui, "Admin", Theme.Colors.Danger, Color3.fromRGB(255, 255, 255), "AdminButton")
toggle.Size = UDim2.new(0, 70, 0, 28)
toggle.Position = UDim2.new(0, 10, 0, 10)
toggle.TextSize = 13
toggle.Visible = false

local window = Theme.Panel(gui, "Window", Theme.Colors.Background)
window.Size = UDim2.new(0, 460, 0, 520)
window.AnchorPoint = Vector2.new(0, 0)
window.Position = UDim2.new(0, 10, 0, 44)
window.Visible = false
ScaleUI.ApplyHud(window)

local title = Theme.Label(window, "Admin panel", Theme.TextSize.Heading, Theme.Colors.Danger, Theme.Fonts.Heading, "Title")
title.Position, title.Size = UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 22)

local body = Theme.ScrollFrame(window, "Body")
body.Position, body.Size = UDim2.new(0, 10, 0, 34), UDim2.new(1, -20, 1, -44)
Theme.AddListLayout(body, Enum.FillDirection.Vertical, 6)

local order = 0
local function nextOrder() order += 1 return order end

local function Heading(text)
    local l = Theme.Label(body, text, Theme.TextSize.Body, Theme.Colors.AccentBright, Theme.Fonts.Heading, "Heading")
    l.Size, l.LayoutOrder = UDim2.new(1, -8, 0, 20), nextOrder()
end

-- A row of text boxes (each { placeholder, width, default }) followed by buttons ({ text, colour, handler })
local function Row(fields, buttons)
    local row = Instance.new("Frame")
    row.Name, row.BackgroundTransparency, row.Size, row.LayoutOrder = "Row", 1, UDim2.new(1, -8, 0, 30), nextOrder()
    row.Parent = body
    Theme.AddListLayout(row, Enum.FillDirection.Horizontal, 6)
    local boxes = {}
    for _, f in ipairs(fields) do
        local box = Instance.new("TextBox")
        box.Size, box.BackgroundColor3, box.BorderSizePixel = UDim2.new(0, f[2], 1, 0), Theme.Colors.Panel, 0
        box.PlaceholderText, box.PlaceholderColor3, box.Text = f[1], Theme.Colors.TextDim, f[3] or ""
        box.TextColor3, box.Font, box.TextSize, box.ClearTextOnFocus = Theme.Colors.TextPrimary, Theme.Fonts.Body, 13, false
        box.Parent = row
        Theme.AddCorner(box, Theme.Corner.Small)
        table.insert(boxes, box)
    end
    for _, b in ipairs(buttons) do
        local btn = Theme.Button(row, b[1], b[2], Color3.fromRGB(255, 255, 255), "Do")
        btn.Size, btn.TextSize = UDim2.new(0, b[4] or 70, 1, 0), 13
        btn.MouseButton1Click:Connect(function() b[3](boxes) end)
    end
    return boxes
end

local output = Theme.Label(body, "Results show here.", Theme.TextSize.Small, Theme.Colors.TextSecondary, Theme.Fonts.Mono, "Output")
output.Size, output.AutomaticSize, output.LayoutOrder = UDim2.new(1, -8, 0, 20), Enum.AutomaticSize.Y, 1000
output.TextYAlignment = Enum.TextYAlignment.Top

local function Say(text, colour)
    output.Text, output.TextColor3 = text, colour or Theme.Colors.TextSecondary
end

local function Run(action, args, onData)
    local ok, success, result = pcall(function() return RemoteEvents.AdminAction:InvokeServer(action, args) end)
    if not ok then Say("Request failed", Theme.Colors.Danger) return end
    if not success then Say(tostring(result), Theme.Colors.Danger) return end
    if onData then onData(result) else Say(tostring(result), Theme.Colors.Success) end
end

local function Time(t) return os.date("!%Y-%m-%d %H:%M", t or 0) end

local function DescribeItems(list)
    local out = {}
    for _, it in ipairs(list or {}) do
        table.insert(out, (it.qty and it.qty > 1 and (it.qty .. "x ") or "") .. tostring(it.name or it.id))
    end
    return #out == 0 and "nothing" or table.concat(out, ", ")
end

local function ShowLookup(r)
    local lines = { string.format("Player %d (%s)", r.userId, r.online and "in this server" or "not in this server") }
    table.insert(lines, string.format("-- Reports against them: %d", #r.reports))
    for i = #r.reports, math.max(1, #r.reports - 4), -1 do
        local e = r.reports[i]
        table.insert(lines, string.format("  %s  by %s (%d): %s", Time(e.t), tostring(e.reporterName), e.reporter or 0, tostring(e.reason)))
    end
    table.insert(lines, string.format("-- Trade / market log (newest %d)", #r.log))
    for _, e in ipairs(r.log) do
        table.insert(lines, string.format("  %s  %s %s  gave: %s  got: %s%s", Time(e.t), tostring(e.kind), tostring(e.result),
            DescribeItems(e.gave), DescribeItems(e.got), e.partnerId and ("  with " .. e.partnerId) or ""))
    end
    table.insert(lines, "-- Recent admin actions")
    for _, e in ipairs(r.admin) do
        table.insert(lines, string.format("  %s  %s: %s", Time(e.t), tostring(e.adminName), tostring(e.action)))
    end
    Say(table.concat(lines, "\n"))
end

local GREEN, ORANGE, RED, BLUE = Theme.Colors.Success, Theme.Colors.Accent, Theme.Colors.Danger, Theme.Colors.Info

Heading("Gift (player must be in this server)")
Row({ { "Player name or id", 150 }, { "Coins", 80 } }, { { "Give coins", GREEN, function(b)
    Run("grantCoins", { target = tonumber(b[1].Text) or b[1].Text, amount = b[2].Text })
end, 90 } })
Row({ { "Player name or id", 150 }, { "Material id", 100 }, { "Qty", 50 } }, { { "Give", GREEN, function(b)
    Run("grantMaterial", { target = tonumber(b[1].Text) or b[1].Text, id = b[2].Text, qty = b[3].Text })
end, 50 } })

Row({ { "Player name or id", 150 }, { "Egg id (Basic...)", 100 }, { "Qty", 50 } }, { { "Gift eggs", GREEN, function(b)
    Run("grantEgg", { target = tonumber(b[1].Text) or b[1].Text, id = b[2].Text, qty = b[3].Text })
end, 80 } })
Row({ { "Player name or id", 150 }, { "Pet id (Ember...)", 100 }, { "Elite/Supreme", 80 } }, { { "Gift pet", GREEN, function(b)
    local v = ({ elite = "Neon", supreme = "MegaNeon" })[b[3].Text:lower()] or b[3].Text
    Run("grantPet", { target = tonumber(b[1].Text) or b[1].Text, id = b[2].Text, variant = v })
end, 70 } })
Row({ { "Player name or id", 150 }, { "Blueprint (BP_Ember_T1)", 130 }, { "Elite/Supreme", 80 } }, { { "Gift Golem", GREEN, function(b)
    local v = ({ elite = "Neon", supreme = "MegaNeon" })[b[3].Text:lower()] or b[3].Text
    Run("grantGolem", { target = tonumber(b[1].Text) or b[1].Text, id = b[2].Text, variant = v })
end, 80 } })

Heading("Events (all servers within ~5 minutes)")
Row({ { "xp / drops", 80, "xp" }, { "Multiplier", 70, "2" }, { "Hours", 50, "2" } }, {
    { "Start", ORANGE, function(b) Run("event", { kind = b[1].Text, multiplier = b[2].Text, hours = b[3].Text }) end, 50 },
    { "Clear", RED, function() Run("clearEvents", {}) end, 50 },
    { "List", BLUE, function() Run("events", {}) end, 50 } })

Heading("Announce to this server")
Row({ { "Message (140 characters)", 300 } }, { { "Send", ORANGE, function(b) Run("announce", { text = b[1].Text }) end, 70 } })

Heading("Moderation (reason shown to the player; hours 0 = permanent)")
local function modRow(label, colour, action, hasHours)
    local fields = { { "Player name or id", 130 }, { "Reason", 150 } }
    if hasHours then table.insert(fields, { "Hours", 50, "0" }) end
    Row(fields, { { label, colour, function(b)
        Run(action, { target = tonumber(b[1].Text) or b[1].Text, reason = b[2].Text, hours = b[3] and b[3].Text or 0 })
    end, 60 } })
end
modRow("Kick", ORANGE, "kick", false)
modRow("Ban", RED, "ban", true)
modRow("Mute", ORANGE, "mute", true)
Row({ { "Player name or id", 130 } }, {
    { "Unban", GREEN, function(b) Run("unban", { target = tonumber(b[1].Text) or b[1].Text }) end, 60 },
    { "Unmute", GREEN, function(b) Run("unmute", { target = tonumber(b[1].Text) or b[1].Text }) end, 60 } })

Heading("Player lookup: trade log, reports, admin actions")
Row({ { "Player name or id", 220 } }, { { "Look up", BLUE, function(b) Run("lookup", { target = tonumber(b[1].Text) or b[1].Text }, ShowLookup) end, 90 } })

toggle.MouseButton1Click:Connect(function() window.Visible = not window.Visible end)

local function Sync() toggle.Visible = LocalPlayer:GetAttribute("EFAdmin") == true if not toggle.Visible then window.Visible = false end end
LocalPlayer:GetAttributeChangedSignal("EFAdmin"):Connect(Sync)
Sync()
