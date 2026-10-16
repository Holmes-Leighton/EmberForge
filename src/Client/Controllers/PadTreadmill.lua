-- The mining pads are treadmills: a player standing still on one runs on the spot (faster the higher their speed level, SpeedData), the pad throws up embers
-- in its colour and its light beats in time with the footsteps. Walking off hands the character straight back to the normal animations.
-- Everything is drawn on each player's own screen from where the characters stand, so everyone sees everyone running on the pads.
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local PadData   = require(game.ReplicatedStorage.Shared.Data.PadData)
local SpeedData = require(game.ReplicatedStorage.Shared.Data.SpeedData)

local PadTreadmill = {}

local RUN_R15, RUN_R6 = "rbxassetid://507767714", "rbxassetid://180426354"      -- Roblox's own run animations
local BEAT_HZ = 2.4                                                              -- footsteps per second at normal speed (the animation is scaled up with speed)

local pads = {}          -- { def, part, emitter, light, baseBrightness, occupied }
local tracks = {}        -- character -> AnimationTrack
local lookedFor = 0

-- The treadmill belt: a thin see-through canvas just above the pad's top with rows of bright stripes that slide towards the front of the pad (the runner faces the
-- info board). It fades in while somebody runs on the spot and slides faster the faster they are. Built here, on this client only.
local BELT_STUDS = 15                                     -- the belt is a circle this wide: the pad's round inner floor (the rim and the beam posts stay clear)
local BELT_PX, BAR_GAP, BAR_COUNT = BELT_STUDS * 24, 80, 6   -- canvas size in pixels (24 per stud) and the spacing / number of stripes
local BELT_TURN = CFrame.Angles(0, math.pi / 2, 0)       -- (turned so the stripes lie across the pad and slide along it, not sideways)
local function MakeBelt(def, part)
    local canvas = Instance.new("Part")
    canvas.Name = "TreadmillBelt"
    canvas.Anchored, canvas.CanCollide, canvas.CanQuery, canvas.CanTouch, canvas.CastShadow = true, false, false, false, false
    canvas.Transparency = 1
    canvas.Size = Vector3.new(BELT_STUDS, 0.1, BELT_STUDS)
    canvas.CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.2, 0) * BELT_TURN
    canvas.Parent = part
    local gui = Instance.new("SurfaceGui")
    gui.Face, gui.SizingMode, gui.CanvasSize = Enum.NormalId.Top, Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(BELT_PX, BELT_PX)
    gui.LightInfluence, gui.Brightness = 0, 2
    gui.Parent = canvas
    local group = Instance.new("CanvasGroup")
    group.Name = "Belt"
    group.Size, group.BackgroundTransparency, group.GroupTransparency, group.ClipsDescendants = UDim2.fromScale(1, 1), 1, 1, true
    group.Parent = gui
    local round = Instance.new("UICorner")                                  -- the pad is round: the stripes are cut to a circle, so they shorten towards the edges
    round.CornerRadius = UDim.new(0.5, 0)
    round.Parent = group
    local bright = def.color:Lerp(Color3.new(1, 1, 1), 0.8)
    local bars = {}
    for i = 1, BAR_COUNT + 1 do
        local bar = Instance.new("Frame")
        bar.Size, bar.BackgroundColor3, bar.BackgroundTransparency, bar.BorderSizePixel = UDim2.new(1, 0, 0, 40), bright, 0.1, 0
        bar.Parent = group
        local fade = Instance.new("UIGradient")                              -- stripes fade out towards the left and right edges
        fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.05, 0), NumberSequenceKeypoint.new(0.95, 0), NumberSequenceKeypoint.new(1, 1) })
        fade.Parent = bar
        bars[i] = bar
    end
    return { canvas = canvas, group = group, bars = bars }
end

local function FindPads()
    for _, def in ipairs(PadData.Pads) do
        local entry
        for _, e in ipairs(pads) do if e.def == def then entry = e break end end
        if not entry then
            local part = workspace:FindFirstChild("Pad_" .. def.id, true)
            if part and part:IsA("BasePart") then
                local emitter = Instance.new("ParticleEmitter")
                emitter.Name = "TreadmillEmbers"
                emitter.Rate, emitter.Enabled = 0, false
                emitter.Lifetime = NumberRange.new(0.8, 1.6)
                emitter.Speed = NumberRange.new(4, 9)
                emitter.SpreadAngle = Vector2.new(25, 25)
                emitter.EmissionDirection = Enum.NormalId.Top
                emitter.Acceleration = Vector3.new(0, 4, 0)
                emitter.LightEmission, emitter.LightInfluence = 1, 0
                emitter.Color = ColorSequence.new(def.color:Lerp(Color3.new(1, 1, 1), 0.3), def.color)
                emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
                emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
                emitter.Shape = Enum.ParticleEmitterShape.Box                   -- spread across the pad's whole top, not from its middle
                emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
                emitter.Parent = part
                local light = part:FindFirstChildOfClass("PointLight")
                local belt = MakeBelt(def, part)
                table.insert(pads, { def = def, part = part, emitter = emitter, light = light, baseBrightness = light and light.Brightness or 0, occupied = 0,
                    belt = belt, beltFill = 1, beltOffset = 0, beltSpeed = 0 })
            end
        end
    end
end

-- Which pad the character stands on (the same test as the server's pay-out)
local function PadUnder(root)
    for _, e in ipairs(pads) do
        if e.part.Parent then
            local rel = e.part.CFrame:PointToObjectSpace(root.Position)
            local half = e.part.Size / 2
            if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y > 0 and rel.Y < 9 then return e end
        end
    end
    return nil
end

local function RunTrack(char, hum)
    local track = tracks[char]
    if track then return track end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = hum.RigType == Enum.HumanoidRigType.R15 and RUN_R15 or RUN_R6
    track = animator:LoadAnimation(anim)
    track.Looped = true
    track.Priority = Enum.AnimationPriority.Action
    tracks[char] = track
    char.AncestryChanged:Connect(function(_, parent) if not parent then tracks[char] = nil end end)
    return track
end

local lastNow = os.clock()
local function Step(now)
    local dt = math.min(now - lastNow, 0.1)
    lastNow = now
    if now - lookedFor > 2 then lookedFor = now FindPads() end
    for _, e in ipairs(pads) do e.occupied, e.runners, e.runSpeed = 0, 0, 0 end
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then
            local pad = PadUnder(root)
            local v = root.AssemblyLinearVelocity
            local still = hum.MoveDirection.Magnitude < 0.1 and Vector3.new(v.X, 0, v.Z).Magnitude < 3
            local running = pad ~= nil and still and hum.FloorMaterial ~= Enum.Material.Air
            if pad then pad.occupied += 1 end
            if running then pad.runners += 1 pad.runSpeed = math.max(pad.runSpeed, hum.WalkSpeed) end
            if char:GetAttribute("OnPad") ~= running then char:SetAttribute("OnPad", running) end         -- (SpeedSparks also throws sparks while running on the spot)
            local track = tracks[char]
            if running then
                track = RunTrack(char, hum)
                if track then
                    local t = math.clamp((hum.WalkSpeed - SpeedData.BASE_WALK) / (SpeedData.PER_LEVEL * SpeedData.MAX_LEVEL), 0, 1)
                    track:AdjustSpeed(1 + 0.8 * t)
                    if not track.IsPlaying then track:Play(0.15) end
                end
            elseif track and track.IsPlaying then
                track:Stop(0.15)
            end
        end
    end
    for _, e in ipairs(pads) do
        local on = e.occupied > 0
        e.emitter.Enabled = on
        if on then e.emitter.Rate = 10 + 8 * math.min(e.occupied, 4) end
        -- the belt: fades in while someone runs on the spot, and its stripes slide at the runner's pace
        local belt = e.belt
        if belt then
            local target = e.runners > 0 and 0 or 1
            e.beltFill += (target - e.beltFill) * math.min(1, dt * 6)
            belt.group.GroupTransparency = e.beltFill
            if e.runners > 0 then
                e.beltSpeed = e.runSpeed * 24 * 0.6                              -- pixels per second (24 px per stud)
                belt.canvas.CFrame = e.part.CFrame * CFrame.new(0, e.part.Size.Y / 2 + 0.2, 0) * BELT_TURN
            end
            if e.beltFill < 0.99 then
                e.beltOffset = (e.beltOffset + e.beltSpeed * dt) % BAR_GAP
                for i, bar in ipairs(belt.bars) do
                    bar.Position = UDim2.fromOffset(0, (i - 1) * BAR_GAP - e.beltOffset)        -- (towards the front of the pad: the runner faces the info board)
                end
            end
        end
        if e.light then
            e.light.Brightness = on and e.baseBrightness * (1.5 + 0.9 * math.abs(math.sin(now * math.pi * BEAT_HZ))) or e.baseBrightness
        end
    end
end

function PadTreadmill.Init()
    RunService.Heartbeat:Connect(function() Step(os.clock()) end)
end

return PadTreadmill
