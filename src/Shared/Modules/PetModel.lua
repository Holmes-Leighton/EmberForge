-- Builds the 3D model for a pet. A pet with an uploaded model (ReplicatedStorage.PetAssets, loaded from
-- AssetData.PetPack) is that model, scaled to its size; otherwise a mini Golem of the same type stands in.
-- Returns model, feet, hover: `feet` is how far the model's pivot sits above the floor (so callers can
-- stand it on the ground) and `hover` is how far it floats above that.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GolemModel = require(script.Parent.GolemModel)
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

function PetModel.Build(petType)
    local look = PetData.Looks[petType] or {}
    local size = look.size or DEFAULT_SIZE
    local model
    local template = PetModel.Template(petType)
    if template then
        model = template:Clone()
        local height = model:GetExtentsSize().Y
        if height > 0.05 then model:ScaleTo(model:GetScale() * size / height) end
    else
        local ok, m = pcall(GolemModel.Build, petType, 1, {})
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
    local box, bsize = model:GetBoundingBox()
    local feet = model:GetPivot().Position.Y - (box.Position.Y - bsize.Y / 2)
    return model, feet, look.hover or 0
end

return PetModel
