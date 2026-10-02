-- Animates the Golems standing in the world: pickaxe swing, Neon pulse and Mega Neon rainbow.
-- Runs on each client for models in workspace.EmberWorld.DeployedGolems. Golems far from the
-- camera are skipped (a simple level-of-detail) so phones stay smooth.
--
-- How a Golem moves depends on the model's "RigMode" attribute (set by GolemModel):
--   (none)   block Golem: arms and pickaxe are placed by formula
--   Parts    uploaded model with parts named ArmL / ArmR / PickHandle / PickHead: swung about their pivots
--   Static   uploaded single mesh: bobs and sways
--   Skinned  uploaded rigged model: plays its Mine (or Idle) animation, paused when far away

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local IdleMoves = require(game.ReplicatedStorage.Shared.Modules.IdleMoves)
local GolemWalk = require(game.ReplicatedStorage.Shared.Modules.GolemWalk)
local GolemMotion = require(game.ReplicatedStorage.Shared.Modules.GolemMotion)
local Players = game:GetService("Players")

local GolemAnimator = {}

local NEAR = 170            -- studs: animate fully
local SWING_SPEED = 4
local SWING_PERIOD = 1.9          -- seconds for one full mining swing at an element's normal pace (GolemMotion shapes it)

-- Each element works at its own pace (how fast the pick swings) and kicks up its own kind of dust when the pick lands
local ELEMENT_FEEL = {
    Ember = { tempo = 1.2,  dust = Color3.fromRGB(255, 150, 60) },
    Stone = { tempo = 0.8,  dust = Color3.fromRGB(150, 140, 125) },
    Frost = { tempo = 1.0,  dust = Color3.fromRGB(200, 235, 255) },
    Storm = { tempo = 1.3,  dust = Color3.fromRGB(200, 170, 255) },
    Void  = { tempo = 0.9,  dust = Color3.fromRGB(150, 90, 220) },
}
local DEFAULT_FEEL = { tempo = 1.0, dust = Color3.fromRGB(170, 150, 125) }

local golems = {}           -- model -> { parts... }
local spinners = {}         -- part -> { cf = original CFrame, speed = rad/s }  (forge gears)
local scenery = {}          -- Model or part -> { base = rest CFrame, kind, speed, amp, phase }  (biome art: see BiomeArt on the server)

local function LoadTrack(animator, model, attr, looped)
    local id = model:GetAttribute(attr)
    if not id then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then
        warn("[GolemAnimator] could not load " .. attr .. " (" .. tostring(id) .. "): " .. tostring(track))
        return nil
    end
    track.Looped = looped
    return track
end

local function FindAnimator(model)
    local existing = model:FindFirstChildWhichIsA("Animator", true)
    if existing then return existing end
    local host = model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true)
    if not host then
        host = Instance.new("AnimationController")
        host.Parent = model
    end
    local animator = Instance.new("Animator")
    animator.Parent = host
    return animator
end

-- where a part sits relative to the Golem's ground pose, so the swing can be applied on top of it
local function Rest(base, p)
    if not p then return nil end
    return { part = p, rel = base:ToObjectSpace(p.CFrame), pivot = base:ToObjectSpace(p:GetPivot()) }
end

-- A small durability bar under the owner tag: green, amber, red. It shows on your own Golems always, and on other players' Golems only once they are
-- nearly worn out (so visitors see why one is slumped). A worn-out Golem's bar says it needs repairing.
local function MakeBar(model)
    local head = model:FindFirstChild("Head", true)
    if not head then return nil end
    local gui = Instance.new("BillboardGui")
    gui.Name = "DurabilityBar"
    gui.Size = UDim2.new(0, 120, 0, 24)
    gui.StudsOffset = Vector3.new(0, 4.8, 0)
    gui.SizeOffset = Vector2.new(0, -2.6)                  -- just under the three-line owner tag
    gui.MaxDistance = 90
    gui.Adornee = head
    gui.Parent = head
    local back = Instance.new("Frame")
    back.Name = "Back"
    back.Size = UDim2.new(1, 0, 0, 10)
    back.BackgroundColor3 = Color3.fromRGB(24, 18, 16)
    back.BorderSizePixel = 0
    back.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = back
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Position = UDim2.new(0, 2, 0, 2)
    fill.Size = UDim2.new(1, -4, 1, -4)
    fill.BorderSizePixel = 0
    fill.Parent = back
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill
    local note = Instance.new("TextLabel")
    note.Name = "Note"
    note.Position = UDim2.new(0, 0, 0, 11)
    note.Size = UDim2.new(1, 0, 0, 13)
    note.BackgroundTransparency = 1
    note.Text = ""
    note.TextColor3 = Color3.fromRGB(255, 120, 100)
    note.TextStrokeTransparency = 0.3
    note.Font = Enum.Font.GothamBold
    note.TextSize = 12
    note.Parent = gui
    local function Refresh()
        local f = model:GetAttribute("Durability") or 1
        local mine = model:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
        gui.Enabled = mine or f <= GolemMotion.LOW
        fill.Size = UDim2.new(math.max(0.02, f), -4, 1, -4)
        fill.BackgroundColor3 = GolemMotion.BarColour(f)
        note.Text = f <= 0 and "NEEDS REPAIR" or (f <= GolemMotion.LOW and "Tired" or "")
    end
    model:GetAttributeChangedSignal("Durability"):Connect(Refresh)
    Refresh()
    return gui
end

local function Track(model)
    if golems[model] then return end
    local info = {
        mode = model:GetAttribute("RigMode"),
        variant = model:GetAttribute("Variant"),
        tinted = {},
    }
    local base = model:GetAttribute("Base")
    if info.mode == nil then
        info.armL = model:FindFirstChild("ArmL")
        info.armR = model:FindFirstChild("ArmR")
        info.handle = model:FindFirstChild("PickHandle")
        info.pickHead = model:FindFirstChild("PickHead")
    elseif info.mode == "Parts" and base then
        info.armL = Rest(base, model:FindFirstChild("ArmL", true))
        info.armR = Rest(base, model:FindFirstChild("ArmR", true))
        info.handle = Rest(base, model:FindFirstChild("PickHandle", true))
        info.pickHead = Rest(base, model:FindFirstChild("PickHead", true))
        info.head = Rest(base, model:FindFirstChild("Head", true))
        info.rest = base:ToObjectSpace(model:GetPivot())
        -- legs swing about the hip (the top of the leg) when the Golem walks; the one on the left of the body is side -1
        info.legs = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Name == "Leg" then
                local rel = base:ToObjectSpace(d.CFrame)
                table.insert(info.legs, { part = d, rel = rel, pivot = base:ToObjectSpace(d.CFrame * CFrame.new(0, d.Size.Y * 0.42, 0)), side = rel.X < 0 and -1 or 1 })
            end
        end
        local feel = ELEMENT_FEEL[model:GetAttribute("Element")] or DEFAULT_FEEL
        info.tempo = feel.tempo
        info.walkState = GolemWalk.New(math.floor((model:GetAttribute("Phase") or 0) * 1000) + 11)
        info.solid = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "PickHead" and d.Name ~= "PickHandle" then table.insert(info.solid, d) end      -- (the pick may rest on, or in, the ground; the body must not)
        end
        -- a puff of dust when the pick lands (the emitter sits on the pick head and is fired by the swing)
        local tip = model:FindFirstChild("PickHead", true)
        if tip and tip:IsA("BasePart") then
            local dust = Instance.new("ParticleEmitter")
            dust.Name = "StrikeDust"
            dust.Enabled = false
            dust.Color = ColorSequence.new(feel.dust)
            dust.Lifetime = NumberRange.new(0.5, 0.9)
            dust.Speed = NumberRange.new(4, 9)
            dust.SpreadAngle = Vector2.new(70, 70)
            dust.Size = NumberSequence.new(0.5, 1.4)
            dust.Transparency = NumberSequence.new(0.2, 1)
            dust.Acceleration = Vector3.new(0, -6, 0)
            dust.EmissionDirection = Enum.NormalId.Top
            dust.Parent = tip
            info.dust = dust
        end
        -- every few seconds a mining Golem stops to do one of four idle moves (look about, flex, stomp, inspect its pickaxe), in random order
        info.idle = IdleMoves.New("golem", math.floor((model:GetAttribute("Phase") or 0) * 1000) + 7, 6, 16)
    elseif info.mode == "Static" and base then
        info.rest = base:ToObjectSpace(model:GetPivot())
    elseif info.mode == "Skinned" then
        local phase = model:GetAttribute("Phase") or 0
        local animator = FindAnimator(model)
        info.track = LoadTrack(animator, model, "AnimMine", true) or LoadTrack(animator, model, "AnimIdle", true)
        if info.track then
            info.speed = 0.9 + (phase / (math.pi * 2)) * 0.2      -- so a row of Golems doesn't move in lockstep
            info.track:Play()
            info.track:AdjustSpeed(info.speed)
            info.playing = true
        end
    end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p:GetAttribute("Tint") then table.insert(info.tinted, { part = p, base = p.Color }) end
    end
    -- lights that dim as the Golem tires
    info.lights = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("PointLight") then table.insert(info.lights, { light = d, base = d.Brightness }) end
    end
    info.bar = MakeBar(model)
    golems[model] = info
end

local function Untrack(model) golems[model] = nil end

local function Step()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local t = os.clock()

    -- forge machinery
    for part, info in pairs(spinners) do
        if not part.Parent then
            spinners[part] = nil
        elseif (part.Position - camPos).Magnitude < NEAR * 1.5 then
            part.CFrame = info.cf * CFrame.Angles(t * info.speed, 0, 0)
        end
    end

    -- biome scenery: floating shards bob and turn, pines sway, crystal cores breathe (only when within range)
    for inst, s in pairs(scenery) do
        if not inst.Parent then
            scenery[inst] = nil
        else
            -- the rest pose is read the first time the piece is really here (with StreamingEnabled a Model can be tagged before its parts arrive,
            -- and a pose read too early would be the world origin)
            if not s.base then
                if inst:IsA("Model") then
                    if inst.PrimaryPart and inst.PrimaryPart:IsDescendantOf(inst) then s.base = inst:GetPivot() end
                else
                    s.base = inst.CFrame
                end
            end
            local pos = s.base and s.base.Position
            if pos and (pos - camPos).Magnitude < NEAR * 1.6 then
                local a = t * s.speed + s.phase
                if s.kind == "bob" then
                    inst:PivotTo(s.base * CFrame.new(0, math.sin(a) * s.amp, 0))
                elseif s.kind == "spin" then
                    inst:PivotTo(s.base * CFrame.Angles(0, a, 0))
                elseif s.kind == "bobspin" then
                    inst:PivotTo(s.base * CFrame.new(0, math.sin(a) * s.amp, 0) * CFrame.Angles(0, a * 0.6, 0))
                elseif s.kind == "sway" then
                    inst:PivotTo(s.base * CFrame.Angles(math.sin(a) * s.amp, 0, math.cos(a * 0.8) * s.amp * 0.7))
                elseif s.kind == "light" and inst:IsA("BasePart") then
                    local light = inst:FindFirstChildWhichIsA("PointLight")
                    if light then
                        s.baseBrightness = s.baseBrightness or light.Brightness
                        light.Brightness = s.baseBrightness * (1 + math.sin(a) * s.amp)
                    end
                elseif s.kind == "pulse" and inst:IsA("BasePart") then
                    inst.Transparency = 0.3 + math.sin(a) * s.amp
                    local light = inst:FindFirstChildWhichIsA("PointLight")
                    if light then light.Brightness = 1 + math.sin(a) * 0.5 end
                end
            end
        end
    end

    for model, info in pairs(golems) do
        if not model.Parent then
            golems[model] = nil
        else
            local base  = model:GetAttribute("Base")
            local scale = model:GetAttribute("Scale") or 1
            local phase = model:GetAttribute("Phase") or 0
            local near = base ~= nil and (base.Position - camPos).Magnitude < NEAR
            if info.track then
                if near ~= info.playing then                    -- pause the skeleton when far away (level of detail)
                    info.playing = near
                    info.track:AdjustSpeed(near and info.speed or 0)
                end
            end
            if near then
                local swing = math.sin(t * SWING_SPEED + phase) * 0.9 - 0.4
                if info.mode == nil then
                    if info.armL then
                        info.armL.CFrame = base * CFrame.new(-2.2 * scale, 6.5 * scale, 0)
                            * CFrame.Angles(-0.3 - swing * 0.3, 0, 0) * CFrame.new(0, -1.5 * scale, 0)
                    end
                    if info.armR then
                        info.armR.CFrame = base * CFrame.new(2.2 * scale, 6.5 * scale, 0)
                            * CFrame.Angles(swing - 0.8, 0, 0) * CFrame.new(0, -1.5 * scale, 0)
                        if info.handle then
                            local hand = info.armR.CFrame * CFrame.new(0, -1.4 * scale, -1.4 * scale)
                            info.handle.CFrame = hand
                            if info.pickHead then info.pickHead.CFrame = hand * CFrame.new(0, 0, -1.6 * scale) end
                        end
                    end
                elseif info.mode == "Parts" then
                    -- A Golem mines at its spot (GolemMotion: wind-up, hold, strike, bounce, recover), now and then walks a few steps to another spot
                    -- (GolemWalk), and moves like one body: the torso twists and leans into every strike, the head follows a beat behind, and on a walk
                    -- the weight shifts, the hips sway and each foot lifts. Every limb turns about its own pivot.
                    local tempo = info.tempo or 1
                    -- tiredness: slower swings, a sag, dimmer glow; at zero it stops where it stands and sits down
                    local fx = GolemMotion.Fatigue(model:GetAttribute("Durability") or 1)
                    for _, l in ipairs(info.lights or {}) do
                        if l.light.Parent then l.light.Brightness = l.base * fx.glow end
                    end
                    local ws = GolemWalk.Sample(info.walkState, t)
                    if fx.stopped then
                        info.frozen = info.frozen or { x = ws.x, z = ws.z, yaw = 0, walking = false, env = 0, stride = 0 }       -- stays exactly where it broke down
                        ws = info.frozen
                    else
                        info.frozen = nil
                    end
                    local walking = ws.walking
                    local dtm = math.min(0.1, t - (info.lastT or t))
                    info.lastT = t
                    -- sitting down and standing up are animated, not snapped: `sit` eases toward 1 when it breaks down and back to 0 when repaired
                    -- (about a second each way); the legs bend at the hips and the hips lower onto the ground
                    info.sit = (info.sit or 0) + ((fx.stopped and 1 or 0) - (info.sit or 0)) * math.min(1, dtm * 2.4)
                    if math.abs((fx.stopped and 1 or 0) - info.sit) < 0.004 then info.sit = fx.stopped and 1 or 0 end
                    local sit = info.sit
                    info.swingClock = (info.swingClock or (phase / (math.pi * 2))) + dtm * tempo * fx.tempo / SWING_PERIOD
                    local clock = info.swingClock
                    local cycle = math.floor(clock)
                    local u = clock - cycle
                    local r = GolemMotion.Raise(u)                                    -- 0 = pick on the ground, 1 = overhead
                    local drive = GolemMotion.Drive(u)                                -- -1 leaning back on the wind-up ... +1 driving forward at impact
                    local headR = GolemMotion.Lagged(u, 0.06)                         -- the head and shoulders follow a beat behind the arm
                    local rise = r * 1.2 * (1 - fx.slump * 0.55)                    -- the arm angle in radians while mining (a tired arm is raised less)
                    local stepT = t * GolemWalk.STRIDE_RATE
                    local stride = math.sin(stepT) * 0.4 * ws.env
                    local raise = rise + (0.55 - rise) * ws.env                      -- during a walk the pick arm hangs and swings a little
                    -- idle move (only while standing and mining): whole-body motion plus an arm pose blended over the mining swing
                    local move, mk = IdleMoves.Step(info.idle, t, not walking and not fx.stopped)
                    local ibob, ipitch, iroll, iyaw = IdleMoves.Body("golem", move, mk, t)
                    local w = move and math.sin(math.clamp(mk, 0, 1) * math.pi) or 0
                    w = math.min(1, w * 2.5)                                             -- quick in and out, holds in between
                    local zL, zR, xL, xR = 0, 0, 0.2 - raise * 0.25 + stride, raise - (walking and stride * 1.6 or 0)
                    if move == "flex" then zL, zR, xL, xR = -1.25 * w, 1.25 * w, xL + (0.4 - xL) * w, xR + (0.4 - xR) * w
                    elseif move == "stomp" or move == "look" then xL, xR = xL + (0.1 - xL) * w, xR + (0.1 - xR) * w
                    elseif move == "inspect" then xL, xR = xL + (0.1 - xL) * w, xR + (1.15 - xR) * w end
                    -- the whole body works with the arm: lean (negative pitch = forward) and twist into the strike, sway and shift weight on a walk
                    local mine = 1 - ws.env
                    local lean = -drive * 0.09 * mine * (1 - sit) - 0.05 * ws.env - fx.slump * 0.18 * (1 - sit) - sit * 0.1
                    local twist = drive * 0.1 * mine + math.cos(stepT) * 0.06 * ws.env
                    local roll = math.sin(stepT) * 0.05 * ws.env
                    local hipHeight = (info.legs and info.legs[1] and info.legs[1].pivot.Y) or 3
                    local settle = (r < 0.2 and (0.2 - r) * 0.5 or 0) * mine * (1 - sit) + fx.slump * 0.8 * (1 - sit) + sit * hipHeight       -- sinks as the pick lands, sags when tired, and lowers the hips to the ground when sitting
                    -- puff dust the moment the pick lands
                    if not walking and not fx.stopped then
                        local strike = cycle + (u >= GolemMotion.IMPACT and 1 or 0)
                        if info.lastStrike ~= nil and strike ~= info.lastStrike and info.dust then info.dust:Emit(8) end
                        info.lastStrike = strike
                    else
                        info.lastStrike = nil
                    end
                    local b = base * CFrame.new(ws.x, (ibob + GolemWalk.Bob(ws, t) - settle) * scale, ws.z)
                        * CFrame.Angles(ipitch + lean, iyaw + ws.yaw + twist, iroll + roll)
                    if info.rest then model:PivotTo(b * info.rest) end
                    if info.legs then
                        for _, l in ipairs(info.legs) do
                            local swing = GolemWalk.LegSwing(ws, t, l.side) * (1 - sit) + 1.5 * sit       -- seated: both legs bend forward at the hip
                            local legPhase = stepT + (l.side == 1 and 0 or math.pi)
                            local lift = walking and math.max(0, math.cos(legPhase)) * 0.3 * ws.env * scale or 0       -- the foot lifts as the leg swings forward
                            l.part.CFrame = b * CFrame.new(0, lift, 0) * l.pivot * CFrame.Angles(swing, 0, 0) * l.pivot:Inverse() * l.rel
                        end
                    end
                    if info.head then
                        local h = info.head
                        local nod = ((move == "inspect") and 0.35 * w or 0) + fx.slump * 0.3
                        nod = nod - (0.5 - headR) * 0.22 * mine                           -- a nod into each strike, a beat after the arm
                        local look = (move == "look" and math.sin(mk * math.pi * 3) * 0.7 * w or 0) - twist * 0.6       -- eyes stay forward as the torso twists
                        h.part.CFrame = b * h.pivot * CFrame.Angles(nod, look, 0) * h.pivot:Inverse() * h.rel
                    end
                    if info.armL then
                        local a = info.armL
                        a.part.CFrame = b * a.pivot * CFrame.Angles(xL, 0, zL) * a.pivot:Inverse() * a.rel
                    end
                    if info.armR then
                        local a = info.armR
                        local delta = b * a.pivot * CFrame.Angles(xR, 0, zR) * a.pivot:Inverse()
                        a.part.CFrame = delta * a.rel
                        if info.handle then info.handle.part.CFrame = delta * info.handle.rel end
                        if info.pickHead then info.pickHead.part.CFrame = delta * info.pickHead.rel end
                    end
                    if (fx.slump > 0 or sit > 0.001) and info.solid then
                        -- a tired Golem sags and a broken one sits: whatever the pose, lift it so no part is below the ground it stands on
                        local floorY = base.Position.Y
                        local lowest = math.huge
                        for _, d in ipairs(info.solid) do
                            local cf, sz = d.CFrame, d.Size
                            local _, _, _, _, _, _, r10, r11, r12 = cf:GetComponents()
                            local y = cf.Y - (math.abs(r10) * sz.X + math.abs(r11) * sz.Y + math.abs(r12) * sz.Z) / 2
                            if y < lowest then lowest = y end
                        end
                        if lowest < floorY then model:PivotTo(model:GetPivot() + Vector3.new(0, floorY - lowest + 0.02, 0)) end
                    end
                elseif info.mode == "Static" and info.rest then
                    local s = math.sin(t * SWING_SPEED * 0.5 + phase)
                    model:PivotTo(base * info.rest * CFrame.new(0, math.abs(s) * 0.5 * scale, 0)
                        * CFrame.Angles(0, s * 0.06, s * 0.05))
                end

                -- Neon glows softly; Mega Neon cycles through the rainbow
                if info.variant == "MegaNeon" then
                    local hue = (t * 0.25 + phase) % 1
                    for _, e in ipairs(info.tinted) do
                        if e.part.Material == Enum.Material.Neon then    -- only the glowing bits; textured bodies keep their art
                            e.part.Color = Color3.fromHSV(hue, 0.75, 1)
                        end
                    end
                elseif info.variant == "Neon" then
                    local pulse = 0.05 + 0.1 * (math.sin(t * 2 + phase) * 0.5 + 0.5)
                    for _, e in ipairs(info.tinted) do
                        if e.part.Material == Enum.Material.Neon then e.part.Transparency = pulse end
                    end
                end
            end
        end
    end
end

function GolemAnimator.Init()
    -- forge gears (tagged by the server, any number of plots)
    local function AddSpinner(part)
        if part:IsA("BasePart") then
            spinners[part] = { cf = part.CFrame, speed = part:GetAttribute("SpinSpeed") or 1 }
        end
    end
    for _, p in ipairs(CollectionService:GetTagged("EFSpin")) do AddSpinner(p) end
    CollectionService:GetInstanceAddedSignal("EFSpin"):Connect(AddSpinner)
    CollectionService:GetInstanceRemovedSignal("EFSpin"):Connect(function(p) spinners[p] = nil end)
    local function AddScenery(inst)
        if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
        local kind = inst:GetAttribute("AnimKind")
        if not kind then return end
        scenery[inst] = { base = nil, kind = kind, speed = inst:GetAttribute("AnimSpeed") or 1, amp = inst:GetAttribute("AnimAmp") or 0.5,
            phase = inst:GetAttribute("AnimPhase") or 0 }
    end
    for _, i in ipairs(CollectionService:GetTagged("EFAnim")) do AddScenery(i) end
    CollectionService:GetInstanceAddedSignal("EFAnim"):Connect(AddScenery)
    CollectionService:GetInstanceRemovedSignal("EFAnim"):Connect(function(i) scenery[i] = nil end)
    RunService.RenderStepped:Connect(Step)

    -- deployed Golems
    task.spawn(function()
        local world = workspace:WaitForChild("EmberWorld", 60)
        if not world then return end
        local folder = world:WaitForChild("DeployedGolems", 60)
        if not folder then return end
        for _, m in ipairs(folder:GetChildren()) do Track(m) end
        folder.ChildAdded:Connect(function(m) task.wait() Track(m) end)
        folder.ChildRemoved:Connect(Untrack)
    end)
end

return GolemAnimator
