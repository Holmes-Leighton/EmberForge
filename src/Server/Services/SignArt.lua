-- Real-mesh frames and posts for the world's text boards and signs. The lettering stays where it always was (a SurfaceGui on the board's own panel part), so the
-- text keeps working; a generated frame mesh is fitted around that panel and a generated post replaces each plain post. The plain parts stay as the solid
-- colliders and as the fallback: if a mesh has not loaded (or fails to), the board looks exactly as it did before.
--
--   SignArt.Frame(kind, panel)   kind "Notice" (a big notice board) or "Plank" (a wide plank sign); `panel` is the part that carries the lettering
--   SignArt.Post(post)           `post` is a plain upright post part; the mesh post stands in its place and the part turns invisible
--   SignArt.Refresh()            called once the SignAssets set has loaded: builds every frame / post that was waiting for it
-- Meshes: AssetData.SignMeshes -> ServerStorage.SignAssets (see GolemAssetLoader).

local ServerStorage = game:GetService("ServerStorage")

local SignArt = {}

local records = {}          -- { kind, panel / post, art }
local FRAME_NAMES = { Notice = "NoticeFrame", Plank = "PlankFrame" }

local function Template(name)
    if not ServerStorage.FindFirstChild then return nil end        -- (the test environment's ServerStorage is a bare stub)
    local folder = ServerStorage:FindFirstChild("SignAssets")
    return folder and folder:FindFirstChild(name)
end

-- Fit a cloned template to `size` (a single mesh is stretched to it; a multi-part model is scaled to the tallest side) and pose it at `cf`
local function Place(template, size, cf, name)
    local m = template:Clone()
    local meshes = {}
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
            if d:IsA("MeshPart") then table.insert(meshes, d) end
        end
    end
    if #meshes == 1 and m == meshes[1] then
        m.Size = size
    elseif #meshes == 1 then
        meshes[1].Size = size
    else
        local ext = m:GetExtentsSize()
        m:ScaleTo(m:GetScale() * size.Y / math.max(ext.Y, 0.01))
    end
    m.Name = name
    m:PivotTo(cf)
    return m
end

local function BuildFrame(rec)
    local panel = rec.panel
    if rec.art or not panel or not panel.Parent then return end
    local template = Template(FRAME_NAMES[rec.kind])
    if not template then return end
    local s = panel.Size
    -- the panel's thin side is the board's thickness; its normal axis tells where the lettering faces
    local thin = (s.X <= s.Y and s.X <= s.Z) and "X" or "Z"
    local long, tall, thick = (thin == "X") and s.Z or s.X, s.Y, (thin == "X") and s.X or s.Z
    local rot = (thin == "X") and CFrame.Angles(0, math.pi / 2, 0) or CFrame.new()
    local meshThick = thick + 1.2
    -- keep the frame's front flush with the lettering side, so a solid-backed mesh can never cover the text
    local shift = Vector3.zero
    local gui = panel:FindFirstChildWhichIsA("SurfaceGui")
    if gui then
        local n = Vector3.FromNormalId(gui.Face)
        shift = -n * ((meshThick - thick) / 2 + 0.1)
    end
    local cf = panel.CFrame * CFrame.new(shift) * rot
    local art = Place(template, Vector3.new(long * 1.14 + 1, tall * 1.16 + 1, meshThick), cf, "SignFrameArt")
    art.Parent = panel.Parent
    rec.art = art
end

local function BuildPost(rec)
    local post = rec.post
    if rec.art or not post or not post.Parent then return end
    local template = Template("SignPost")
    if not template then return end
    local s = post.Size
    local art = Place(template, Vector3.new(math.max(s.X, s.Z) + 0.4, s.Y, math.max(s.X, s.Z) + 0.4), post.CFrame, "SignPostArt")
    art.Parent = post.Parent
    post.Transparency = 1                               -- the plain post stays as the solid collider
    rec.art = art
end

function SignArt.Frame(kind, panel)
    local rec = { kind = kind, panel = panel }
    table.insert(records, rec)
    BuildFrame(rec)
    return rec
end

function SignArt.Post(post)
    local rec = { post = post }
    table.insert(records, rec)
    BuildPost(rec)
    return rec
end

function SignArt.Refresh()
    for i = #records, 1, -1 do
        local rec = records[i]
        if rec.art == nil then
            if rec.panel then BuildFrame(rec) else BuildPost(rec) end
        end
    end
end

return SignArt
