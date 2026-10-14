-- The card showing what bonus is live. The schedule is pure clock maths (EventScheduleData), so this needs no server messages.
-- Three looks, so a player recognises what they are seeing at a glance: the hourly event (gold), a surge (red-orange, tinted, a little bigger) and a
-- jackpot (bright gold, tinted, biggest, pulsing).
-- Where it sits: on a normal screen it is a card just above the player card on the left, the same width, so the middle of the screen (where you are
-- walking) stays clear. On a phone it is a slim one-line strip in the free middle of the top bar instead.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Theme = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScaleUI = require(game.ReplicatedStorage.Shared.Modules.ScaleUI)
local Schedule = require(game.ReplicatedStorage.Shared.Data.EventScheduleData)
local ScreenMode = require(game.ReplicatedStorage.Shared.Modules.ScreenMode)
local compact = ScreenMode.Compact()

local CARD_W, CARD_H = 196, 108                 -- the same width as the player card (HUDBuilder's CARD_W)

local gui = Instance.new("ScreenGui")
gui.Name = "EventBanner"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local LOOKS = {
    hourly  = { tag = "HOURLY EVENT", colour = Theme.Colors.Gold,              fill = Color3.fromRGB(34, 26, 22),  nameSize = 18, stroke = 2 },
    surge   = { tag = "SURGE",        colour = Color3.fromRGB(255, 120, 90),   fill = Color3.fromRGB(70, 28, 22),  nameSize = 19, stroke = 3 },
    jackpot = { tag = "JACKPOT",      colour = Color3.fromRGB(255, 226, 90),   fill = Color3.fromRGB(78, 58, 10),  nameSize = 20, stroke = 4 },
}

local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.BackgroundColor3 = LOOKS.hourly.fill
pill.BackgroundTransparency = 0.05
pill.BorderSizePixel = 0
pill.Parent = gui
Theme.AddCorner(pill, UDim.new(0, 14))
local stroke = Theme.AddStroke(pill, Theme.Colors.Gold, 2, 0.1)
local pillScale = ScaleUI.ApplyHud(pill, 720, function() return ScreenMode.Compact() and 1 or nil end)   -- the card scales exactly like the player card; the phone strip does not

-- the tag: a small coloured chip that says which kind of event this is
local chip = Instance.new("Frame")
chip.Name = "Tag"
chip.Position = UDim2.new(0, 10, 0, 8)
chip.Size = UDim2.new(0, 108, 0, 18)
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

-- the event's name
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Colors.Gold
title.TextStrokeTransparency = 0.6
title.TextTruncate = Enum.TextTruncate.AtEnd
title.Text = ""
title.Parent = pill

-- what it does, in plain words
local blurb = Instance.new("TextLabel")
blurb.Name = "Blurb"
blurb.BackgroundTransparency = 1
blurb.Font = Theme.Fonts.Body
blurb.TextSize = 13
blurb.TextXAlignment = Enum.TextXAlignment.Left
blurb.TextYAlignment = Enum.TextYAlignment.Top
blurb.TextColor3 = Color3.fromRGB(235, 228, 218)
blurb.TextWrapped = true
blurb.Text = ""
blurb.Parent = pill

-- the countdown
local clock = Instance.new("TextLabel")
clock.Name = "Clock"
clock.BackgroundTransparency = 1
clock.AnchorPoint = Vector2.new(1, 0)
clock.Font = Enum.Font.GothamBlack
clock.TextXAlignment = Enum.TextXAlignment.Right
clock.TextColor3 = Theme.Colors.Gold
clock.Text = ""
clock.Parent = pill

-- what comes next
local sub = Instance.new("TextLabel")
sub.Name = "Sub"
sub.BackgroundTransparency = 1
sub.Font = Theme.Fonts.Body
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = Theme.Colors.TextSecondary
sub.TextTruncate = Enum.TextTruncate.AtEnd
sub.Text = ""
sub.Parent = pill

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds >= 3600 then return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60) end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local current
local look = LOOKS.hourly

local function Apply(kind)
    look = LOOKS[kind]
    pill.BackgroundColor3 = look.fill
    stroke.Color = look.colour
    chip.BackgroundColor3 = look.colour
    chipText.Text = look.tag
    title.TextColor3 = look.colour
    clock.TextColor3 = look.colour
    if not compact then
        stroke.Thickness = look.stroke
        title.TextSize = look.nameSize
    end
end

-- The card sits just above the player card (same left edge, same width, same scale). The player card is centred vertically, so its top edge is
-- half the screen minus half its height (scaled).
local function PlaceCard()
    local hud = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    local card = hud and hud:FindFirstChild("MainFrame")
    local cardHeight = card and card.Size.Y.Offset or 352
    pill.AnchorPoint = Vector2.new(0, 1)
    pill.Position = UDim2.new(0, 8, 0.5, -(cardHeight / 2) * pillScale.Scale - 6)
end

local function Layout(isCompact)
    compact = isCompact
    gui.IgnoreGuiInset = compact
    if compact then
        -- a phone: one slim line (name and countdown) in the top bar's free middle
        local cam = workspace.CurrentCamera
        local vx = cam and cam.ViewportSize.X or 640
        chip.Visible, blurb.Visible, sub.Visible = false, false, false
        pill.AnchorPoint = Vector2.new(0.5, 0)
        pill.Position = UDim2.new(0.5, 0, 0, 4)
        pill.Size = UDim2.new(0, math.clamp(vx - 240, 200, 340), 0, 28)
        stroke.Thickness = 2
        title.Position, title.Size, title.TextSize = UDim2.new(0, 10, 0, 2), UDim2.new(1, -86, 0, 24), 13
        clock.Position, clock.Size, clock.TextSize = UDim2.new(1, -8, 0, 2), UDim2.new(0, 70, 0, 24), 15
    else
        chip.Visible, blurb.Visible, sub.Visible = true, true, true
        pill.Size = UDim2.new(0, CARD_W, 0, CARD_H)
        title.Position, title.Size = UDim2.new(0, 10, 0, 30), UDim2.new(1, -20, 0, 24)
        blurb.Position, blurb.Size = UDim2.new(0, 10, 0, 56), UDim2.new(1, -20, 0, 32)
        clock.Position, clock.Size, clock.TextSize = UDim2.new(1, -10, 0, 3), UDim2.new(0, 76, 0, 24), 20
        sub.Position, sub.Size = UDim2.new(0, 10, 0, 90), UDim2.new(1, -20, 0, 14)
        PlaceCard()
    end
    Apply(current or "hourly")
end

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

ScreenMode.Watch(Layout)
pillScale:GetPropertyChangedSignal("Scale"):Connect(function() if not compact then PlaceCard() end end)
task.defer(function() if not compact then PlaceCard() end end)           -- once the HUD has been built, line up with its real card

-- The hourly event bonus does nothing in the Sky Tower, so the card is hidden while climbing
-- (the server sets the TowerLevel attribute for the length of a climb)
local function SyncTower() gui.Enabled = LocalPlayer:GetAttribute("TowerLevel") == nil end
LocalPlayer:GetAttributeChangedSignal("TowerLevel"):Connect(SyncTower)
SyncTower()
