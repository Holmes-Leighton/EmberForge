-- The Hollow Maze on the client: the section / clock panel, the live "furthest" list, banners and flashes, the danger glow when the Zombie Golem is close, and the Zombie
-- Golem itself. The server decides everything that matters (position of the Zombie, catches, rewards, who escaped); the Zombie is only an anchored model there with its
-- position published as attributes, so this moves and animates it (the same walk for everyone, drawn on each screen).
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")

local MazeData     = require(game.ReplicatedStorage.Shared.Data.MazeData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local MaterialIcon = require(game.ReplicatedStorage.Shared.Modules.MaterialIcon)
local ScreenMode   = require(game.ReplicatedStorage.Shared.Modules.ScreenMode)

local LocalPlayer = Players.LocalPlayer

local MazeController = {}

local SECTION_COLORS = {
    Stone = Color3.fromRGB(190, 180, 160), Ember = Color3.fromRGB(255, 130, 60), Frost = Color3.fromRGB(150, 220, 255),
    Storm = Color3.fromRGB(255, 232, 110), Void = Color3.fromRGB(190, 120, 255),
}

local CARD_W, CARD_GAP = 270, 8       -- the reward cards (see below)
local cardHolder
local hud, sectionLbl, clockLbl, infoLbl, standingsFrame, standingsLbl, flash, banner, danger, panel
local dailyTarget, dailyDone = nil, false
local best = 0
local panelCompact = nil

local function ServerNow() return workspace:GetServerTimeNow() end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ── HUD ───────────────────────────────────────────────────────────────────────
local function BuildHud()
    hud = Instance.new("ScreenGui")
    hud.Name, hud.ResetOnSpawn, hud.IgnoreGuiInset, hud.DisplayOrder, hud.Enabled = "MazeHUD", false, true, 8, false
    hud.Parent = LocalPlayer:WaitForChild("PlayerGui")

    danger = Instance.new("Frame")                                 -- a red glow round the screen edge that grows as the Zombie closes in
    danger.Size, danger.BackgroundColor3, danger.BackgroundTransparency, danger.BorderSizePixel, danger.ZIndex = UDim2.new(1, 0, 1, 0), Color3.fromRGB(190, 20, 20), 1, 0, 5
    danger.Parent = hud
    local grad = Instance.new("UIGradient")
    grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 0) })
    grad.Rotation = 90
    grad.Parent = danger

    panel = Instance.new("Frame")
    panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0, 0), UDim2.new(0, 14, 0, 96), UDim2.new(0, 300, 0, 84)
    panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Color3.fromRGB(18, 22, 20), 0.15, 0
    panel.Parent = hud
    Theme.AddCorner(panel, Theme.Corner.Medium)
    Theme.AddStroke(panel, Color3.fromRGB(110, 190, 120), 2)
    sectionLbl = Theme.Label(panel, "THE HOLLOW MAZE", 24, Color3.fromRGB(255, 255, 255), Theme.Fonts.Title)
    sectionLbl.Position, sectionLbl.Size, sectionLbl.TextXAlignment = UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 30), Enum.TextXAlignment.Center
    clockLbl = Theme.Label(panel, "", 20, Color3.fromRGB(255, 232, 170), Theme.Fonts.Heading)
    clockLbl.Position, clockLbl.Size, clockLbl.TextXAlignment = UDim2.new(0, 10, 0, 36), UDim2.new(1, -20, 0, 24), Enum.TextXAlignment.Center
    infoLbl = Theme.Label(panel, "", Theme.TextSize.Small, Color3.fromRGB(230, 220, 200), Theme.Fonts.Body)
    infoLbl.Position, infoLbl.Size, infoLbl.TextXAlignment = UDim2.new(0, 10, 0, 62), UDim2.new(1, -20, 0, 16), Enum.TextXAlignment.Center

    standingsFrame = Instance.new("Frame")
    standingsFrame.AnchorPoint, standingsFrame.Position, standingsFrame.Size = Vector2.new(1, 0), UDim2.new(1, -90, 0, 200), UDim2.new(0, 200, 0, 130)
    standingsFrame.BackgroundColor3, standingsFrame.BackgroundTransparency, standingsFrame.BorderSizePixel = Color3.fromRGB(18, 22, 20), 0.25, 0
    standingsFrame.Parent = hud
    Theme.AddCorner(standingsFrame, Theme.Corner.Small)
    standingsLbl = Theme.Label(standingsFrame, "", Theme.TextSize.Small, Color3.fromRGB(235, 240, 230), Theme.Fonts.Body)
    standingsLbl.Position, standingsLbl.Size, standingsLbl.TextYAlignment = UDim2.new(0, 8, 0, 6), UDim2.new(1, -16, 1, -12), Enum.TextYAlignment.Top

    cardHolder = Instance.new("Frame")                                 -- the reward cards stack down the left, where the event cards sit when you are not in the maze
    cardHolder.BackgroundTransparency, cardHolder.Position, cardHolder.Size = 1, UDim2.new(0, 14, 0, 192), UDim2.new(0, CARD_W, 0, 400)
    cardHolder.Parent = hud
    flash = Instance.new("Frame")
    flash.Size, flash.BackgroundTransparency, flash.BorderSizePixel, flash.Visible, flash.ZIndex = UDim2.new(1, 0, 1, 0), 1, 0, false, 20
    flash.Parent = hud
    banner = Theme.Label(hud, "", 36, Color3.fromRGB(255, 255, 255), Theme.Fonts.Title)
    banner.AnchorPoint, banner.Position, banner.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.32, 0), UDim2.new(0.8, 0, 0, 64)
    banner.TextXAlignment, banner.TextTransparency, banner.TextStrokeTransparency, banner.TextStrokeColor3, banner.ZIndex = Enum.TextXAlignment.Center, 1, 1, Color3.fromRGB(10, 14, 12), 21
end

-- On a phone the panel moves to the left column above the player card, like the Sky Tower's badge
local function PlacePanel()
    if not panel then return end
    local compact = ScreenMode.Compact()
    local card = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("MainFrame")
    if compact and card then
        local inset = (LocalPlayer.PlayerGui.HUD.IgnoreGuiInset and 0 or game:GetService("GuiService"):GetGuiInset().Y)
        panel.AnchorPoint = Vector2.new(0, 1)
        panel.Position = UDim2.fromOffset(card.AbsolutePosition.X, card.AbsolutePosition.Y + inset - 6)
        panel.Size = UDim2.fromOffset(math.max(card.AbsoluteSize.X, 140), 62)
        if panelCompact ~= true then
            panelCompact = true
            sectionLbl.Position, sectionLbl.Size, sectionLbl.TextSize = UDim2.new(0, 4, 0, 2), UDim2.new(1, -8, 0, 20), 15
            clockLbl.Position, clockLbl.Size, clockLbl.TextSize = UDim2.new(0, 4, 0, 22), UDim2.new(1, -8, 0, 16), 14
            infoLbl.Position, infoLbl.Size, infoLbl.TextSize = UDim2.new(0, 4, 0, 40), UDim2.new(1, -8, 0, 12), 10
        end
    elseif panelCompact ~= false then
        panelCompact = false
        panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0, 0), UDim2.new(0, 14, 0, 96), UDim2.new(0, 300, 0, 84)
        sectionLbl.Position, sectionLbl.Size, sectionLbl.TextSize = UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 30), 24
        clockLbl.Position, clockLbl.Size, clockLbl.TextSize = UDim2.new(0, 10, 0, 36), UDim2.new(1, -20, 0, 24), 20
        infoLbl.Position, infoLbl.Size, infoLbl.TextSize = UDim2.new(0, 10, 0, 62), UDim2.new(1, -20, 0, 16), Theme.TextSize.Small
    end
end

local function Flash(color, strength)
    if not flash then return end
    flash.BackgroundColor3, flash.BackgroundTransparency, flash.Visible = color, 1 - (strength or 0.5), true
    TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
    task.delay(0.65, function() if flash then flash.Visible = false end end)
end

local function Banner(text, color)
    if not banner then return end
    banner.Text, banner.TextColor3 = text, color or Color3.fromRGB(255, 255, 255)
    banner.TextTransparency, banner.TextStrokeTransparency = 0, 0.2
    banner.Position = UDim2.new(0.5, 0, 0.34, 0)
    TweenService:Create(banner, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1, Position = UDim2.new(0.5, 0, 0.26, 0) }):Play()
end

local function Sparks(color, count)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local e = Instance.new("ParticleEmitter")
    e.Color, e.Size, e.Lifetime, e.Speed = ColorSequence.new(color or Color3.fromRGB(255, 220, 120)), NumberSequence.new(0.9, 0), NumberRange.new(0.6, 1.2), NumberRange.new(14, 26)
    e.SpreadAngle, e.LightEmission, e.Rate, e.Acceleration = Vector2.new(180, 180), 1, 0, Vector3.new(0, -25, 0)
    e.Parent = root
    e:Emit(count or 30)
    Debris:AddItem(e, 2)
end

-- ── Reward cards ──────────────────────────────────────────────────────────────
-- The moments you want to read (a section cleared and what it paid, a Maze Golem piece, the daily bonus) are cards stacked down the left of the screen, like the event cards,
-- instead of big centre text (that stays for the urgent moments: the gate, the wake-up, caught, escaped). They wait while the Zombie Golem is close, so nothing covers the
-- corridor at the wrong moment (a piece find waits at most PIECE_WAIT seconds), and they stack so two finds in a row are both seen.
local CARD_NEAR = 40                  -- studs: the Zombie is "close" inside this
local PIECE_WAIT = 10                 -- seconds a piece card will wait for the Zombie to back off
local cardQueue = {}                  -- { build = fn(parent) -> frame, height, stay, special, queuedAt }
local liveCards = {}                  -- { frame, height, dieAt }
local zombieNear = false

local function LayoutCards()
    local y = 0
    for _, c in ipairs(liveCards) do
        TweenService:Create(c.frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = UDim2.new(0, 0, 0, y) }):Play()
        y += c.height + CARD_GAP
    end
end

local function NewCard(height, accent, special)
    local f = Instance.new("Frame")
    f.Size, f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = UDim2.new(0, CARD_W, 0, height), Color3.fromRGB(18, 22, 20), 0.1, 0
    Theme.AddCorner(f, Theme.Corner.Medium)
    Theme.AddStroke(f, accent, special and 3 or 2)
    return f
end

local function PushCard(spec)
    spec.queuedAt = os.clock()
    table.insert(cardQueue, spec)
end

local function PumpCards()
    if not cardHolder then return end
    for i = #liveCards, 1, -1 do                                   -- retire the ones whose time is up
        local c = liveCards[i]
        if os.clock() >= c.dieAt then
            table.remove(liveCards, i)
            TweenService:Create(c.frame, TweenInfo.new(0.3), { Position = c.frame.Position - UDim2.new(0, CARD_W + 20, 0, 0) }):Play()
            Debris:AddItem(c.frame, 0.35)
            LayoutCards()
        end
    end
    local i = 1
    while i <= #cardQueue do
        local spec = cardQueue[i]
        local waited = os.clock() - spec.queuedAt
        if (not zombieNear) or (spec.special and waited > PIECE_WAIT) or waited > 25 then
            if #liveCards >= 4 then break end                    -- (four cards at a time at most)
            table.remove(cardQueue, i)
            local frame = spec.build(cardHolder)
            local y = 0
            for _, c in ipairs(liveCards) do y += c.height + CARD_GAP end
            frame.Position = UDim2.new(0, -CARD_W - 20, 0, y)
            table.insert(liveCards, { frame = frame, height = spec.height, dieAt = os.clock() + spec.stay })
            TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0, 0, 0, y) }):Play()
        else
            i += 1
        end
    end
end

local function ClearCards()
    cardQueue = {}
    for _, c in ipairs(liveCards) do c.frame:Destroy() end
    liveCards = {}
end

local function CardText(f, text, size, color, font, y, h, x)
    local l = Theme.Label(f, text, size, color, font)
    l.Position, l.Size, l.TextXAlignment = UDim2.new(0, x or 12, 0, y), UDim2.new(1, -((x or 12) + 12), 0, h), Enum.TextXAlignment.Left
    return l
end

-- A section-cleared card: the section's colour, what it paid
local function SectionCard(p)
    local col = SECTION_COLORS[p.name] or Color3.fromRGB(255, 255, 255)
    PushCard({ height = 64, stay = 4.5, build = function(parent)
        local f = NewCard(64, col, false)
        f.Parent = parent
        CardText(f, string.upper(p.name or "") .. " CLEARED", 17, col, Theme.Fonts.Heading, 6, 24)
        local bits = { string.format("+%d coins", p.coins or 0), string.format("+%d XP", p.xp or 0) }
        if p.rare then table.insert(bits, "RARE!") end
        if p.playerLevelUp then table.insert(bits, string.format("Level %d!", p.playerLevelUp)) end
        CardText(f, table.concat(bits, "   "), Theme.TextSize.Small, Color3.fromRGB(235, 235, 220), Theme.Fonts.Body, 32, 22)
        return f
    end })
end

-- A Maze Golem piece card: gold border, the piece's own mesh, and a bar towards the full set
local function PieceCard(piece)
    PushCard({ height = 88, stay = 6.5, special = true, build = function(parent)
        local gold = Color3.fromRGB(255, 215, 90)
        local f = NewCard(88, gold, true)
        f.Parent = parent
        local icon = MaterialIcon.Make(f, piece.id, 64)
        if icon then icon.Position = UDim2.new(0, 10, 0, 12) end
        CardText(f, string.upper(piece.name) .. " FOUND!", 15, gold, Theme.Fonts.Heading, 8, 22, 82)
        CardText(f, string.format("%d / %d for the Maze Golem", piece.have, piece.need), Theme.TextSize.Small, Color3.fromRGB(235, 235, 220), Theme.Fonts.Body, 32, 20, 82)
        local track = Instance.new("Frame")
        track.Position, track.Size, track.BackgroundColor3, track.BorderSizePixel = UDim2.new(0, 82, 0, 60), UDim2.new(1, -96, 0, 10), Color3.fromRGB(40, 36, 30), 0
        track.Parent = f
        Theme.AddCorner(track, UDim.new(0, 5))
        local fill = Instance.new("Frame")
        fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = UDim2.new(0, 0, 1, 0), gold, 0
        fill.Parent = track
        Theme.AddCorner(fill, UDim.new(0, 5))
        TweenService:Create(fill, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = UDim2.new(math.clamp(piece.have / piece.need, 0, 1), 0, 1, 0) }):Play()
        Flash(gold, 0.3)
        Sparks(gold, 60)
        return f
    end })
end

local function TextCard(title, text, accent)
    PushCard({ height = 64, stay = 5, build = function(parent)
        local f = NewCard(64, accent, false)
        f.Parent = parent
        CardText(f, title, 17, accent, Theme.Fonts.Heading, 6, 24)
        CardText(f, text, Theme.TextSize.Small, Color3.fromRGB(235, 235, 220), Theme.Fonts.Body, 32, 22)
        return f
    end })
end

-- ── The Zombie Golem ──────────────────────────────────────────────────────────
-- Poses the model from the attributes the server publishes (position, heading, speed, state) and swings its arms and legs about the shoulder / hip. Each part is kept at
-- its offset from the model's pivot so the walk is a pure function of time: nothing drifts, and a model that streams in late still lines up.
local zombie, rig = nil, nil
local zombieSearchAt = 0
local walkPhase = 0
local smoothX, smoothZ, smoothYaw

-- With streaming a model can arrive part by part, so the rig is topped up as parts show up. A part that has just arrived is still where the server put it (the Zombie's home
-- pose, which is also where the pivot was taken), so its offset from the pivot is read once, when it is first seen.
local function AddParts(r)
    for _, p in ipairs(r.model:GetDescendants()) do
        if p:IsA("BasePart") and not r.seen[p] then
            r.seen[p] = true
            local n = p.Name
            local kind = (n == "ArmL" and "armL") or (n == "ArmR" and "armR") or (n == "Leg" and "leg") or (n == "Head" and "head") or (n == "Torso" and "torso") or "body"
            local rel = r.pivot:ToObjectSpace(p.CFrame)
            local side = 0
            if kind == "leg" then side = (rel.X < 0) and 1 or -1 end        -- (the two legs swing opposite ways)
            table.insert(r.parts, { part = p, rel = rel, kind = kind, side = side, hang = Vector3.new(0, p.Size.Y / 2 - 0.2, 0) })
        end
    end
end

local function BuildRig(model)
    local r = { model = model, pivot = model:GetAttribute("PivotCF"), home = model:GetAttribute("Home"), parts = {}, seen = {}, checkedAt = 0 }
    if not (r.pivot and r.home) then return r end
    AddParts(r)
    return r
end

local function FindZombie(now)
    if zombie and zombie.Parent then return end
    zombie, rig = nil, nil
    if now - zombieSearchAt < 1 then return end
    zombieSearchAt = now
    local m = workspace:FindFirstChild("MazeZombie", true)
    if m and m:IsA("Model") and m:GetAttribute("Home") then
        local built = BuildRig(m)
        if #built.parts == 0 then return end                         -- (the model can arrive before its pivot or parts: look again next second)
        zombie, rig = m, built
        smoothX, smoothZ, smoothYaw = nil, nil, nil
    end
end

local function StepZombie(dt, now)
    FindZombie(now)
    if not (zombie and rig) then return nil end
    local zx, zz, yaw = zombie:GetAttribute("ZX"), zombie:GetAttribute("ZZ"), zombie:GetAttribute("ZYaw")
    if not (zx and zz and yaw) then return nil end
    local speed, state = zombie:GetAttribute("ZSpeed") or 0, zombie:GetAttribute("ZState") or "asleep"
    local a = math.min(1, dt * 12)                                  -- (the server publishes at 20Hz: smooth between updates)
    if not smoothX then smoothX, smoothZ, smoothYaw = zx, zz, yaw end
    smoothX, smoothZ = smoothX + (zx - smoothX) * a, smoothZ + (zz - smoothZ) * a
    local dy = (yaw - smoothYaw + math.pi) % (2 * math.pi) - math.pi
    smoothYaw += dy * math.min(1, dt * 8)

    local walking = state ~= "asleep" and speed > 0.5
    walkPhase += dt * (walking and math.clamp(speed * 0.55, 3, 11) or 1.2)
    local swing = walking and 0.7 or 0.04
    local bob = walking and (math.abs(math.sin(walkPhase)) * 0.35) or (math.sin(walkPhase) * 0.05)
    local lean = walking and -0.12 or 0.18                          -- asleep: slumped forward

    local home, base = rig.home, rig.pivot
    if now - rig.checkedAt > 0.5 then
        rig.checkedAt = now
        AddParts(rig)
        for i = #rig.parts, 1, -1 do if not rig.parts[i].part.Parent then table.remove(rig.parts, i) end end
    end
    -- (the model is built facing -Z, which is heading 0; ZYaw -pi/2 turns it to face east, into the maze)
    local pose = CFrame.new(smoothX, base.Y + bob, smoothZ) * CFrame.Angles(0, smoothYaw, 0)
        * CFrame.new(base.X - home.X, 0, base.Z - home.Z) * base.Rotation * CFrame.Angles(lean, 0, 0)
    for _, e in ipairs(rig.parts) do
        local cf = pose * e.rel
        if e.kind == "armL" or e.kind == "armR" then
            local s = math.sin(walkPhase + (e.kind == "armL" and 0 or math.pi)) * swing + (walking and 0 or -0.25)
            local pivotPt = CFrame.new(e.hang)
            cf = cf * pivotPt * CFrame.Angles(s, 0, 0) * pivotPt:Inverse()
        elseif e.kind == "leg" then
            local s = math.sin(walkPhase + (e.side > 0 and 0 or math.pi)) * swing * 1.1
            local pivotPt = CFrame.new(e.hang)
            cf = cf * pivotPt * CFrame.Angles(s, 0, 0) * pivotPt:Inverse()
        elseif e.kind == "head" and walking then
            cf = cf * CFrame.Angles(math.sin(walkPhase * 2) * 0.05, math.sin(walkPhase) * 0.1, 0)
        end
        e.part.CFrame = cf
    end
    return smoothX, smoothZ, state
end

-- ── Per-frame HUD ─────────────────────────────────────────────────────────────
local noRunSince
local function Update(dt, now)
    local zx, zz, zstate = StepZombie(dt, now)
    if not (hud and hud.Enabled) then return end
    local section = LocalPlayer:GetAttribute("MazeSection")
    if section == nil then                                          -- safety net: no run on the server for a few seconds means no HUD
        noRunSince = noRunSince or now
        if now - noRunSince > 3 then hud.Enabled = false noRunSince = nil return end
    else
        noRunSince = nil
    end
    section = section or 0
    local total = LocalPlayer:GetAttribute("MazeTotal") or #MazeData.SECTIONS
    local name = MazeData.SECTIONS[math.max(1, section)] or "Stone"
    local caught = LocalPlayer:GetAttribute("MazeCaught") == true
    best = math.max(best, section)
    sectionLbl.Text = section <= 0 and "THE HOLLOW MAZE" or string.format("%s  %d / %d", string.upper(name), section, total)
    sectionLbl.TextColor3 = section <= 0 and Color3.fromRGB(255, 255, 255) or (SECTION_COLORS[name] or Color3.fromRGB(255, 255, 255))

    local wakes, ends, opens = workspace:GetAttribute("MazeWakesAt"), workspace:GetAttribute("MazeEndsAt"), workspace:GetAttribute("MazeOpensAt")
    if caught then
        clockLbl.Text, clockLbl.TextColor3 = "Caught!", Color3.fromRGB(255, 110, 90)
    elseif wakes and now < wakes then
        clockLbl.Text, clockLbl.TextColor3 = string.format("Head start  %s", Clock(wakes - now)), Color3.fromRGB(150, 255, 170)
    elseif ends then
        local left = ends - now
        clockLbl.Text = "HUNTED  " .. Clock(left)
        clockLbl.TextColor3 = left < 60 and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(255, 200, 150)
    end
    infoLbl.Text = caught and "" or (best > 0 and string.format("Furthest this run: %d / %d", best, total) or "Find the way out. Go go go!")

    -- the red edge glow: nothing past WARN_RADIUS, solid at the catch radius
    local glow = 1
    zombieNear = false
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and zx and zstate ~= "asleep" and not caught then
        local d = math.sqrt((root.Position.X - zx) ^ 2 + (root.Position.Z - zz) ^ 2)
        local t = 1 - math.clamp((d - MazeData.CATCH_RADIUS) / (MazeData.WARN_RADIUS - MazeData.CATCH_RADIUS), 0, 1)
        glow = 1 - t * 0.7 * (0.75 + 0.25 * math.sin(now * (4 + 8 * t)))
        zombieNear = d < CARD_NEAR
    end
    danger.BackgroundTransparency = glow
    PumpCards()
end

-- ── The end-of-run card ───────────────────────────────────────────────────────
local MATERIAL_NAMES = {}
local function MatName(id)
    if MATERIAL_NAMES[id] then return MATERIAL_NAMES[id] end
    local ok, MaterialData = pcall(function() return require(game.ReplicatedStorage.Shared.Data.MaterialData) end)
    local def = ok and MaterialData.Get(id)
    MATERIAL_NAMES[id] = def and def.displayName or id
    return MATERIAL_NAMES[id]
end

local function ShowSummary(s)
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "MazeSummary", false, true, 40
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local scrim = Instance.new("Frame")
    scrim.Size, scrim.BackgroundColor3, scrim.BackgroundTransparency, scrim.BorderSizePixel = UDim2.new(1, 0, 1, 0), Color3.fromRGB(0, 0, 0), 0.5, 0
    scrim.Parent = gui
    local W, H = 420, 360
    local card = Instance.new("Frame")
    card.AnchorPoint, card.Position, card.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, W, 0, H)
    card.BackgroundColor3, card.BorderSizePixel = Color3.fromRGB(20, 26, 22), 0
    card.Parent = gui
    Theme.AddCorner(card, Theme.Corner.Large)
    local esc = s.escaped
    local color = esc and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(190, 70, 70)
    Theme.AddStroke(card, color, 3)
    local y = 14
    local function line(text, size, col, font, height)
        local l = Theme.Label(card, text, size, col, font or Theme.Fonts.Body)
        l.Position, l.Size, l.TextXAlignment = UDim2.new(0, 20, 0, y), UDim2.new(1, -40, 0, height or size + 6), Enum.TextXAlignment.Center
        y += (height or size + 6) + 2
        return l
    end
    line(esc and "ESCAPED!" or (s.caught and "CAUGHT!" or "RUN OVER"), 32, color, Theme.Fonts.Title, 42)
    line(string.format("You cleared %d of %d sections", s.best or 0, s.total or #MazeData.SECTIONS), 20, Color3.fromRGB(255, 255, 255), Theme.Fonts.Heading, 28)
    if esc then
        line(string.format("%s%s", esc.medal and (esc.medal .. " time  ") or "", string.format("%d:%04.1f", math.floor(esc.seconds / 60), esc.seconds % 60)), 22, Color3.fromRGB(255, 232, 140), Theme.Fonts.Heading)
        if esc.personalBest then line("NEW PERSONAL BEST!", 16, Color3.fromRGB(120, 255, 150), Theme.Fonts.Heading) end
    end
    local reason = ({ timeup = "Time's up! A new maze is being built.", newround = "A new maze is being built.", left = "You left the maze.", home = "You went home.", speed = "That run was stopped.", died = "You were knocked out." })[s.reason]
    if reason then line(reason, 14, Color3.fromRGB(200, 190, 170)) end
    y += 6
    line(string.format("+%d coins", s.coins or 0), 26, Color3.fromRGB(255, 215, 90), Theme.Fonts.Heading, 34)
    line(string.format("+%d XP", s.xp or 0), 16, Color3.fromRGB(150, 220, 255), Theme.Fonts.Heading)
    local items = {}
    for id, qty in pairs(s.materials or {}) do table.insert(items, string.format("%s x%d", MatName(id), qty)) end
    table.sort(items)
    if #items > 0 then line(table.concat(items, "    "), 14, Color3.fromRGB(235, 225, 205), nil, 40) end
    H = y + 62
    card.Size = UDim2.new(0, W, 0, H)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.6
    scale.Parent = card
    TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = math.min(1, (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700) / (H + 60)) }):Play()
    local ok = Theme.Button(card, "Nice!", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255))
    ok.AnchorPoint, ok.Position, ok.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), UDim2.new(0, 160, 0, 40)
    ok.MouseButton1Click:Connect(function() gui:Destroy() end)
    Flash(color, 0.3)
    Sparks(color, 50)
    task.delay(25, function() if gui.Parent then gui:Destroy() end end)
end

-- ── Events from the server ────────────────────────────────────────────────────
local function OnEvent(kind, p)
    p = p or {}
    if kind == "start" then
        best = 0
        ClearCards()
        dailyTarget, dailyDone = p.dailyTarget, p.dailyDone
        hud.Enabled = true
        Banner("GET READY...", Color3.fromRGB(150, 255, 170))
    elseif kind == "gateopen" then
        Banner("THE GATE IS OPEN! RUN!", Color3.fromRGB(255, 232, 120))
        Flash(Color3.fromRGB(255, 232, 120), 0.2)
    elseif kind == "wake" then
        Banner("THE ZOMBIE GOLEM WAKES", Color3.fromRGB(255, 80, 70))
        Flash(Color3.fromRGB(190, 20, 20), 0.35)
    elseif kind == "section" then
        local col = SECTION_COLORS[p.name] or Color3.fromRGB(255, 255, 255)
        Sparks(col, 40)
        Flash(col, 0.15)
        SectionCard(p)                                               -- what it paid goes on a card down the left
        if p.daily then
            dailyDone = true
            TextCard("DAILY CHALLENGE!", string.format("+%d coins", p.daily.coins), Color3.fromRGB(255, 232, 120))
        end
        if p.piece then
            PieceCard(p.piece)
        elseif p.pieceCapped then
            TextCard("MAZE PIECES", "You have found all you can today", Color3.fromRGB(190, 160, 255))
        end
    elseif kind == "caught" then
        Banner("CAUGHT!", Color3.fromRGB(255, 70, 60))
        Flash(Color3.fromRGB(200, 20, 20), 0.6)
    elseif kind == "escape" then
        Banner("YOU ESCAPED!!", Color3.fromRGB(255, 215, 90))
        Flash(Color3.fromRGB(255, 215, 90), 0.4)
        Sparks(Color3.fromRGB(255, 215, 90), 80)
        local piece = p.chest and p.chest.piece
        if piece then PieceCard(piece) end
    elseif kind == "speedup" then
        Banner(string.format("%s escaped! %ds left!", p.name or "Someone", p.seconds or 45), Color3.fromRGB(255, 150, 80))
    elseif kind == "standings" then
        local lines = { "FURTHEST" }
        if dailyTarget then table.insert(lines, 1, dailyDone and "Daily: done!" or string.format("Daily: clear %d sections", dailyTarget)) end
        for i, e in ipairs(p.list or {}) do
            if i > 6 then break end
            table.insert(lines, string.format("%d.  %s   %s", i, e.name, e.escaped and "OUT" or ("S" .. tostring(e.section or e.level or 0))))
        end
        standingsLbl.Text = table.concat(lines, "\n")
    elseif kind == "roundover" or kind == "abandon" then
        hud.Enabled = false
        ClearCards()
        danger.BackgroundTransparency = 1
        if kind == "roundover" and (p.best or 0) <= 0 and (p.coins or 0) == 0 and not p.escaped then
            Banner("Run ended", Color3.fromRGB(255, 190, 120))
        elseif kind == "roundover" then
            ShowSummary(p)
        else
            Banner(({ left = "You wandered off.", speed = "That run was stopped.", died = "You were knocked out." })[p.reason] or "Run ended", Color3.fromRGB(255, 190, 120))
        end
    end
end

function MazeController.Init()
    BuildHud()
    RunService.RenderStepped:Connect(function(dt)
        PlacePanel()
        Update(dt, ServerNow())
    end)
    RemoteEvents.MazeEvent.OnClientEvent:Connect(OnEvent)
end

return MazeController
