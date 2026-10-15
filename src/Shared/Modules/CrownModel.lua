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
    local acc = ReplicatedStorage:FindFirstChild("AccessoryAssets")
    return (folder and folder:GetAttribute("Version") or 0) + (acc and acc:GetAttribute("Version") or 0)
end

-- A Golem accessory mesh (ReplicatedStorage.AccessoryAssets.<Name>, see AssetData.GolemAccessoryMeshes) on a head: `width` studs wide, standing on `baseCFrame`
-- (centre of its base). Returns its height, or nil when that accessory has no mesh (the caller builds the block version).
function CrownModel.AttachAccessory(target, name, width, baseCFrame)
    local folder = ReplicatedStorage:FindFirstChild("AccessoryAssets")
    local template = folder and folder:FindFirstChild(name)
    if not template then return nil end
    local piece = template:Clone()
    local ext = piece:GetExtentsSize()
    local widest = math.max(ext.X, ext.Z)
    if widest < 0.05 then piece:Destroy() return nil end
    piece:ScaleTo(piece:GetScale() * width / widest)
    local height = piece:GetExtentsSize().Y
    piece:PivotTo(baseCFrame * CFrame.new(0, height / 2, 0))             -- generated meshes pivot on their centre
    for _, d in ipairs(piece:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
            d.Name = "Accessory_" .. d.Name
            d.Parent = target
        end
    end
    piece:Destroy()
    return height
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
