-- Brings every player's Quarry to life. The server draws the pieces (anchored meshes, lights, particle emitters); this moves
-- their separate parts every frame, so it costs the server nothing:
--   Core            the crystal heart floats and turns, the gold ring spins and tilts, the glow breathes
--   Drill Rig       the drill spins and bobs, the arm sways, dust kicks up
--   Sky Spire       the orb bobs, and its light flickers with lightning
--   Cooling Pool    the water ripples
--   Nodes / Prism   the glow pulses (the Prism Cluster's light cycles through the rainbow)
-- Pieces farther than NEAR studs from the camera are left alone.

local RunService = game:GetService("RunService")

local QuarryAnimator = {}

local NEAR = 140
local pieces = {}          -- model -> { id, parts = { name = { part, rest } }, lights = {...}, phase }

local function Track(model)
    if pieces[model] then return end
    local id = model:GetAttribute("PieceId")
    if not id then return end
    local info = { id = id, parts = {}, phase = (model:GetPivot().Position.X * 0.37 + model:GetPivot().Position.Z * 0.21) % 6.28 }
    for _, p in ipairs(model:GetChildren()) do
        if p:IsA("BasePart") then info.parts[p.Name] = { part = p, rest = p.CFrame } end
    end
    info.light = model:FindFirstChildWhichIsA("PointLight", true)
    pieces[model] = info
end

local function Rot(rest, axisAngleY, tiltX, tiltZ)
    -- rotate a part about its own centre, keeping it where it is
    return rest * CFrame.Angles(tiltX or 0, axisAngleY or 0, tiltZ or 0)
end

local function Step()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local t = os.clock()
    for model, info in pairs(pieces) do
        if not model.Parent then
            pieces[model] = nil
        elseif (model:GetPivot().Position - camPos).Magnitude < NEAR then
            local id, ph, P = info.id, info.phase, info.parts
            if id == "Core" then
                if P.Crystal then P.Crystal.part.CFrame = Rot(P.Crystal.rest, t * 0.7, 0, 0) + Vector3.new(0, math.sin(t * 1.6 + ph) * 0.18, 0) end
                if P.Ring then P.Ring.part.CFrame = Rot(P.Ring.rest, t * 1.3, math.sin(t * 0.9) * 0.35, math.cos(t * 0.7) * 0.3) + Vector3.new(0, math.sin(t * 1.6 + ph) * 0.18, 0) end
                if info.light then info.light.Brightness = 1.4 + math.sin(t * 2 + ph) * 0.5 end
            elseif id == "DrillRig" then
                if P.Drill then P.Drill.part.CFrame = Rot(P.Drill.rest, t * 9, 0, 0) + Vector3.new(0, -math.abs(math.sin(t * 1.4 + ph)) * 0.25, 0) end
                if P.Arm then P.Arm.part.CFrame = Rot(P.Arm.rest, 0, 0, math.sin(t * 1.4 + ph) * 0.05) end
            elseif id == "SkySpire" then
                local bob = math.sin(t * 2.2 + ph) * 0.2
                if P.Orb then P.Orb.part.CFrame = Rot(P.Orb.rest, t * 1.5, 0, 0) + Vector3.new(0, bob, 0) end
                if info.light then
                    local strike = math.max(0, math.sin(t * 3.1 + ph)) ^ 20 + math.max(0, math.sin(t * 7.3 + ph * 2)) ^ 30      -- sudden flashes
                    info.light.Brightness = 1.2 + strike * 5
                end
            elseif id == "CoolingPool" then
                if P.Water then P.Water.part.CFrame = P.Water.rest * CFrame.new(0, math.sin(t * 2.4 + ph) * 0.05, 0) * CFrame.Angles(math.sin(t * 1.7) * 0.012, 0, math.cos(t * 1.3) * 0.012) end
            elseif id == "PrismCluster" then
                if info.light then info.light.Color = Color3.fromHSV((t * 0.2 + ph) % 1, 0.6, 1) info.light.Brightness = 1.3 + math.sin(t * 2 + ph) * 0.4 end
            elseif info.light then
                info.light.Brightness = 1.2 + math.sin(t * 1.7 + ph) * 0.5            -- nodes breathe
            end
        end
    end
end

function QuarryAnimator.Init()
    task.spawn(function()
        local folder = workspace:WaitForChild("ForgeZones", 60)
        if not folder then return end
        local function Scan(q)
            if not q.Name:match("^Quarry_") then return end
            for _, m in ipairs(q:GetChildren()) do if m:IsA("Model") then Track(m) end end
            q.ChildAdded:Connect(function(m) task.wait() if m:IsA("Model") then Track(m) end end)
        end
        for _, c in ipairs(folder:GetChildren()) do Scan(c) end
        folder.ChildAdded:Connect(function(c) task.wait() Scan(c) end)
    end)
    RunService.RenderStepped:Connect(Step)
end

return QuarryAnimator
