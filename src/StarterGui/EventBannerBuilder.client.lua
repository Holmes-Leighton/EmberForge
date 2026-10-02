-- Top-centre card showing what bonus is live. The schedule is pure clock maths (EventScheduleData), so this needs no server messages.
-- Three looks, so a player recognises what they are seeing at a glance: the hourly event (gold), a surge (red-orange, tinted, a little bigger) and a
-- jackpot (bright gold, tinted, biggest, pulsing). The tag, the name, the countdown and the one-line description each have their own place and size.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local Schedule = require(game.ReplicatedStorage.Shared.Data.EventScheduleData)

local gui = Instance.new("ScreenGui")
gui.Name = "EventBanner"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local LOOKS = {
    hourly  = { tag = "HOURLY EVENT", colour = Theme.Colors.Gold,              fill = Color3.fromRGB(34, 26, 22),  height = 68, nameSize = 20, stroke = 2, countdown = "ends in" },
    surge   = { tag = "SURGE",        colour = Color3.fromRGB(255, 120, 90),   fill = Color3.fromRGB(70, 28, 22),  height = 74, nameSize = 22, stroke = 3, countdown = "ends in" },
    jackpot = { tag = "JACKPOT",      colour = Color3.fromRGB(255, 226, 90),   fill = Color3.fromRGB(78, 58, 10),  height = 80, nameSize = 24, stroke = 4, countdown = "ends in" },
}

local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Size = UDim2.new(0, 500, 0, LOOKS.hourly.height)
pill.Position = UDim2.new(0.5, 0, 0, 6)
pill.BackgroundColor3 = LOOKS.hourly.fill
pill.BackgroundTransparency = 0.05
pill.BorderSizePixel = 0
pill.Parent = gui
Theme.AddCorner(pill, UDim.new(0, 16))
local stroke = Theme.AddStroke(pill, Theme.Colors.Gold, 2, 0.1)
ScaleUI.ApplyHud(pill)

-- the tag: a small coloured chip that says which kind of event this is
local chip = Instance.new("Frame")
chip.Name = "Tag"
chip.Position = UDim2.new(0, 14, 0, 8)
chip.Size = UDim2.new(0, 112, 0, 18)
chip.BackgroundColor3 = Theme.Colors.Gold
chip.BorderSizePixel = 0
chip.Parent = pill
Theme.AddCorner(chip, UDim.new(0, 9))
local chipText = Instance.new("TextLabel")
chipText.BackgroundTransparency = 1
chipText.Size = UDim2.new(1, 0, 1, 0)
chipText.Font = Enum.Font.GothamBlack
chipText.TextSize = 12
chipText.TextColor3 = Color3.fromRGB(30, 22, 16)
chipText.Text = ""
chipText.Parent = chip

-- the event's name, large
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 14, 0, 28)
title.Size = UDim2.new(1, -170, 0, 26)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Colors.Gold
title.TextStrokeTransparency = 0.6
title.Text = ""
title.Parent = pill

-- what it does, in plain words
local blurb = Instance.new("TextLabel")
blurb.Name = "Blurb"
blurb.BackgroundTransparency = 1
blurb.Position = UDim2.new(0, 14, 0, 0)       -- (y is set per look, under the name)
blurb.Size = UDim2.new(1, -170, 0, 18)
blurb.Font = Theme.Fonts.Body
blurb.TextSize = 15
blurb.TextXAlignment = Enum.TextXAlignment.Left
blurb.TextColor3 = Color3.fromRGB(235, 228, 218)
blurb.TextTruncate = Enum.TextTruncate.AtEnd
blurb.Text = ""
blurb.Parent = pill

-- the countdown, big, on the right, with what comes next under it
local clock = Instance.new("TextLabel")
clock.Name = "Clock"
clock.BackgroundTransparency = 1
clock.AnchorPoint = Vector2.new(1, 0)
clock.Position = UDim2.new(1, -14, 0, 8)
clock.Size = UDim2.new(0, 140, 0, 32)
clock.Font = Enum.Font.GothamBlack
clock.TextSize = 28
clock.TextXAlignment = Enum.TextXAlignment.Right
clock.TextColor3 = Theme.Colors.Gold
clock.Text = ""
clock.Parent = pill

local sub = Instance.new("TextLabel")
sub.Name = "Sub"
sub.BackgroundTransparency = 1
sub.AnchorPoint = Vector2.new(1, 0)
sub.Position = UDim2.new(1, -14, 0, 42)
sub.Size = UDim2.new(0, 150, 0, 16)
sub.Font = Theme.Fonts.Body
sub.TextSize = 13
sub.TextXAlignment = Enum.TextXAlignment.Right
sub.TextColor3 = Theme.Colors.TextSecondary
sub.TextTruncate = Enum.TextTruncate.AtEnd
sub.Text = ""
sub.Parent = pill

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds >= 3600 then return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60) end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local look = LOOKS.hourly
local function Apply(kind)
    look = LOOKS[kind]
    pill.Size = UDim2.new(0, 500, 0, look.height)
    pill.BackgroundColor3 = look.fill
    stroke.Color = look.colour
    stroke.Thickness = look.stroke
    chip.BackgroundColor3 = look.colour
    chipText.Text = look.tag
    title.TextColor3 = look.colour
    title.TextSize = look.nameSize
    title.Size = UDim2.new(1, -170, 0, look.nameSize + 6)
    blurb.Position = UDim2.new(0, 14, 0, 28 + look.nameSize + 6)
    clock.TextColor3 = look.colour
end

local current
local last = 0
RunService.Heartbeat:Connect(function()
    local now = workspace:GetServerTimeNow()
    if look == LOOKS.jackpot then                       -- the jackpot pulses so it cannot be missed
        stroke.Transparency = 0.05 + 0.4 * (math.sin(os.clock() * 5) * 0.5 + 0.5)
    else
        stroke.Transparency = 0.1
    end
    if now - last < 0.5 then return end
    last = now
    local cur = Schedule.Current(now)
    local nxt = Schedule.Next(now)
    local jackpot = Schedule.Jackpot(now)
    local surge = (not jackpot) and Schedule.Surge(now) or nil
    local event, kind = cur, "hourly"
    if jackpot then event, kind = jackpot, "jackpot" elseif surge then event, kind = surge, "surge" end
    if current ~= kind then current = kind Apply(kind) end
    title.Text = event.name
    blurb.Text = event.blurb
    clock.Text = Clock(event.endTime - now)
    if kind == "hourly" then
        sub.Text = "next: " .. nxt.name
    else
        sub.Text = "hourly: " .. cur.name
    end
end)
