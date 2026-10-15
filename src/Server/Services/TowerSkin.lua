-- Real meshes for the Sky Tower and the other obstacle courses (platforms, rest decks, crumbling and moving slabs, spinner bars, crushers, death tiles, bounce
-- pads, the rainbow gate rings, the scaffold girders and the clouds). They are generated models (AssetData.TowerMeshes -> ServerStorage.TowerAssets, loaded by
-- GolemAssetLoader).
--
-- The mesh is drawn by a SpecialMesh inside the part the rules already use, so it moves, spins and collides exactly like the plain block it replaces (the
-- server's movers, crumbling floors and spinners keep working untouched); a part with no mesh loaded simply stays a plain block.
--   TowerSkin.Fit(part, name, tint)                 turn an existing part into mesh `name`  (tint = a Color3 mixed into the mesh's own colours, optional)
--   TowerSkin.Piece(name, size, cf, parent, hide, tint)   a stand-alone mesh part; `hide` (parts) turn invisible once it is there (their block fallback)
--   TowerSkin.Refresh()                             called once the assets have loaded: everything built before that picks its mesh up
local ServerStorage = game:GetService("ServerStorage")

local TowerSkin = {}

local records = {}

local function Template(name)
    if not ServerStorage.FindFirstChild then return nil end              -- (the test environment's ServerStorage is a bare stub)
    local folder = ServerStorage:FindFirstChild("TowerAssets")
    local model = folder and folder:FindFirstChild(name)
    return model and (model:IsA("MeshPart") and model or model:FindFirstChildWhichIsA("MeshPart", true))
end

local function VertexTint(tint)
    if not tint then return Vector3.new(1, 1, 1) end
    local c = tint:Lerp(Color3.new(1, 1, 1), 0.5)                       -- a gentle colour wash: the mesh keeps its own painted look
    return Vector3.new(c.R, c.G, c.B)
end

local function Skin(part, template, tint)
    local sm = Instance.new("SpecialMesh")
    sm.Name = "TowerMesh"
    sm.MeshType = Enum.MeshType.FileMesh
    sm.MeshId, sm.TextureId = template.MeshId, template.TextureID
    local native = template.MeshSize
    sm.Scale = Vector3.new(part.Size.X / math.max(native.X, 0.01), part.Size.Y / math.max(native.Y, 0.01), part.Size.Z / math.max(native.Z, 0.01))
    sm.VertexColor = VertexTint(tint)
    sm.Parent = part
end

-- For a MOVING part whose mesh has its long axis along Z (the spinner bar, a girder): a MeshPart child turned a quarter turn and welded to the part, so it follows
-- every CFrame the client or server sets on it. The part itself turns invisible but keeps its collision.
local turnedFat
local function SkinTurned(part, template, tint)
    local mp = template:Clone()
    mp.Name = "TowerMesh"
    mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow, mp.Massless = false, false, false, false, false, true
    local fat = turnedFat or 1.7                                              -- a little chunkier than the hitbox so the bar reads from a distance
    mp.Size = Vector3.new(part.Size.Z * fat, part.Size.Y * fat, part.Size.X)
    mp.CFrame = part.CFrame * CFrame.Angles(0, math.pi / 2, 0)
    mp.Color = tint and tint:Lerp(Color3.new(1, 1, 1), 0.5) or mp.Color
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1 = part, mp
    weld.Parent = mp
    mp.Parent = part
    part.Transparency = 1
end

local function Apply(rec)
    if rec.done then return end
    local template = Template(rec.name)
    if not template then return end
    if rec.part then
        if not rec.part.Parent then rec.done = true return end
        if rec.turned then SkinTurned(rec.part, template, rec.tint) else Skin(rec.part, template, rec.tint) end
        rec.done = true
    else
        if not rec.parent or not rec.parent.Parent then rec.done = true return end
        local part = Instance.new("Part")
        part.Name = rec.name .. "Mesh"
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
        part.Transparency = 0
        part.Size, part.CFrame = rec.size, rec.cf
        part.Parent = rec.parent
        Skin(part, template, rec.tint)
        for _, h in ipairs(rec.hide or {}) do if h.Parent then h.Transparency = 1 end end
        rec.done = true
    end
end

function TowerSkin.Fit(part, name, tint, turned)
    local rec = { part = part, name = name, tint = tint, turned = turned }
    table.insert(records, rec)
    Apply(rec)
    return rec
end

function TowerSkin.Piece(name, size, cf, parent, hide, tint)
    local rec = { name = name, size = size, cf = cf, parent = parent, hide = hide, tint = tint }
    table.insert(records, rec)
    Apply(rec)
    return rec
end

function TowerSkin.Refresh()
    local keep = {}
    for _, rec in ipairs(records) do
        Apply(rec)
        if not rec.done then table.insert(keep, rec) end
    end
    records = keep
end

return TowerSkin
