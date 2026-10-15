-- The Sky Tower on the client: the level counter and round clock, the live "highest level" list, this player's own rising lava, level-up and fall effects, and the
-- summary at the end of a climb. The server decides everything that matters (levels, falls, lava hits, rewards); this only draws it.
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")

local TowerData    = require(game.ReplicatedStorage.Shared.Data.TowerData)
local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local Theme        = require(game.ReplicatedStorage.Shared.Modules.Theme)
local ScreenMode = require(game.ReplicatedStorage.Shared.Modules.ScreenMode)
local TowerArtColors = nil

local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local TowerController = {}

-- ── Bounce pads and sweeper bars ──────────────────────────────────────────────
-- A bounce pad throws the local character up and forward (the character belongs to this client, so setting its velocity here is what moves it). A sweeper bar slides
-- across its beam on the shared server clock, the same position for everyone; the server separately decides who it knocks off.
local bounceCooldown = 0
local sweepers = {}

local function AddBounce(pad)
    pad.Touched:Connect(function(hit)
        local char = LocalPlayer.Character
        if not (char and hit:IsDescendantOf(char)) then return end
        local now = os.clock()
        if now - bounceCooldown < 0.6 then return end
        bounceCooldown = now
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local dir = pad:GetAttribute("Dir") or 1
        root.AssemblyLinearVelocity = Vector3.new(dir * (pad:GetAttribute("HSpeed") or 28), pad:GetAttribute("Power") or 78, 0)
        local e = Instance.new("ParticleEmitter")
        e.Color, e.Size, e.Lifetime, e.Speed = ColorSequence.new(Color3.fromRGB(120, 255, 170)), NumberSequence.new(1.2, 0), NumberRange.new(0.5, 1), NumberRange.new(10, 20)
        e.SpreadAngle, e.LightEmission, e.Rate = Vector2.new(60, 60), 1, 0
        e.Parent = root
        e:Emit(30)
        Debris:AddItem(e, 1.5)
    end)
end

local function AddSweeper(bar)
    sweepers[bar] = { amp = bar:GetAttribute("Amp") or 4, period = bar:GetAttribute("Period") or 3, phase = bar:GetAttribute("Phase") or 0,
        x = bar:GetAttribute("X") or bar.Position.X, y = bar:GetAttribute("Y") or bar.Position.Y, z0 = bar:GetAttribute("Z0") or bar.Position.Z }
end

local function StepSweepers(now)
    for bar, s in pairs(sweepers) do
        if bar.Parent then
            bar.CFrame = CFrame.new(s.x, s.y, s.z0 + s.amp * math.sin(2 * math.pi * (now + s.phase) / s.period))
        else
            sweepers[bar] = nil
        end
    end
end

-- ── Flickering flames ─────────────────────────────────────────────────────────
-- Every light the world tags "EFFlicker" (the braziers and lanterns on the Sky Tower doorways) breathes: the brightness wanders around its normal level so the fire looks alive.
-- Done here on each player's screen, so it costs the server nothing.
local flickers = {}
local function AddFlicker(light)
    if light:IsA("PointLight") then flickers[light] = { base = light.Brightness, seed = math.random() * 100 } end
end
local function StepFlicker(now)
    for light, s in pairs(flickers) do
        if light.Parent then
            light.Brightness = s.base * (0.78 + 0.5 * (math.noise(now * 7, s.seed) + 0.5) + 0.1 * math.sin(now * 23 + s.seed))
        else
            flickers[light] = nil
        end
    end
end

local function ServerNow() return workspace:GetServerTimeNow() end

local hud, levelLbl, clockLbl, infoLbl, lavaLbl, standingsFrame, standingsLbl, flash, banner, badge
local badgeCompact = nil
local roundEnds, total = nil, 30
local dailyTarget, dailyDone = nil, false
local lava

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function LevelColor(level)
    return Color3.fromHSV(0.02 + 0.72 * (level - 1) / math.max(1, total - 1), 0.75, 1)
end

-- ── HUD ───────────────────────────────────────────────────────────────────────
local function BuildHud()
    hud = Instance.new("ScreenGui")
    hud.Name, hud.ResetOnSpawn, hud.IgnoreGuiInset, hud.DisplayOrder, hud.Enabled = "TowerHUD", false, true, 8, false
    hud.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local panel = Instance.new("Frame")
    badge = panel
    panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 118), UDim2.new(0, 300, 0, 96)
    panel.BackgroundColor3, panel.BackgroundTransparency, panel.BorderSizePixel = Color3.fromRGB(26, 18, 14), 0.15, 0
    panel.Parent = hud
    Theme.AddCorner(panel, Theme.Corner.Medium)
    Theme.AddStroke(panel, Color3.fromRGB(190, 120, 255), 2)
    levelLbl = Theme.Label(panel, "LEVEL 1 / 30", 26, Color3.fromRGB(255, 255, 255), Theme.Fonts.Title)
    levelLbl.Position, levelLbl.Size, levelLbl.TextXAlignment = UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 32), Enum.TextXAlignment.Center
    clockLbl = Theme.Label(panel, "Round 10:00", 20, Color3.fromRGB(255, 232, 170), Theme.Fonts.Heading)
    clockLbl.Position, clockLbl.Size, clockLbl.TextXAlignment = UDim2.new(0, 10, 0, 38), UDim2.new(1, -20, 0, 24), Enum.TextXAlignment.Center
    infoLbl = Theme.Label(panel, "", Theme.TextSize.Small, Color3.fromRGB(230, 220, 200), Theme.Fonts.Body)
    infoLbl.Position, infoLbl.Size, infoLbl.TextXAlignment = UDim2.new(0, 10, 0, 62), UDim2.new(1, -20, 0, 16), Enum.TextXAlignment.Center
    lavaLbl = Theme.Label(panel, "", Theme.TextSize.Small, Color3.fromRGB(255, 130, 90), Theme.Fonts.Heading)
    lavaLbl.Position, lavaLbl.Size, lavaLbl.TextXAlignment = UDim2.new(0, 10, 0, 78), UDim2.new(1, -20, 0, 16), Enum.TextXAlignment.Center

    standingsFrame = Instance.new("Frame")
    standingsFrame.AnchorPoint, standingsFrame.Position, standingsFrame.Size = Vector2.new(1, 0), UDim2.new(1, -90, 0, 200), UDim2.new(0, 200, 0, 130)
    standingsFrame.BackgroundColor3, standingsFrame.BackgroundTransparency, standingsFrame.BorderSizePixel = Color3.fromRGB(26, 18, 14), 0.25, 0
    standingsFrame.Parent = hud
    Theme.AddCorner(standingsFrame, Theme.Corner.Small)
    standingsLbl = Theme.Label(standingsFrame, "", Theme.TextSize.Small, Color3.fromRGB(240, 230, 210), Theme.Fonts.Body)
    standingsLbl.Position, standingsLbl.Size, standingsLbl.TextYAlignment = UDim2.new(0, 8, 0, 6), UDim2.new(1, -16, 1, -12), Enum.TextYAlignment.Top

    flash = Instance.new("Frame")
    flash.Size, flash.BackgroundTransparency, flash.BorderSizePixel, flash.Visible, flash.ZIndex = UDim2.new(1, 0, 1, 0), 1, 0, false, 20
    flash.Parent = hud
    banner = Theme.Label(hud, "", 36, Color3.fromRGB(255, 255, 255), Theme.Fonts.Title)
    banner.AnchorPoint, banner.Position, banner.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.32, 0), UDim2.new(0.8, 0, 0, 64)
    banner.TextXAlignment, banner.TextTransparency, banner.TextStrokeTransparency, banner.TextStrokeColor3, banner.ZIndex = Enum.TextXAlignment.Center, 1, 1, Color3.fromRGB(20, 10, 6), 21
end

-- On a phone the badge does not sit in the middle of the screen (where you are looking): it goes in the left column, just above the player card, as wide as that card.
-- (The card itself is hidden while climbing, but its frame still has its place and size, which is what this follows.)
local function PlaceBadge()
    if not badge then return end
    local compact = ScreenMode.Compact()
    local card = LocalPlayer.PlayerGui:FindFirstChild("HUD") and LocalPlayer.PlayerGui.HUD:FindFirstChild("MainFrame")
    if compact and card then
        local inset = (LocalPlayer.PlayerGui.HUD.IgnoreGuiInset and 0 or game:GetService("GuiService"):GetGuiInset().Y)
        local w = math.max(card.AbsoluteSize.X, 140)
        badge.AnchorPoint = Vector2.new(0, 1)
        badge.Position = UDim2.fromOffset(card.AbsolutePosition.X, card.AbsolutePosition.Y + inset - 6)
        badge.Size = UDim2.fromOffset(w, 66)
        if badgeCompact ~= true then
            badgeCompact = true
            levelLbl.Position, levelLbl.Size, levelLbl.TextSize = UDim2.new(0, 4, 0, 2), UDim2.new(1, -8, 0, 22), 18
            clockLbl.Position, clockLbl.Size, clockLbl.TextSize = UDim2.new(0, 4, 0, 24), UDim2.new(1, -8, 0, 16), 14
            infoLbl.Position, infoLbl.Size, infoLbl.TextSize = UDim2.new(0, 4, 0, 40), UDim2.new(1, -8, 0, 12), 10
            lavaLbl.Position, lavaLbl.Size, lavaLbl.TextSize = UDim2.new(0, 4, 0, 52), UDim2.new(1, -8, 0, 12), 10
        end
    elseif badgeCompact ~= false then
        badgeCompact = false
        badge.AnchorPoint, badge.Position, badge.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 118), UDim2.new(0, 300, 0, 96)
        levelLbl.Position, levelLbl.Size, levelLbl.TextSize = UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 32), 26
        clockLbl.Position, clockLbl.Size, clockLbl.TextSize = UDim2.new(0, 10, 0, 38), UDim2.new(1, -20, 0, 24), 20
        infoLbl.Position, infoLbl.Size, infoLbl.TextSize = UDim2.new(0, 10, 0, 62), UDim2.new(1, -20, 0, 16), Theme.TextSize.Small
        lavaLbl.Position, lavaLbl.Size, lavaLbl.TextSize = UDim2.new(0, 10, 0, 78), UDim2.new(1, -20, 0, 16), Theme.TextSize.Small
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
    TweenService:Create(banner, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1, Position = UDim2.new(0.5, 0, 0.26, 0) }):Play()
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

-- ── The lava ──────────────────────────────────────────────────────────────────
local function EnsureLava()
    if lava and lava.Parent then return lava end
    lava = Instance.new("Part")
    lava.Name = "TowerLava"
    lava.Anchored, lava.CanCollide, lava.CanQuery, lava.CanTouch = true, false, false, false
    lava.Material, lava.Color, lava.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 96, 24), 0.2
    lava.Size = Vector3.new(700, 6, 700)
    lava.Parent = workspace
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 120, 40), 90, 3
    light.Parent = lava
    local fire = Instance.new("ParticleEmitter")
    fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 60, 20))
    fire.Size, fire.Lifetime, fire.Rate, fire.Speed = NumberSequence.new(8, 0), NumberRange.new(1.5, 2.8), 80, NumberRange.new(5, 12)
    fire.LightEmission, fire.EmissionDirection = 1, Enum.NormalId.Top
    fire.Parent = lava
    return lava
end

local function LavaY(now)
    local y0, t0, rise = LocalPlayer:GetAttribute("TowerLavaY0"), LocalPlayer:GetAttribute("TowerLavaT0"), LocalPlayer:GetAttribute("TowerLavaRise")
    if not (y0 and t0 and rise) then return nil end
    return y0 + rise * math.max(0, now - t0)
end

local noRunSince
local function Update(now)
    if not (hud and hud.Enabled) then return end
    -- safety net: if the server says there is no climb (no TowerLevel for a few seconds) the HUD must not stay up
    if LocalPlayer:GetAttribute("TowerLevel") == nil then
        noRunSince = noRunSince or now
        if now - noRunSince > 3 then
            hud.Enabled = false
            if lava then lava:Destroy() lava = nil end
            noRunSince = nil
            return
        end
    else
        noRunSince = nil
    end
    local level = LocalPlayer:GetAttribute("TowerLevel") or 1
    levelLbl.Text = string.format("LEVEL %d / %d", level, total)
    levelLbl.TextColor3 = LevelColor(level)
    local left = roundEnds and (roundEnds - os.time()) or 0
    clockLbl.Text = "Round  " .. Clock(left)
    clockLbl.TextColor3 = left < 60 and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(255, 232, 170)
    local start = LocalPlayer:GetAttribute("TowerStart")
    local respawns = LocalPlayer:GetAttribute("TowerRespawns") or 0
    infoLbl.Text = string.format("Climbing %s%s", Clock(start and (now - start) + respawns * TowerData.RESPAWN_PENALTY or 0), respawns > 0 and ("   Falls " .. respawns) or "")
    local ly = LavaY(now)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if ly and root then
        local gap = root.Position.Y - ly
        lavaLbl.Text = string.format("LAVA %d studs below you!", math.max(0, math.floor(gap)))
        lavaLbl.TextColor3 = gap < 14 and Color3.fromRGB(255, 70, 50) or Color3.fromRGB(255, 160, 100)
        lavaLbl.Visible = true
        local wall = EnsureLava()
        wall.CFrame = CFrame.new(TowerData.BASE.x + 80, ly - 3, TowerData.BASE.z + 20)
        if gap < 10 and math.floor(now * 4) % 2 == 0 then Flash(Color3.fromRGB(255, 40, 20), 0.18) end
    else
        lavaLbl.Visible = false
        if lava then lava:Destroy() lava = nil end
    end
end

-- ── The end-of-climb summary ──────────────────────────────────────────────────
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
    gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "TowerSummary", false, true, 40
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local scrim = Instance.new("Frame")
    scrim.Size, scrim.BackgroundColor3, scrim.BackgroundTransparency, scrim.BorderSizePixel = UDim2.new(1, 0, 1, 0), Color3.fromRGB(0, 0, 0), 0.5, 0
    scrim.Parent = gui
    local W, H = 420, 360          -- (H is replaced by the real height once the lines are laid out)
    local panel = Instance.new("Frame")
    panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, W, 0, H)
    panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(32, 22, 18), 0
    panel.Parent = gui
    Theme.AddCorner(panel, Theme.Corner.Large)
    local color = s.summit and Color3.fromRGB(255, 215, 90) or LevelColor(s.best)
    Theme.AddStroke(panel, color, 3)
    local y = 14
    local function line(text, size, col, font, height)
        local l = Theme.Label(panel, text, size, col, font or Theme.Fonts.Body)
        l.Position, l.Size, l.TextXAlignment = UDim2.new(0, 20, 0, y), UDim2.new(1, -40, 0, height or size + 6), Enum.TextXAlignment.Center
        y += (height or size + 6) + 2
        return l
    end
    line(s.summit and "SUMMIT!" or "CLIMB OVER", 32, color, Theme.Fonts.Title, 42)
    line(string.format("You reached level %d of %d", s.best, s.total), 20, Color3.fromRGB(255, 255, 255), Theme.Fonts.Heading, 28)
    if s.summit then
        line(string.format("%s%s", s.summit.medal and (s.summit.medal .. " time  ") or "", string.format("%d:%04.1f", math.floor(s.summit.seconds / 60), s.summit.seconds % 60)), 22, Color3.fromRGB(255, 232, 140), Theme.Fonts.Heading)
        if s.summit.personalBest then line("NEW PERSONAL BEST!", 16, Color3.fromRGB(120, 255, 150), Theme.Fonts.Heading) end
        if s.summit.chest and s.summit.chest.firstToday then line("First summit today: double chest!", 14, Color3.fromRGB(255, 220, 150)) end
    end
    local reason = ({ timeup = "Time's up! A new tower is being built.", newround = "A new tower is being built.", left = "You left the tower.", home = "You went home.", speed = "That climb was stopped.", died = "You were knocked out." })[s.reason]
    if reason then line(reason, 14, Color3.fromRGB(200, 190, 170)) end
    y += 6
    line(string.format("+%d coins", s.coins), 26, Color3.fromRGB(255, 215, 90), Theme.Fonts.Heading, 34)
    line(string.format("+%d XP", s.xp + (s.summit and TowerData.SUMMIT_PLAYER_XP or 0)), 16, Color3.fromRGB(150, 220, 255), Theme.Fonts.Heading)
    local items = {}
    for id, qty in pairs(s.materials or {}) do table.insert(items, string.format("%s x%d", MatName(id), qty)) end
    table.sort(items)
    if #items > 0 then line(table.concat(items, "    "), 14, Color3.fromRGB(235, 225, 205), nil, 40) end
    line(string.format("Falls: %d", s.respawns), 13, Color3.fromRGB(190, 180, 160))
    H = y + 62                                                     -- as tall as its lines plus the button, no empty space
    panel.Size = UDim2.new(0, W, 0, H)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.6
    scale.Parent = panel
    TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = math.min(1, (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700) / (H + 60)) }):Play()
    local ok = Theme.Button(panel, "Nice!", Theme.Colors.Accent, Color3.fromRGB(255, 255, 255))
    ok.AnchorPoint, ok.Position, ok.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), UDim2.new(0, 160, 0, 40)
    ok.MouseButton1Click:Connect(function() gui:Destroy() end)
    Flash(color, 0.3)
    Sparks(color, 50)
    task.delay(25, function() if gui.Parent then gui:Destroy() end end)
end

-- ── Events from the server ────────────────────────────────────────────────────
local REASONS = { fell = "You fell!", lava = "The lava got you!", crushed = "Crushed!", spun = "Knocked off by the bar!", swept = "Swept off the beam!", swung = "Hit by a swinging blade!", zapped = "Zapped by a beam of light!", burned = "You stepped on a death tile!" }

local function OnEvent(kind, p)
    p = p or {}
    if kind == "start" then
        total, roundEnds = p.total or total, p.roundEnds
        dailyTarget, dailyDone = p.dailyTarget, p.dailyDone
        hud.Enabled = true
        Banner("CLIMB!", Color3.fromRGB(255, 232, 120))
    elseif kind == "level" then
        if p.repeatLevel then return end
        local col = LevelColor(p.level)
        Banner(string.format("LEVEL %d", p.level), col)
        Sparks(col, 40)
        Flash(col, 0.15)
        if p.daily then
            dailyDone = true
            task.delay(1.2, function()
                Banner(string.format("DAILY CHALLENGE!  +%d coins", p.daily.coins), Color3.fromRGB(255, 232, 120))
                Flash(Color3.fromRGB(255, 232, 120), 0.3)
                Sparks(Color3.fromRGB(255, 232, 120), 60)
            end)
        end
        if p.coins and p.level > 1 then
            task.delay(0.1, function()
                local t = string.format("+%d coins  +%d XP", p.coins, p.xp or 0)
                if p.rare then t ..= "  RARE!" end
                if p.playerLevelUp then t ..= string.format("   Player level %d!", p.playerLevelUp) end
                infoLbl.Text = t
            end)
        end
    elseif kind == "respawn" then
        Banner(string.format("%s  +%ds", REASONS[p.reason] or "Back to your level", p.penalty or 0), Color3.fromRGB(255, 110, 90))
        Flash(Color3.fromRGB(255, 50, 30), 0.45)
    elseif kind == "summit" then
        Banner("SUMMIT!!", Color3.fromRGB(255, 215, 90))
        Flash(Color3.fromRGB(255, 215, 90), 0.4)
        Sparks(Color3.fromRGB(255, 215, 90), 80)
    elseif kind == "speedup" then
        Banner(string.format("%s reached the top! %ds left!", p.name or "Someone", p.seconds or 60), Color3.fromRGB(255, 150, 80))
        roundEnds = math.min(roundEnds or math.huge, os.time() + (p.seconds or 60))
    elseif kind == "standings" then
        roundEnds = p.roundEnds or roundEnds
        local lines = { "HIGHEST" }
        if dailyTarget then table.insert(lines, 1, dailyDone and "Daily: done!" or string.format("Daily: reach level %d", dailyTarget)) end
        for i, e in ipairs(p.list or {}) do
            if i > 6 then break end
            table.insert(lines, string.format("%d.  %s   L%d", i, e.name, e.level))
        end
        standingsLbl.Text = table.concat(lines, "\n")
    elseif kind == "roundover" or kind == "abandon" then
        hud.Enabled = false
        if lava then lava:Destroy() lava = nil end
        if kind == "roundover" and p.best <= 1 and (p.coins or 0) == 0 and not p.summit then
            Banner("Climb ended", Color3.fromRGB(255, 190, 120))            -- just peeked in: no big summary card for nothing
        elseif kind == "roundover" then ShowSummary(p) else Banner(({ left = "You wandered off.", speed = "That climb was stopped.", died = "You were knocked out." })[p.reason] or "Climb ended", Color3.fromRGB(255, 190, 120)) end
    end
end

function TowerController.Init()
    BuildHud()
    for _, pad in ipairs(CollectionService:GetTagged("EFCourierBounce")) do AddBounce(pad) end
    CollectionService:GetInstanceAddedSignal("EFCourierBounce"):Connect(AddBounce)
    for _, bar in ipairs(CollectionService:GetTagged("EFCourierSweeper")) do AddSweeper(bar) end
    CollectionService:GetInstanceAddedSignal("EFCourierSweeper"):Connect(AddSweeper)
    for _, light in ipairs(CollectionService:GetTagged("EFFlicker")) do AddFlicker(light) end
    CollectionService:GetInstanceAddedSignal("EFFlicker"):Connect(AddFlicker)
    RunService.RenderStepped:Connect(function()
        local now = ServerNow()
        StepSweepers(now)
        StepFlicker(now)
        PlaceBadge()
        Update(now)
    end)
    RemoteEvents.TowerEvent.OnClientEvent:Connect(OnEvent)
end

return TowerController
