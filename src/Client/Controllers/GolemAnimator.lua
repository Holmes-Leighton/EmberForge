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

local GolemAnimator = {}

local NEAR = 170            -- studs: animate fully
local SWING_SPEED = 4

local golems = {}           -- model -> { parts... }
local spinners = {}         -- part -> { cf = original CFrame, speed = rad/s }  (forge gears)

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
                    -- Rotate each arm about its own pivot (the shoulder). Positive angle raises the arm forward.
                    local raise = 0.6 + math.sin(t * SWING_SPEED + phase) * 0.6
                    if info.armL then
                        local a = info.armL
                        a.part.CFrame = base * a.pivot * CFrame.Angles(0.2 - raise * 0.25, 0, 0) * a.pivot:Inverse() * a.rel
                    end
                    if info.armR then
                        local a = info.armR
                        local delta = base * a.pivot * CFrame.Angles(raise, 0, 0) * a.pivot:Inverse()
                        a.part.CFrame = delta * a.rel
                        if info.handle then info.handle.part.CFrame = delta * info.handle.rel end
                        if info.pickHead then info.pickHead.part.CFrame = delta * info.pickHead.rel end
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
