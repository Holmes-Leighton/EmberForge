-- Draws a material's mesh as a small icon (a ViewportFrame, turned three-quarters so it reads as an object).
--   MaterialIcon.Make(parent, materialId, size)  -> ViewportFrame, or nil when the material has no mesh yet
--   MaterialIcon.Overlay(tile, materialId)       -> puts the mesh on top of an existing lettered tile and clears its text;
--                                                   the tile stays as a coloured backdrop. Returns true when it did.
-- Meshes live in ReplicatedStorage.MaterialAssets (loaded by GolemAssetLoader). One mesh is cloned per icon, so keep lists modest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MaterialIcon = {}

function MaterialIcon.Template(materialId)
    local folder = ReplicatedStorage:FindFirstChild("MaterialAssets")
    return folder and folder:FindFirstChild(materialId) or nil
end

local function Fill(vp, template)
    local model = template:Clone()
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = true end
        if d:IsA("ParticleEmitter") or d:IsA("Light") then d.Enabled = false end
    end
    local _, size = model:GetBoundingBox()
    model.Parent = vp
    local cam = Instance.new("Camera")
    cam.FieldOfView = 30
    cam.Parent = vp
    vp.CurrentCamera = cam
    local centre = select(1, model:GetBoundingBox()).Position
    local reach = math.max(size.X, size.Y, size.Z) * 0.5
    local dist = reach / math.tan(math.rad(cam.FieldOfView / 2))
    local dir = CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(math.rad(-18), 0, 0)
    cam.CFrame = CFrame.lookAt(centre + dir:VectorToWorldSpace(Vector3.new(0, 0, -dist)), centre)
end

function MaterialIcon.Make(parent, materialId, size)
    local template = MaterialIcon.Template(materialId)
    if not template then return nil end
    local vp = Instance.new("ViewportFrame")
    vp.Name = "MaterialMesh"
    vp.Size = UDim2.new(0, size or 32, 0, size or 32)
    vp.BackgroundTransparency = 1
    vp.LightColor = Color3.fromRGB(255, 244, 230)
    vp.Ambient = Color3.fromRGB(160, 150, 145)
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
