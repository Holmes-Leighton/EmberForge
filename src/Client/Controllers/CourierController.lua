-- Courier Run on the client: animates the moving platforms, spinning bars, crushers and crumbling platforms on the shared server clock (so everyone sees the same
-- thing), draws this player's own lava wall, shows the run timer, and plays the checkpoint, fall and delivery effects (sparks, flashes, a results screen with a
-- count-up and confetti). The server decides everything that matters (position checks, falls, rewards); this only draws it.
local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local CartCourseData = require(game.ReplicatedStorage.Shared.Data.CartCourseData)     -- (the shared gate clock)
local CourierData    = require(game.ReplicatedStorage.Shared.Data.CourierData)
local RemoteEvents   = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local CourierLayout  = require(game.ReplicatedStorage.Shared.Modules.CourierLayout)
local Theme          = require(game.ReplicatedStorage.Shared.Modules.Theme)

local CourierController = {}

local LocalPlayer = Players.LocalPlayer
local movers, spinners, crushers = {}, {}, {}
local MOVE_TIME = 0.3

local function ServerNow() return workspace:GetServerTimeNow() end

-- ── Moving pieces ─────────────────────────────────────────────────────────────
local function AddMover(part)
    movers[part] = { x0 = part:GetAttribute("X0") or 0, x1 = part:GetAttribute("X1") or 0, period = part:GetAttribute("Period") or 6, phase = part:GetAttribute("Phase") or 0 }
end
local function AddSpinner(part)
    spinners[part] = { omega = part:GetAttribute("Omega") or 1, phase = part:GetAttribute("Phase") or 0, cx = part:GetAttribute("CX") or part.Position.X,
        cz = part:GetAttribute("CZ") or part.Position.Z, y = part:GetAttribute("Y") or part.Position.Y }
end
-- lifts (up and down), depth movers (toward and away), orbiting platforms, swinging blades and the beam pads' circles: all driven by the same shared clock and
-- the same functions (CourierLayout) the server judges with
local lifts, zmovers, orbiters, pendulums, beams = {}, {}, {}, {}, {}
local function AddLift(part)
    lifts[part] = { x = part:GetAttribute("X") or part.Position.X, z = part:GetAttribute("Z") or part.Position.Z, y0 = part:GetAttribute("Y0") or part.Position.Y,
        y1 = part:GetAttribute("Y1") or part.Position.Y, period = part:GetAttribute("Period") or 6, phase = part:GetAttribute("Phase") or 0 }
end
local function AddZMover(part)
    zmovers[part] = { x = part:GetAttribute("X") or part.Position.X, y = part:GetAttribute("Y") or part.Position.Y, z0 = part:GetAttribute("Z0") or part.Position.Z,
        z1 = part:GetAttribute("Z1") or part.Position.Z, period = part:GetAttribute("Period") or 6, phase = part:GetAttribute("Phase") or 0 }
end
local function AddOrbiter(part)
    orbiters[part] = { x = part:GetAttribute("CX") or part.Position.X, y = part:GetAttribute("Y") or part.Position.Y, z = part:GetAttribute("CZ") or part.Position.Z,
        radius = part:GetAttribute("Radius") or 8, omega = part:GetAttribute("Omega") or 0.5, phase = part:GetAttribute("Phase") or 0 }
end
local function AddPendulum(part)
    pendulums[part] = { x = part:GetAttribute("PX") or part.Position.X, pivotY = part:GetAttribute("PY") or part.Position.Y, z = part:GetAttribute("PZ") or part.Position.Z,
        length = part:GetAttribute("Length") or 12, amp = part:GetAttribute("Amp") or 0.9, period = part:GetAttribute("Period") or 3, phase = part:GetAttribute("Phase") or 0,
        off = part:GetAttribute("Off") or (part:GetAttribute("Length") or 12) }
end
local function AddBeam(part)
    local n = part:GetAttribute("N") or 1
    local circles = {}
    for i = 1, n do circles[i] = true end
    beams[part] = { f = { seed = part:GetAttribute("Seed") or 1, circles = circles, period = part:GetAttribute("Period") or 3, warn = part:GetAttribute("Warn") or 1,
        fire = part:GetAttribute("Fire") or 0.7, phase = part:GetAttribute("Phase") or 0 }, circle = part:GetAttribute("Circle") or 1, role = part:GetAttribute("Role") or "column" }
end

local function AddCrusher(unit)
    crushers[unit] = { base = nil, o = 0 }
end

local function AddCrumble(part)
    local fallen = false
    part.Touched:Connect(function(hit)
        if fallen then return end
        local char = LocalPlayer.Character
        if not (char and hit:IsDescendantOf(char)) then return end
        fallen = true
        local delay, respawn = part:GetAttribute("Delay") or 0.6, part:GetAttribute("Respawn") or 3
        local original = part.Color
        task.delay(delay * 0.5, function() part.Color = Color3.fromRGB(255, 120, 60) end)        -- it shakes red, then goes
        task.delay(delay, function()
            part.CanCollide = false
            for _, d in ipairs(part:GetDescendants()) do if d:IsA("BasePart") then d.Transparency = 1 end end
            part.Transparency = 1
        end)
        task.delay(delay + respawn, function()
            part.Color, part.Transparency, part.CanCollide = original, 0, true
            for _, d in ipairs(part:GetDescendants()) do if d:IsA("BasePart") then d.Transparency = 0 end end
            fallen = false
        end)
    end)
end

-- A platform moved by setting its CFrame does not carry the character standing on it sideways (only up and down happens by itself), so the local player is
-- carried here: if they are standing on the platform, they move by exactly what it moved. Sets the platform's new position and returns nothing.
local function MoveCarrying(part, newCF)
    local old = part.Position
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    part.CFrame = newCF
    if not root then return end
    local d = part.Position - old
    if d.X == 0 and d.Z == 0 then return end
    local rel = root.Position - old                                   -- where the player stood relative to the platform before it moved
    local half = part.Size / 2
    if math.abs(rel.X) <= half.X + 0.6 and math.abs(rel.Z) <= half.Z + 0.6 and rel.Y > half.Y - 0.5 and rel.Y < half.Y + 6 then
        root.CFrame = root.CFrame + Vector3.new(d.X, 0, d.Z)
    end
end

local function StepWorld(dt, now)
    for part, m in pairs(movers) do
        if part.Parent then
            local f = 0.5 - 0.5 * math.cos(2 * math.pi * (now + m.phase) / m.period)
            local p = part.Position
            MoveCarrying(part, CFrame.new(m.x0 + (m.x1 - m.x0) * f, p.Y, p.Z))
        else movers[part] = nil end
    end
    for part, s in pairs(spinners) do
        if part.Parent then
            -- (the server clock is about 1.8 billion seconds and CFrame.Angles keeps its angle in 32 bits, so a big angle only changes every couple of minutes: the bar
            -- looked frozen while the server still judged it moving. Wrap it into one turn first, in doubles.)
            part.CFrame = CFrame.new(s.cx, s.y, s.cz) * CFrame.Angles(0, -((s.phase + s.omega * now) % (2 * math.pi)), 0)
        else spinners[part] = nil end
    end
    for part, l in pairs(lifts) do
        if part.Parent then MoveCarrying(part, CFrame.new(l.x, CourierLayout.LiftY(l, now), l.z)) else lifts[part] = nil end
    end
    for part, m in pairs(zmovers) do
        if part.Parent then MoveCarrying(part, CFrame.new(m.x, m.y, CourierLayout.ZMoverZ(m, now))) else zmovers[part] = nil end
    end
    for part, o in pairs(orbiters) do
        if part.Parent then
            local x, z = CourierLayout.OrbitPos(o, now)
            MoveCarrying(part, CFrame.new(x, o.y, z))
        else orbiters[part] = nil end
    end
    for part, p in pairs(pendulums) do
        if part.Parent then
            local a = p.amp * math.sin(2 * math.pi * (now + p.phase) / p.period)
            part.CFrame = CFrame.new(p.x, p.pivotY, p.z) * CFrame.Angles(0, 0, a) * CFrame.new(0, -p.off, 0)
        else pendulums[part] = nil end
    end
    for part, b in pairs(beams) do
        if part.Parent then
            local state, k = nil, 0
            for _, s in ipairs(CourierLayout.BeamState(b.f, now)) do
                if s.idx == b.circle and (state ~= "fire") then state, k = s.state, s.k end
            end
            local mine = state ~= nil
            if b.role == "column" then
                part.Transparency = (mine and state == "fire") and 0.12 or (mine and state == "warn") and (0.9 - 0.15 * k) or 1
            else                                                    -- the glowing disc on the floor: faint at rest, pulsing as it charges, blazing as it fires
                part.Transparency = (mine and state == "fire") and 0 or (mine and state == "warn") and (0.55 - 0.45 * k * (0.6 + 0.4 * math.sin(now * 18))) or 0.8
            end
        else beams[part] = nil end
    end
    for unit, c in pairs(crushers) do
        if unit.Parent then
            c.base = c.base or unit:GetPivot()
            local def = { open = unit:GetAttribute("Open") or 4, closed = unit:GetAttribute("Closed") or 2.5, phase = unit:GetAttribute("Phase") or 0 }
            local open = CartCourseData.HazardOpen(def, now)
            local want = open and 1 or 0
            if c.o < want then c.o = math.min(want, c.o + dt / MOVE_TIME) elseif c.o > want then c.o = math.max(want, c.o - dt / (MOVE_TIME * 0.4)) end        -- it slams faster than it rises
            unit:PivotTo(c.base * CFrame.new(0, c.o * (unit:GetAttribute("Lift") or 15), 0))
        else crushers[unit] = nil end
    end
end

-- ── This player's lava wall ───────────────────────────────────────────────────
local lava, lavaGui
local function LavaX(now)
    local x0, t0, speed = LocalPlayer:GetAttribute("CourierLavaX0"), LocalPlayer:GetAttribute("CourierLavaT0"), LocalPlayer:GetAttribute("CourierLavaSpeed")
    if not (x0 and t0 and speed) then return nil end
    return x0 + speed * math.max(0, now - t0)
end

local function EnsureLava()
    if lava and lava.Parent then return lava end
    lava = Instance.new("Part")
    lava.Name = "CourierLava"
    lava.Anchored, lava.CanCollide, lava.CanQuery, lava.CanTouch = true, false, false, false
    lava.Material, lava.Color, lava.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 96, 24), 0.15
    lava.Size = Vector3.new(8, 110, 150)
    lava.Parent = workspace
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 120, 40), 60, 3
    light.Parent = lava
    local fire = Instance.new("ParticleEmitter")
    fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 60, 20))
    fire.Size, fire.Lifetime, fire.Rate, fire.Speed = NumberSequence.new(6, 0), NumberRange.new(1.2, 2.2), 60, NumberRange.new(4, 9)
    fire.LightEmission, fire.EmissionDirection = 1, Enum.NormalId.Right
    fire.Parent = lava
    return lava
end

-- ── HUD ───────────────────────────────────────────────────────────────────────
local hud, hudTitle, hudTime, hudInfo, hudLava, flash, banner
local runInfo                  -- { course, checkpoints, par, best }

local function Clock(seconds)
    seconds = math.max(0, seconds)
    local m = math.floor(seconds / 60)
    return string.format("%d:%04.1f", m, seconds - m * 60)
end

-- The run's timers sit down the left with the event card and the player card (not in the middle of the screen, where you are looking): just beside that column,
-- level with the event card; on a phone, above the player card like the Sky Tower's badge.
local hudPanel
local function PlaceHudPanel()
    if not hudPanel then return end
    local main = LocalPlayer.PlayerGui:FindFirstChild("HUD")
    local card = main and main:FindFirstChild("MainFrame")
    if not (card and card.Visible) then hudPanel.AnchorPoint, hudPanel.Position = Vector2.new(0, 0), UDim2.new(0, 14, 0, 96) return end
    local inset = (main.IgnoreGuiInset and 0 or game:GetService("GuiService"):GetGuiInset().Y)
    local x, y, w, h = card.AbsolutePosition.X, card.AbsolutePosition.Y + inset, card.AbsoluteSize.X, card.AbsoluteSize.Y
    if require(game.ReplicatedStorage.Shared.Modules.ScreenMode).Compact() then
        hudPanel.AnchorPoint = Vector2.new(0, 1)
        hudPanel.Position = UDim2.fromOffset(x, y - 6)
    else
        hudPanel.AnchorPoint = Vector2.new(0, 0)
        hudPanel.Position = UDim2.fromOffset(x + w + 10, math.max(60, y - 92))
    end
end

local function BuildHud()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    hud = Instance.new("ScreenGui")
    hud.Name, hud.ResetOnSpawn, hud.IgnoreGuiInset, hud.DisplayOrder, hud.Enabled = "CourierHUD", false, true, 8, false
    hud.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    hudPanel = panel
    panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0, 0), UDim2.new(0, 216, 0, 96), UDim2.new(0, 280, 0, 92)
    panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Color3.fromRGB(26, 18, 14), 0.15, 0
    panel.Parent = hud
    Theme.AddCorner(panel, Theme.Corner.Medium)
    Theme.AddStroke(panel, Color3.fromRGB(255, 190, 80), 2)

    hudTitle = Theme.Label(panel, "", Theme.TextSize.Small, Color3.fromRGB(255, 220, 150), Theme.Fonts.Heading)
    hudTitle.Position, hudTitle.Size, hudTitle.TextXAlignment = UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 18), Enum.TextXAlignment.Center
    hudTime = Theme.Label(panel, "0:00.0", 30, Color3.fromRGB(255, 255, 255), Theme.Fonts.Title)
    hudTime.Position, hudTime.Size, hudTime.TextXAlignment = UDim2.new(0, 10, 0, 20), UDim2.new(1, -20, 0, 36), Enum.TextXAlignment.Center
    hudInfo = Theme.Label(panel, "", Theme.TextSize.Small, Color3.fromRGB(230, 220, 200), Theme.Fonts.Body)
    hudInfo.Position, hudInfo.Size, hudInfo.TextXAlignment = UDim2.new(0, 10, 0, 58), UDim2.new(1, -20, 0, 16), Enum.TextXAlignment.Center
    hudLava = Theme.Label(panel, "", Theme.TextSize.Small, Color3.fromRGB(255, 120, 80), Theme.Fonts.Heading)
    hudLava.Position, hudLava.Size, hudLava.TextXAlignment = UDim2.new(0, 10, 0, 74), UDim2.new(1, -20, 0, 16), Enum.TextXAlignment.Center

    flash = Instance.new("Frame")                               -- full-screen colour flash (falls, lava, delivery)
    flash.Name = "Flash"
    flash.Size, flash.BackgroundTransparency, flash.BorderSizePixel, flash.Visible = UDim2.new(1, 0, 1, 0), 1, 0, false
    flash.ZIndex = 20
    flash.Parent = hud

    banner = Theme.Label(hud, "", 34, Color3.fromRGB(255, 255, 255), Theme.Fonts.Title)       -- big message in the middle ("Checkpoint 2/6!")
    banner.AnchorPoint, banner.Position, banner.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.32, 0), UDim2.new(0.8, 0, 0, 60)
    banner.TextXAlignment, banner.TextTransparency, banner.TextStrokeTransparency, banner.TextStrokeColor3 = Enum.TextXAlignment.Center, 1, 1, Color3.fromRGB(20, 10, 6)
    banner.ZIndex = 21
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
    TweenService:Create(banner, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1, Position = UDim2.new(0.5, 0, 0.26, 0) }):Play()
end

-- A burst of sparks on the player
local function Sparks(color, count)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local e = Instance.new("ParticleEmitter")
    e.Color, e.Size, e.Lifetime, e.Speed = ColorSequence.new(color or Color3.fromRGB(255, 220, 120)), NumberSequence.new(0.9, 0), NumberRange.new(0.6, 1.2), NumberRange.new(14, 26)
    e.SpreadAngle, e.LightEmission, e.Rate, e.Acceleration = Vector2.new(180, 180), 1, 0, Vector3.new(0, -25, 0)
    e.Parent = root
    e:Emit(count or 30)
    Debris:AddItem(e, 2)
end

local function UpdateHud(now)
    if not (hud and hud.Enabled) then return end
    local start = LocalPlayer:GetAttribute("CourierStart")
    if not start then return end
    local respawns = LocalPlayer:GetAttribute("CourierRespawns") or 0
    local elapsed = (now - start) + respawns * CourierData.RESPAWN_PENALTY
    hudTime.Text = Clock(elapsed)
    hudTime.TextColor3 = (runInfo and runInfo.par and elapsed <= runInfo.par) and Color3.fromRGB(255, 232, 140) or Color3.fromRGB(255, 255, 255)
    local cp = (LocalPlayer:GetAttribute("CourierCP") or 1) - 1
    hudInfo.Text = string.format("Checkpoint %d/%d   Par %s%s", cp, runInfo and runInfo.checkpoints or 0, Clock(runInfo and runInfo.par or 0),
        runInfo and runInfo.best and ("   Best " .. Clock(runInfo.best)) or "")
    local lx = LavaX(now)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if lx and root then
        local gap = root.Position.X - lx
        hudLava.Text = string.format("LAVA %d studs behind you!", math.max(0, math.floor(gap)))
        hudLava.TextColor3 = gap < 25 and Color3.fromRGB(255, 70, 50) or Color3.fromRGB(255, 160, 100)
        hudLava.Visible = true
        local wall = EnsureLava()
        wall.CFrame = CFrame.new(lx - 4, 40, LocalPlayer:GetAttribute("CourierLavaZ") or 142)
        if gap < 20 and math.floor(now * 4) % 2 == 0 then Flash(Color3.fromRGB(255, 40, 20), 0.18) end        -- the screen pulses red as it closes in
    else
        hudLava.Visible = false
        if lava then lava:Destroy() lava = nil end
    end
end

-- ── Results screen ────────────────────────────────────────────────────────────
local function Confetti(parent)
    local colors = { Color3.fromRGB(255, 120, 80), Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 210, 255), Color3.fromRGB(140, 255, 150), Color3.fromRGB(230, 130, 255) }
    for i = 1, 60 do
        local bit = Instance.new("Frame")
        bit.Size = UDim2.new(0, math.random(8, 14), 0, math.random(8, 14))
        bit.Position = UDim2.new(math.random(), 0, -0.1, 0)
        bit.BackgroundColor3 = colors[math.random(#colors)]
        bit.BorderSizePixel, bit.ZIndex, bit.Rotation = 0, 30, math.random(0, 360)
        bit.Parent = parent
        local t = math.random(18, 35) / 10
        TweenService:Create(bit, TweenInfo.new(t, Enum.EasingStyle.Quad), { Position = UDim2.new(bit.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0), Rotation = bit.Rotation + math.random(-300, 300) }):Play()
        Debris:AddItem(bit, t + 0.2)
    end
end

local MATERIAL_NAMES = {}
local function MatName(id)
    if MATERIAL_NAMES[id] then return MATERIAL_NAMES[id] end
    local ok, MaterialData = pcall(function() return require(game.ReplicatedStorage.Shared.Data.MaterialData) end)
    local def = ok and MaterialData.Get(id)
    MATERIAL_NAMES[id] = def and def.displayName or id
    return MATERIAL_NAMES[id]
end

local function ShowResults(s)
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "CourierResults", false, true, 40
    gui.Parent = playerGui
    local scrim = Instance.new("Frame")
    scrim.Size, scrim.BackgroundColor3, scrim.BackgroundTransparency, scrim.BorderSizePixel = UDim2.new(1, 0, 1, 0), Color3.fromRGB(0, 0, 0), 0.5, 0
    scrim.Parent = gui

    local W, H = 420, 430
    local panel = Instance.new("Frame")
    panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, W, 0, H)
    panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(32, 22, 18), 0
    panel.Parent = gui
    Theme.AddCorner(panel, Theme.Corner.Large)
    local medalColor = s.medal == "Gold" and Color3.fromRGB(255, 215, 90) or (s.medal == "Silver" and Color3.fromRGB(210, 220, 235) or Color3.fromRGB(230, 200, 150))
    Theme.AddStroke(panel, medalColor, 3)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.6
    scale.Parent = panel
    TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = math.min(1, (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700) / (H + 60)) }):Play()

    local y = 14
    local function line(text, size, color, font, height)
        local l = Theme.Label(panel, text, size, color, font or Theme.Fonts.Body)
        l.Position, l.Size, l.TextXAlignment = UDim2.new(0, 20, 0, y), UDim2.new(1, -40, 0, height or size + 6), Enum.TextXAlignment.Center
        y += (height or size + 6) + 2
        return l
    end
    line(s.medal and (string.upper(s.medal) .. " DELIVERY!") or "DELIVERED!", 30, medalColor, Theme.Fonts.Title, 40)
    line(s.course, 16, Color3.fromRGB(255, 220, 150), Theme.Fonts.Heading)
    line(Clock(s.seconds), 38, Color3.fromRGB(255, 255, 255), Theme.Fonts.Title, 48)
    local detail = string.format("Par %s   %s", Clock(s.par), s.respawns > 0 and (s.respawns .. " fall" .. (s.respawns > 1 and "s" or "") .. " (+" .. s.respawns * CourierData.RESPAWN_PENALTY .. "s)") or "No falls!")
    line(detail, 14, Color3.fromRGB(220, 210, 190))
    if s.personalBest then line(s.previousBest and ("NEW PERSONAL BEST!  (was " .. Clock(s.previousBest) .. ")") or "FIRST TIME ON THE BOARD!", 16, Color3.fromRGB(120, 255, 150), Theme.Fonts.Heading) end
    y += 6
    local coins = line("+0 coins", 24, Color3.fromRGB(255, 215, 90), Theme.Fonts.Heading, 32)
    local xpLine = line(string.format("+%d Courier XP", s.xp), 16, Color3.fromRGB(150, 220, 255), Theme.Fonts.Heading)

    -- XP bar
    local bar = Instance.new("Frame")
    bar.Position, bar.Size, bar.BackgroundColor3, bar.BorderSizePixel = UDim2.new(0, 60, 0, y), UDim2.new(1, -120, 0, 12), Color3.fromRGB(20, 14, 12), 0
    bar.Parent = panel
    Theme.AddCorner(bar, UDim.new(0, 6))
    local fill = Instance.new("Frame")
    fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = UDim2.new(0, 0, 1, 0), Color3.fromRGB(110, 200, 255), 0
    fill.Parent = bar
    Theme.AddCorner(fill, UDim.new(0, 6))
    local frac = s.xpNeeded > 0 and math.clamp(s.xpInto / s.xpNeeded, 0, 1) or 1
    TweenService:Create(fill, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = UDim2.new(frac, 0, 1, 0) }):Play()
    y += 18
    line(s.levelUps > 0 and string.format("LEVEL UP!  Courier Level %d", s.level) or string.format("Courier Level %d", s.level), 15,
        s.levelUps > 0 and Color3.fromRGB(255, 232, 120) or Color3.fromRGB(220, 210, 190), Theme.Fonts.Heading)
    y += 4

    local items = {}
    for _, m in ipairs(s.materials or {}) do table.insert(items, string.format("%s x%d", MatName(m.id), m.qty)) end
    if #items > 0 then line(table.concat(items, "    "), 15, Color3.fromRGB(235, 225, 205)) end
    if s.bundleSkipped then line("(Daily material limit reached: coins and XP only)", 12, Color3.fromRGB(180, 170, 150)) end
    if s.cappedCoins then line("(Daily coin limit reached)", 12, Color3.fromRGB(180, 170, 150)) end
    if s.rare then line(string.format("RARE FIND!  %s x%d", MatName(s.rare.id), s.rare.qty), 16, Color3.fromRGB(255, 150, 255), Theme.Fonts.Heading) end
    if s.daily then line(string.format("DAILY CHALLENGE!  +%d coins  +%s x%d", s.daily.coins, MatName(s.daily.rare.id), s.daily.rare.qty), 15, Color3.fromRGB(255, 232, 120), Theme.Fonts.Heading) end

    local ok = Theme.Button(panel, "Nice!", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255))
    ok.AnchorPoint, ok.Position, ok.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), UDim2.new(0, 160, 0, 40)
    ok.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- the coins count up
    task.spawn(function()
        local total = s.coins
        for i = 1, 24 do
            coins.Text = string.format("+%d coins", math.floor(total * i / 24))
            task.wait(0.04)
        end
        coins.Text = string.format("+%d coins", total)
    end)
    Confetti(gui)
    Flash(medalColor, 0.35)
    Sparks(medalColor, 60)
    task.delay(30, function() if gui.Parent then gui:Destroy() end end)
end

-- ── Events from the server ────────────────────────────────────────────────────
local REASONS = { fell = "You fell!", lava = "The lava got you!", crushed = "Crushed!", spun = "Knocked off by the bar!", swung = "Hit by a swinging blade!", zapped = "Zapped by a beam of light!" }

local function OnEvent(kind, p)
    p = p or {}
    if kind == "start" then
        runInfo = { course = p.course, checkpoints = p.checkpoints, par = p.par, best = p.best }
        hud.Enabled = true
        hudTitle.Text = string.upper(p.course) .. (p.lava and "   (lava chase!)" or "")
        Banner("GO!", Color3.fromRGB(255, 232, 120))
        Sparks(Color3.fromRGB(255, 220, 120), 25)
    elseif kind == "checkpoint" then
        Banner(string.format("Checkpoint %d/%d", p.index, p.total), Color3.fromRGB(150, 255, 170))
        Sparks(Color3.fromRGB(150, 255, 170), 35)
        Flash(Color3.fromRGB(150, 255, 170), 0.15)
    elseif kind == "respawn" then
        Banner(string.format("%s  +%ds", REASONS[p.reason] or "Back to the checkpoint", p.penalty or 0), Color3.fromRGB(255, 110, 90))
        Flash(Color3.fromRGB(255, 50, 30), 0.45)
    elseif kind == "finish" then
        hud.Enabled = false
        if lava then lava:Destroy() lava = nil end
        ShowResults(p)
    elseif kind == "abandon" then
        hud.Enabled = false
        if lava then lava:Destroy() lava = nil end
        local why = { left = "You wandered off the course.", idle = "That run timed out.", speed = "That run was stopped.", died = "You were knocked out." }
        Banner(why[p.reason] or "Run ended", Color3.fromRGB(255, 190, 120))
    end
end

function CourierController.Init()
    BuildHud()
    for _, p in ipairs(CollectionService:GetTagged("EFCourierMover")) do AddMover(p) end
    CollectionService:GetInstanceAddedSignal("EFCourierMover"):Connect(AddMover)
    for _, p in ipairs(CollectionService:GetTagged("EFCourierSpinner")) do AddSpinner(p) end
    CollectionService:GetInstanceAddedSignal("EFCourierSpinner"):Connect(AddSpinner)
    for _, u in ipairs(CollectionService:GetTagged("EFCourierCrusher")) do AddCrusher(u) end
    for tag, add in pairs({ EFCourierLift = AddLift, EFCourierZMover = AddZMover, EFCourierOrbit = AddOrbiter, EFCourierPendulum = AddPendulum, EFCourierBeam = AddBeam }) do
        for _, p in ipairs(CollectionService:GetTagged(tag)) do add(p) end
        CollectionService:GetInstanceAddedSignal(tag):Connect(add)
    end
    CollectionService:GetInstanceAddedSignal("EFCourierCrusher"):Connect(AddCrusher)
    for _, p in ipairs(CollectionService:GetTagged("EFCourierCrumble")) do AddCrumble(p) end
    CollectionService:GetInstanceAddedSignal("EFCourierCrumble"):Connect(AddCrumble)
    RunService.RenderStepped:Connect(function(dt)
        local now = ServerNow()
        StepWorld(dt, now)
        UpdateHud(now)
        PlaceHudPanel()
    end)
    RemoteEvents.CourierEvent.OnClientEvent:Connect(OnEvent)
end

return CourierController
