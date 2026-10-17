-- Sparks from the feet of a player who has trained up their movement speed (SpeedData): the faster they walk, the more and the bigger the sparks, and the
-- hotter their colour (orange, then yellow, then white-blue). It follows each character's real WalkSpeed, so it is quiet in the Sky Tower (no bonus there) and
-- for anyone standing still. Drawn on every player's screen, so everyone sees everyone's sparks; players far from the camera are skipped.
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpeedData = require(game.ReplicatedStorage.Shared.Data.SpeedData)

local SpeedSparks = {}

local SHOW_RANGE   = 160       -- studs from the camera
local MIN_BONUS    = 0.5       -- studs/s of bonus before the first spark (a level or so)
local FULL_BONUS   = SpeedData.PER_LEVEL * SpeedData.MAX_LEVEL
local FOOT_NAMES   = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }

local rigs = {}                -- character -> { emitters = { ParticleEmitter }, t = last intensity }

local COLD = Color3.fromRGB(255, 120, 40)
local MID  = Color3.fromRGB(255, 220, 90)
local HOT  = Color3.fromRGB(190, 235, 255)

local function HeatColor(t)
    if t < 0.5 then return COLD:Lerp(MID, t * 2) end
    return MID:Lerp(HOT, (t - 0.5) * 2)
end

local function MakeEmitter(foot)
    local at = Instance.new("Attachment")
    at.Name = "SpeedSparkPoint"
    at.Position = Vector3.new(0, -foot.Size.Y / 2, 0)
    at.Parent = foot
    local e = Instance.new("ParticleEmitter")
    e.Name = "SpeedSparks"
    e.Rate = 0
    e.Lifetime = NumberRange.new(0.25, 0.5)
    e.Orientation = Enum.ParticleOrientation.VelocityParallel         -- each spark is a streak along its flight
    e.LightEmission, e.LightInfluence = 1, 0
    e.Acceleration = Vector3.new(0, -45, 0)
    e.EmissionDirection = Enum.NormalId.Top
    e.SpreadAngle = Vector2.new(35, 35)
    e.Drag = 1
    e.Enabled = false
    e.Parent = at
    return e
end

local function Build(char)
    local emitters = {}
    for _, name in ipairs(FOOT_NAMES) do
        local foot = char:FindFirstChild(name)
        if foot and foot:IsA("BasePart") then table.insert(emitters, MakeEmitter(foot)) end
    end
    if #emitters == 0 then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local e = MakeEmitter(root)
            e.Parent.Position = Vector3.new(0, -3, 0)
            table.insert(emitters, e)
        end
    end
    return { emitters = emitters, t = -1 }
end

local function Tune(rig, t, active)
    for _, e in ipairs(rig.emitters) do
        e.Enabled = active
        if active then
            e.Rate = 8 + 42 * t
            local size = 0.12 + 0.9 * t                                -- bigger sparks the faster they go
            e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
            e.Speed = NumberRange.new(6 + 14 * t, 10 + 20 * t)
            local c = HeatColor(t)
            e.Color = ColorSequence.new(c, c:Lerp(COLD, 0.6))
            e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
        end
    end
end

local function Step()
    local cam = workspace.CurrentCamera
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then
            local rig = rigs[char]
            if not rig then
                rig = Build(char)
                rigs[char] = rig
                char.AncestryChanged:Connect(function(_, parent) if not parent then rigs[char] = nil end end)
            end
            local bonus = math.max(0, hum.WalkSpeed - SpeedData.NORMAL_WALK)
            local v = root.AssemblyLinearVelocity
            local onPad = char:GetAttribute("OnPad") == true                -- running on the spot on a mining pad (PadTreadmill): a few sparks even at normal speed
            local running = (Vector3.new(v.X, 0, v.Z).Magnitude > 8 and hum.FloorMaterial ~= Enum.Material.Air) or onPad
            local near = cam == nil or (cam.CFrame.Position - root.Position).Magnitude <= SHOW_RANGE
            local active = (bonus >= MIN_BONUS or onPad) and running and near
            local t = math.clamp(bonus / FULL_BONUS, 0, 1)
            if onPad then t = math.max(t, 0.12) end
            if active ~= (rig.active or false) or (active and math.abs(t - rig.t) > 0.02) then      -- (only when something changed: building the sequences every frame is wasted work)
                Tune(rig, t, active)
                rig.active, rig.t = active, t
            end
        end
    end
end

function SpeedSparks.Init()
    RunService.Heartbeat:Connect(Step)
end

return SpeedSparks
