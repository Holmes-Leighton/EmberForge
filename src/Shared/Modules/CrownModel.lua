-- Puts a type's unique Elite/Supreme crown on a head. Crown models live in ReplicatedStorage.CrownAssets
-- (loaded from AssetData.CrownPack), one per Golem/pet type, each a single mesh whose pivot is the centre of
-- its base. Returns the crown's height, or nil when that type has no crown model (the caller then builds a
-- plain circlet instead).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrownModel = {}

function CrownModel.Has(crownType)
    local folder = ReplicatedStorage:FindFirstChild("CrownAssets")
    return folder ~= nil and folder:FindFirstChild(crownType) ~= nil
end

-- Bumps whenever a crown finishes loading, so callers can rebuild stand-ins
function CrownModel.AssetVersion()
    local folder = ReplicatedStorage:FindFirstChild("CrownAssets")
    return folder and folder:GetAttribute("Version") or 0
end

-- `width` = how wide the crown should be in studs; `baseCFrame` = where the centre of its base sits.
function CrownModel.Attach(target, crownType, width, baseCFrame)
    local folder = ReplicatedStorage:FindFirstChild("CrownAssets")
    local template = folder and folder:FindFirstChild(crownType)
    if not template then return nil end
    local crown = template:Clone()
    local ext = crown:GetExtentsSize()
    local widest = math.max(ext.X, ext.Z)
    if widest < 0.05 then crown:Destroy() return nil end
    crown:ScaleTo(crown:GetScale() * width / widest)
    crown:PivotTo(baseCFrame)
    local height = crown:GetExtentsSize().Y
    for _, d in ipairs(crown:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
            d.Name = "Crown_" .. d.Name
            d.Parent = target
        end
    end
    crown:Destroy()
    return height
end

return CrownModel
