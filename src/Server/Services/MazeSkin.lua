-- Real meshes for the Hollow Maze (floor tiles, wall pieces, decorations, the coffin, the gate and the exit arch). They are generated models (AssetData.MazeMeshes ->
-- ServerStorage.MazeAssets, loaded by GolemAssetLoader). Like TowerSkin, a mesh is drawn on a part the rules already use, so the maze works as plain blocks if a mesh has not
-- loaded (or never does) and every wall still collides the same.
--   MazeSkin.Piece(name, size, cf, parent, hide, tint)   a stand-alone mesh part scaled to `size` at `cf`; each part in `hide` turns invisible once it is there.
--                                                        `size` may be a function(template) returning the size (to keep the mesh's own proportions).
--   MazeSkin.Refresh()                                   called once the assets have loaded: everything built before that picks its mesh up
--   MazeSkin.Has(name)                                   whether that mesh is loaded now
local ServerStorage = game:GetService("ServerStorage")

local MazeSkin = {}

local records = {}

local function Template(name)
    if not ServerStorage.FindFirstChild then return nil end              -- (the test environment's ServerStorage is a bare stub)
    local folder = ServerStorage:FindFirstChild("MazeAssets")
    local model = folder and folder:FindFirstChild(name)
    return model and (model:IsA("MeshPart") and model or model:FindFirstChildWhichIsA("MeshPart", true))
end

function MazeSkin.Has(name) return Template(name) ~= nil end

local function Skin(part, template, tint)
    local sm = Instance.new("SpecialMesh")
    sm.Name = "MazeMesh"
    sm.MeshType = Enum.MeshType.FileMesh
    sm.MeshId, sm.TextureId = template.MeshId, template.TextureID
    local native = template.MeshSize
    sm.Scale = Vector3.new(part.Size.X / math.max(native.X, 0.01), part.Size.Y / math.max(native.Y, 0.01), part.Size.Z / math.max(native.Z, 0.01))
    if tint then
        local c = tint:Lerp(Color3.new(1, 1, 1), 0.5)                    -- a gentle colour wash: the mesh keeps its own painted look
        sm.VertexColor = Vector3.new(c.R, c.G, c.B)
    end
    sm.Parent = part
end

local function Apply(rec)
    if rec.done then return end
    local template = Template(rec.name)
    if not template then return end
    if not rec.parent or not rec.parent.Parent then rec.done = true return end
    local part = Instance.new("Part")
    part.Name = rec.name .. "Mesh"
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
    part.Size, part.CFrame = (type(rec.size) == "function") and rec.size(template) or rec.size, rec.cf
    part.Parent = rec.parent
    Skin(part, template, rec.tint)
    for _, h in ipairs(rec.hide or {}) do if h.Parent then h.Transparency = 1 end end
    rec.done = true
end

function MazeSkin.Piece(name, size, cf, parent, hide, tint)
    local rec = { name = name, size = size, cf = cf, parent = parent, hide = hide, tint = tint }
    table.insert(records, rec)
    Apply(rec)
    return rec
end

function MazeSkin.Refresh()
    local keep = {}
    for _, rec in ipairs(records) do
        Apply(rec)
        if not rec.done then table.insert(keep, rec) end
    end
    records = keep
end

-- Forget the records of a maze that has been torn down (a new round builds a new one)
function MazeSkin.Clear() records = {} end

return MazeSkin
