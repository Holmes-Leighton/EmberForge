-- Builds the 3D model for a pet. A pet with an uploaded model (ReplicatedStorage.PetAssets, loaded from
-- AssetData.PetPack) is that model, scaled to its size; otherwise a mini Golem of the same type stands in.
-- Returns model, feet, hover: `feet` is how far the model's pivot sits above the floor (so callers can
-- stand it on the ground) and `hover` is how far it floats above that.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GolemModel = require(script.Parent.GolemModel)
local Theme      = require(script.Parent.Theme)
local PetData    = require(script.Parent.Parent.Data.PetData)

local PetModel = {}

local DEFAULT_SIZE = 2.6

function PetModel.Template(petType)
    local folder = ReplicatedStorage:FindFirstChild("PetAssets")
    return folder and folder:FindFirstChild(petType) or nil
end

-- Bumps whenever a pet model finishes loading, so callers can rebuild stand-ins
function PetModel.AssetVersion()
    local folder = ReplicatedStorage:FindFirstChild("PetAssets")
    return folder and folder:GetAttribute("Version") or 0
end

function PetModel.Build(petType, variant)
    local look = PetData.Looks[petType] or {}
    local size = look.size or DEFAULT_SIZE
    local model
    local template = PetModel.Template(petType)
    if template then
        model = template:Clone()
        local height = model:GetExtentsSize().Y
        if height > 0.05 then model:ScaleTo(model:GetScale() * size / height) end
    else
        local ok, m = pcall(GolemModel.Build, petType, 1, { variant = variant })
        if not ok or not m then return nil end
        model = m
        model:ScaleTo(model:GetScale() * 0.2)            -- a fifth of a Golem
    end
    model.Name = "Pet_" .. petType
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
        elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("SpotLight") then
            d.Enabled = false                            -- keep a crowd of pets cheap
        end
    end
    -- Neon / Mega Neon: a flat glowing body in the pet's colour (a MeshPart ignores Color while it has a
    -- texture, so the texture goes). Mega Neon parts are tagged "Tint" so the controller can cycle the colour.
    if variant and PetData.Variants[variant] then
        local mega = variant == "MegaNeon"
        local colour = Theme.Colors[petType] or Color3.fromRGB(255, 200, 120)
        if math.max(colour.R, colour.G, colour.B) > 0.8 then colour = colour:Lerp(Color3.fromRGB(200, 140, 60), 0.55) end   -- pale types would wash out
        if mega then colour = Color3.fromRGB(255, 140, 220) end
        local centre, bs = model:GetBoundingBox()
        local function glowPart(name, size, cf, transparency, tint, shape)
            local p = Instance.new("Part")
            p.Name, p.Size, p.CFrame = name, size, cf
            p.Color, p.Material, p.Transparency = colour, Enum.Material.Neon, transparency
            p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
            if shape then p.Shape = shape end
            if tint then p:SetAttribute("Tint", true) end      -- Mega Neon: the controller cycles these through the rainbow
            p.Parent = model
            return p
        end
        -- a small glowing crown floating over its head
        local topY = centre.Position.Y + bs.Y / 2 + (mega and 0.55 or 0.4)
        local w = math.max(bs.X, bs.Z) * (mega and 0.7 or 0.55)
        glowPart("NeonCrownBand", Vector3.new(w, 0.16, w), CFrame.new(centre.Position.X, topY, centre.Position.Z), 0.1, true)
        for i = 0, (mega and 6 or 4) do
            local a = i / (mega and 7 or 5) * math.pi * 2
            glowPart("NeonCrownPoint", Vector3.new(0.16, mega and 0.6 or 0.45, 0.16),
                CFrame.new(centre.Position.X + math.cos(a) * w * 0.4, topY + 0.3, centre.Position.Z + math.sin(a) * w * 0.4), 0.1, true)
        end
        -- a glowing pad under it and rising sparkles
        local padSize = math.max(bs.X, bs.Z) * 1.7
        glowPart("NeonPad", Vector3.new(0.1, padSize, padSize),
            CFrame.new(centre.Position.X, centre.Position.Y - bs.Y / 2 + 0.04, centre.Position.Z) * CFrame.Angles(0, 0, math.pi / 2), 0.55, mega, Enum.PartType.Cylinder)
        local sparkles = Instance.new("ParticleEmitter")
        sparkles.Color = mega and ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 200)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 140, 255)),
        }) or ColorSequence.new(colour)
        sparkles.Rate = mega and 12 or 6
        sparkles.Lifetime = NumberRange.new(0.8, 1.4)
        sparkles.Speed = NumberRange.new(1, 2.5)
        sparkles.EmissionDirection = Enum.NormalId.Top
        sparkles.LightEmission = 1
        sparkles.Size = NumberSequence.new(0.25, 0)
        sparkles.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        local glow = Instance.new("PointLight")
        glow.Color = colour
        glow.Range = mega and 10 or 7
        glow.Brightness = mega and 1.6 or 1.0
        glow.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        model:SetAttribute("Variant", variant)
    end
    local box, bsize = model:GetBoundingBox()
    local feet = model:GetPivot().Position.Y - (box.Position.Y - bsize.Y / 2)
    return model, feet, look.hover or 0
end

return PetModel
