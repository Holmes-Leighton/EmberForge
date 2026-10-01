-- Builds the 3D model for a pet. A pet with an uploaded model (ReplicatedStorage.PetAssets, loaded from
-- AssetData.PetPack) is that model, scaled to its size; otherwise a mini Golem of the same type stands in.
-- Returns model, feet, hover, rig: `feet` is how far the model's pivot sits above the floor (so callers can
-- stand it on the ground), `hover` is how far it floats above that, and `rig` (PetRig) animates a segmented pet's limbs
-- (nil for a one-piece pet or the mini-Golem stand-in).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GolemModel = require(script.Parent.GolemModel)
local CrownModel = require(script.Parent.CrownModel)
local Theme      = require(script.Parent.Theme)
local PetData    = require(script.Parent.Parent.Data.PetData)
local PetRig     = require(script.Parent.PetRig)

local PetModel = {}

local DEFAULT_SIZE = 2.6

function PetModel.Template(petType)
    local folder = ReplicatedStorage:FindFirstChild("PetAssets")
    return folder and folder:FindFirstChild(petType) or nil
end

-- Bumps whenever a pet model finishes loading, so callers can rebuild stand-ins
function PetModel.AssetVersion()
    local folder = ReplicatedStorage:FindFirstChild("PetAssets")
    return (folder and folder:GetAttribute("Version") or 0) + CrownModel.AssetVersion() * 1000   -- crowns loading also rebuild pets
end

function PetModel.Build(petType, variant)
    local look = PetData.Looks[petType] or {}
    local size = (look.size or DEFAULT_SIZE) * (variant == "MegaNeon" and 1.18 or (variant == "Neon" and 1.08 or 1))   -- Elite / Supreme are bigger
    local model, rig
    local template = PetModel.Template(petType)
    if template then
        model = template:Clone()
        -- The uploaded pet's front is on its -Z side, but its pivot (the "Body" part) is turned 180 degrees, so PivotTo(yaw)
        -- used to face it backwards. Turn the pivot (not the parts) so a pivot with no turn means "front toward -Z",
        -- which is what PetController assumes.
        -- (the segmented pet pack is already built facing -Z and is tagged "Rigged", so only the old one-piece pack needs this)
        local body = model.PrimaryPart
        if body and not model:GetAttribute("Rigged") then body.PivotOffset = body.PivotOffset * CFrame.Angles(0, math.pi, 0) end
        local height = model:GetExtentsSize().Y
        if height > 0.05 then model:ScaleTo(model:GetScale() * size / height) end
        if model:GetAttribute("Rigged") then rig = PetRig.Build(model) end
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
    -- Elite / Supreme: the pet keeps its own model and gains status gear (internal ids "Neon" / "MegaNeon").
    -- Elite: a gold crown and a gold chest pendant with a gem in the pet's colour (and a little bigger).
    -- Supreme: adds a halo, a tiny royal cape, wings of light and orbiting gems (and is bigger still).
    -- Gems carry the "Tint" attribute: they pulse on an Elite and cycle the rainbow on a Supreme.
    if variant and PetData.Variants[variant] then
        local supreme = variant == "MegaNeon"
        local gold = Color3.fromRGB(255, 205, 90)
        local gem = Theme.Colors[petType] or Color3.fromRGB(255, 200, 120)
        if math.max(gem.R, gem.G, gem.B) > 0.8 then gem = gem:Lerp(Color3.fromRGB(200, 140, 60), 0.55) end   -- pale types would wash out
        local centre, bs = model:GetBoundingBox()
        local function gear(name, size, cf, colour, material, transparency, tint, shape)
            local p = Instance.new("Part")
            p.Name, p.Size, p.CFrame = name, size, cf
            p.Color, p.Material, p.Transparency = colour, material, transparency or 0
            p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
            if shape then p.Shape = shape end
            if tint then p:SetAttribute("Tint", true) end
            p.Parent = model
            return p
        end
        local cx, cz = centre.Position.X, centre.Position.Z
        local top = centre.Position.Y + bs.Y / 2
        local front, back = cz - bs.Z / 2, cz + bs.Z / 2
        local w = math.max(bs.X, bs.Z) * 0.6

        -- this type's own crown (a unique mesh per type); a plain gold crown if it has none yet
        local crownH = CrownModel.Attach(model, petType, math.max(bs.X, bs.Z) * (supreme and 0.85 or 0.7), CFrame.new(cx, top - 0.05, cz))
        if not crownH then
            gear("CrownBand", Vector3.new(w, 0.14, w), CFrame.new(cx, top + 0.04, cz), gold, Enum.Material.Metal)
            for i = 0, 4 do
                local a = i / 5 * math.pi * 2
                gear("CrownPoint", Vector3.new(0.14, 0.4, 0.14), CFrame.new(cx + math.cos(a) * w * 0.4, top + 0.25, cz + math.sin(a) * w * 0.4), gold, Enum.Material.Metal)
            end
            gear("CrownGem", Vector3.new(0.22, 0.22, 0.22), CFrame.new(cx, top + 0.18, front + w * 0.3), gem, Enum.Material.Neon, 0.1, true, Enum.PartType.Ball)
        end
        gear("Pendant", Vector3.new(0.4, 0.4, 0.08), CFrame.new(cx, centre.Position.Y, front - 0.03) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Metal, 0, nil, Enum.PartType.Cylinder)
        gear("PendantGem", Vector3.new(0.22, 0.22, 0.22), CFrame.new(cx, centre.Position.Y, front - 0.1), gem, Enum.Material.Neon, 0.1, true, Enum.PartType.Ball)

        if supreme then
            gear("Halo", Vector3.new(0.08, w * 1.5, w * 1.5), CFrame.new(cx, top + (crownH or 0.4) + 0.45, cz) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Neon, 0.15, nil, Enum.PartType.Cylinder)
            gear("Cape", Vector3.new(bs.X * 0.75, bs.Y * 0.6, 0.08), CFrame.new(cx, centre.Position.Y, back + 0.1) * CFrame.Angles(0.12, 0, 0), Color3.fromRGB(170, 35, 55), Enum.Material.Fabric)
            gear("CapeTrim", Vector3.new(bs.X * 0.8, 0.1, 0.12), CFrame.new(cx, centre.Position.Y + bs.Y * 0.3, back + 0.1), gold, Enum.Material.Metal)
            for _, side in ipairs({ -1, 1 }) do
                for i = 0, 1 do
                    gear("Wing", Vector3.new(0.05, bs.Y * (0.7 - i * 0.2), bs.X * 0.3), CFrame.new(cx + side * (bs.X * 0.5 + i * bs.X * 0.25), centre.Position.Y + bs.Y * 0.1, back + 0.3)
                        * CFrame.Angles(0, side * (0.5 + 0.2 * i), side * -0.4), gem:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon, 0.35)
                end
            end
            for i = 1, 2 do
                local a = i * math.pi + 0.6
                gear("OrbitGem", Vector3.new(0.2, 0.3, 0.2), CFrame.new(cx + math.cos(a) * bs.X * 0.9, centre.Position.Y + bs.Y * 0.2, cz + math.sin(a) * bs.Z * 0.9)
                    * CFrame.Angles(i, i * 0.6, 0), gem, Enum.Material.Neon, 0.1, true)
            end
            gear("GoldPad", Vector3.new(0.06, math.max(bs.X, bs.Z) * 1.7, math.max(bs.X, bs.Z) * 1.7),
                CFrame.new(cx, centre.Position.Y - bs.Y / 2 + 0.04, cz) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Neon, 0.6, nil, Enum.PartType.Cylinder)
        end

        local sparkles = Instance.new("ParticleEmitter")
        sparkles.Color = ColorSequence.new(supreme and gold or gem)
        sparkles.Rate = supreme and 12 or 5
        sparkles.Lifetime = NumberRange.new(0.8, 1.4)
        sparkles.Speed = NumberRange.new(1, 2.5)
        sparkles.EmissionDirection = Enum.NormalId.Top
        sparkles.LightEmission = 1
        sparkles.Size = NumberSequence.new(0.25, 0)
        sparkles.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        local glow = Instance.new("PointLight")
        glow.Color = supreme and gold or gem
        glow.Range = supreme and 10 or 7
        glow.Brightness = supreme and 1.6 or 1.0
        glow.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        model:SetAttribute("Variant", variant)
    end
    local box, bsize = model:GetBoundingBox()
    local feet = model:GetPivot().Position.Y - (box.Position.Y - bsize.Y / 2)
    return model, feet, look.hover or 0, rig
end

return PetModel
