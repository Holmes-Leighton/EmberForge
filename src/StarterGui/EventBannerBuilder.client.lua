-- Top-centre pill showing the live hourly event and a countdown to the next one. The schedule is pure clock maths
-- (EventScheduleData), so this needs no server messages.
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

local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Size = UDim2.new(0, 340, 0, 44)
pill.Position = UDim2.new(0.5, 0, 0, 6)
pill.BackgroundColor3 = Theme.Colors.Panel
pill.BackgroundTransparency = 0.1
pill.BorderSizePixel = 0
pill.Parent = gui
Theme.AddCorner(pill, UDim.new(0, 22))
Theme.AddStroke(pill, Theme.Colors.Gold, 2, 0.2)
ScaleUI.ApplyHud(pill)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -24, 0, 22)
title.Position = UDim2.new(0, 12, 0, 3)
title.Font = Theme.Fonts.Heading
title.TextScaled = true        -- long names shrink to fit the pill
local cap = Instance.new("UITextSizeConstraint")
cap.MaxTextSize = 17
cap.MinTextSize = 9
cap.Parent = title
title.TextColor3 = Theme.Colors.Gold
title.TextXAlignment = Enum.TextXAlignment.Center
title.Text = ""
title.Parent = pill

local sub = Instance.new("TextLabel")
sub.Name = "Sub"
sub.BackgroundTransparency = 1
sub.Size = UDim2.new(1, -24, 0, 16)
sub.Position = UDim2.new(0, 12, 0, 24)
sub.Font = Theme.Fonts.Body
sub.TextSize = 13
sub.TextColor3 = Theme.Colors.TextSecondary
sub.Text = ""
sub.Parent = pill

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local last = 0
RunService.Heartbeat:Connect(function()
    local now = workspace:GetServerTimeNow()
    if now - last < 0.5 then return end
    last = now
    local cur = Schedule.Current(now)
    local nxt = Schedule.Next(now)
    title.Text = string.format("%s  -  %s", cur.name, cur.blurb)
    sub.Text = string.format("ends in %s  |  next: %s", Clock(cur.endTime - now), nxt.name)
end)
