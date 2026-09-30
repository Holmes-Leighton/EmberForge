-- Animates the Golems standing in the world: pickaxe swing, Neon pulse and Mega Neon rainbow.
-- Runs on each client for models in workspace.EmberWorld.DeployedGolems. Golems far from the
-- camera are skipped (a simple level-of-detail) so phones stay smooth.

local RunService = game:GetService("RunService")

local GolemAnimator = {}

local NEAR = 170            -- studs: animate fully
local SWING_SPEED = 4

local golems = {}           -- model -> { parts... }

local function Track(model)
    if golems[model] then return end
    local info = {
        armL = model:FindFirstChild("ArmL"), armR = model:FindFirstChild("ArmR"),
        handle = model:FindFirstChild("PickHandle"), pickHead = model:FindFirstChild("PickHead"),
        variant = model:GetAttribute("Variant"),
        tinted = {},
    }
    for _, p in ipairs(model:GetChildren()) do
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

    for model, info in pairs(golems) do
        if not model.Parent then
            golems[model] = nil
        else
            local base  = model:GetAttribute("Base")
            local scale = model:GetAttribute("Scale") or 1
            local phase = model:GetAttribute("Phase") or 0
            if base and (base.Position - camPos).Magnitude < NEAR then
                local swing = math.sin(t * SWING_SPEED + phase) * 0.9 - 0.4
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

                -- Neon glows softly; Mega Neon cycles through the rainbow
                if info.variant == "MegaNeon" then
                    local hue = (t * 0.25 + phase) % 1
                    for _, e in ipairs(info.tinted) do
                        e.part.Color = Color3.fromHSV(hue, 0.75, 1)
                    end
                elseif info.variant == "Neon" then
                    local pulse = 0.05 + 0.1 * (math.sin(t * 2 + phase) * 0.5 + 0.5)
                    for _, e in ipairs(info.tinted) do e.part.Transparency = pulse end
                end
            end
        end
    end
end

function GolemAnimator.Init()
    task.spawn(function()
        local world = workspace:WaitForChild("EmberWorld", 60)
        if not world then return end
        local folder = world:WaitForChild("DeployedGolems", 60)
        if not folder then return end
        for _, m in ipairs(folder:GetChildren()) do Track(m) end
        folder.ChildAdded:Connect(function(m) task.wait() Track(m) end)
        folder.ChildRemoved:Connect(Untrack)
        RunService.RenderStepped:Connect(Step)
    end)
end

return GolemAnimator
