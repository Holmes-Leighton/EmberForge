-- Draws a material's mesh as a small icon (a ViewportFrame, turned three-quarters so it reads as an object).
--   MaterialIcon.Make(parent, materialId, size)  -> ViewportFrame, or nil when the material has no mesh yet
--   MaterialIcon.Overlay(tile, materialId)       -> puts the mesh on top of an existing lettered tile and clears its text;
--                                                   the tile stays as a coloured backdrop. Returns true when it did.
-- Meshes live in ReplicatedStorage.MaterialAssets (loaded by GolemAssetLoader). One mesh is cloned per icon, so keep lists modest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local MaterialIcon = {}

-- Every icon turns slowly on the spot. One shared loop (about 30 times a second) turns all the icons that are on screen.
local SPIN_SPEED = math.rad(50)          -- radians per second
local spinning = {}                      -- [viewport] = { model, centre, phase }
local acc = 0
local made = 0                        -- icons made so far: gives each one its own starting angle
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 1 / 30 then return end
    local step = acc
    acc = 0
    local now = os.clock()
    for vp, s in pairs(spinning) do
        if not vp.Parent or not s.model.Parent then
            spinning[vp] = nil
        else
            local gui = vp:FindFirstAncestorWhichIsA("LayerCollector")
            if gui and gui.Enabled and vp.Visible and vp.AbsoluteSize.X > 0 then
                s.model:PivotTo(CFrame.new(s.centre) * CFrame.Angles(0, s.phase + now * SPIN_SPEED, 0) * CFrame.new(-s.centre) * s.rest)
            end
        end
    end
end)

function MaterialIcon.Template(materialId)
    for _, name in ipairs({ "MaterialAssets", "IconAssets" }) do
        local folder = ReplicatedStorage:FindFirstChild(name)
        local found = folder and folder:FindFirstChild(materialId)
        if found then return found end
    end
    return nil
end

local function Fill(vp, template)
    local model = template:Clone()
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = true end
        if d:IsA("ParticleEmitter") or d:IsA("Light") then d.Enabled = false end
    end
    local _, size = model:GetBoundingBox()
    model.Parent = vp
    local rest = model:GetPivot()
    local cam = Instance.new("Camera")
    cam.FieldOfView = 30
    cam.Parent = vp
    vp.CurrentCamera = cam
    local centre = select(1, model:GetBoundingBox()).Position
    local reach = math.max(size.X, size.Y, size.Z) * 0.58
    local dist = reach / math.tan(math.rad(cam.FieldOfView / 2))
    local dir = CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(math.rad(-18), 0, 0)
    cam.CFrame = CFrame.lookAt(centre + dir:VectorToWorldSpace(Vector3.new(0, 0, -dist)), centre)
    made += 1
    spinning[vp] = { model = model, centre = centre, rest = rest, phase = (made * 1.7) % (math.pi * 2) }
end

function MaterialIcon.Make(parent, materialId, size)
    local template = MaterialIcon.Template(materialId)
    if not template then return nil end
    local vp = Instance.new("ViewportFrame")
    vp.Name = "MaterialMesh"
    vp.Size = UDim2.new(0, size or 32, 0, size or 32)
    vp.BackgroundTransparency = 1
    vp.LightColor = Color3.fromRGB(255, 250, 240)
    vp.Ambient = Color3.fromRGB(205, 198, 192)
    vp.Parent = parent
    Fill(vp, template)
    return vp
end

function MaterialIcon.Overlay(tile, materialId)
    local vp = MaterialIcon.Make(tile, materialId, 1)
    if not vp then return false end
    vp.Size = UDim2.new(1, 0, 1, 0)
    if tile:IsA("TextLabel") or tile:IsA("TextButton") then tile.Text = "" end
    tile.BackgroundTransparency = 0.55
    return true
end

return MaterialIcon
