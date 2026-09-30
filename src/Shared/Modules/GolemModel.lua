-- Builds a blocky Golem model from primitives. Used for the Anvil preview and for Golems
-- standing in mining zones. Origin is ground level, facing -Z.
--
-- Look:   element -> body material/colour + accents (cracks, moss, ice, sparks, shadow)
--         tier    -> more detail: shoulders (T2), glowing core (T3), horns (T4), halo (T5)
--         variant -> Neon glows, Mega Neon cycles through rainbow colours (animated client-side)
--
-- Parts tagged with the attribute "Tint" take the variant colour animation; the arms and
-- pickaxe are named ArmL / ArmR / PickHandle / PickHead so the client can swing them.
--
-- If an uploaded model is available (server loads AssetData ids into ReplicatedStorage.GolemAssets,
-- see GolemAssetLoader) it is used instead of the blocks: scaled to the tier, tinted by element, made
-- Neon when asked, and dressed with the same cosmetics. Any problem falls back to the block Golem.
-- The model's "RigMode" attribute (Skinned / Parts / Static) tells GolemAnimator how to move it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local CosmeticData = require(script.Parent.Parent.Data.CosmeticData)
local AssetData = require(script.Parent.Parent.Data.AssetData)
local GolemSkinData = require(script.Parent.Parent.Data.GolemSkinData)

local GolemModel = {}

local warned = {}
local function WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    warn("[GolemModel] " .. msg)
end

local function AssetFolder() return ReplicatedStorage:FindFirstChild("GolemAssets") end

-- Bumps whenever an asset finishes loading, so callers can rebuild Golems that were made as blocks.
function GolemModel.AssetVersion()
    local f = AssetFolder()
    return f and f:GetAttribute("Version") or 0
end

-- The loaded template for an element: its own model if it has one, otherwise the shared Default.
function GolemModel.FindAsset(element)
    local f = AssetFolder()
    if not f then return nil end
    return f:FindFirstChild(element) or f:FindFirstChild("Default")
end

local function BodyParts(model)
    local out = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(out, d) end
    end
    return out
end

local function PickRoot(model)
    local root = model.PrimaryPart or model:FindFirstChild("Torso", true) or model:FindFirstChild("HumanoidRootPart", true)
    if root and root:IsA("BasePart") then return root end
    local best, bestVol
    for _, p in ipairs(BodyParts(model)) do
        local v = p.Size.X * p.Size.Y * p.Size.Z
        if not bestVol or v > bestVol then best, bestVol = p, v end
    end
    return best
end

-- Clones and prepares an uploaded model: faces -Z, scaled to the tier, standing on the ground at the
-- origin, tinted, glowing if Neon, pivot 5 studs up (where the block Golem's torso is) so every
-- caller can PivotTo it exactly like a block Golem.
-- Body colour per element for an uploaded (neutral light-grey) model; the model's own texture still
-- shows through, so this is a strong tint rather than a flat fill. ART_BRIEF 4.3.
local ELEMENT_BODY = {
    Ember = Color3.fromRGB(110, 92, 92),
    Stone = Color3.fromRGB(165, 170, 175),
    Frost = Color3.fromRGB(175, 225, 255),
    Storm = Color3.fromRGB(95, 100, 125),
    Void  = Color3.fromRGB(135, 85, 195),
    All   = Color3.fromRGB(250, 245, 232),
}

local function PrepareAsset(template, s, elementColor, skinColor, isNeon, element, skinLook)
    local model = template:Clone()
    model.Name = "GolemPreview"
    local mode = template:GetAttribute("RigMode") or "Static"
    local tint = template:GetAttribute("ElementTint") or 0

    local facing = template:GetAttribute("Facing") or 0
    if facing ~= 0 then model:PivotTo(CFrame.Angles(0, math.rad(facing), 0) * model:GetPivot()) end

    local height = model:GetExtentsSize().Y
    if height < 0.05 then error("model has no height") end
    model:ScaleTo(model:GetScale() * (AssetData.TARGET_HEIGHT / height) * s)

    local box, size = model:GetBoundingBox()
    model:PivotTo(CFrame.new(-box.Position.X, -(box.Position.Y - size.Y / 2), -box.Position.Z) * model:GetPivot())

    local root = PickRoot(model)
    if not root then error("model has no parts") end

    local bodyColor = Color3.new(1, 1, 1):Lerp(elementColor, tint)
    if tint > 0 and ELEMENT_BODY[element] then bodyColor = ELEMENT_BODY[element] end
    if skinLook then bodyColor = skinLook.color end
    if skinColor then bodyColor = bodyColor:Lerp(skinColor, 0.5) end
    local recolour = tint > 0 or skinColor ~= nil or skinLook ~= nil

    for _, d in ipairs(BodyParts(model)) do
        d.CanCollide = false
        d.CastShadow = false
        d.Anchored = mode ~= "Skinned" or d == root      -- skinned rigs: only the root is fixed, joints move the rest
        if d.Material ~= Enum.Material.Neon then         -- eyes and other glowing bits keep their own look
            d:SetAttribute("Tint", true)
            -- A MeshPart ignores Color while it has a baked TextureID, so recolouring means dropping
            -- the texture (the pickaxe keeps its own look). Glowing eyes are added back in Build.
            if (recolour or isNeon) and d:IsA("MeshPart") and d.Name ~= "PickHandle" and d.Name ~= "PickHead" then
                d.TextureID = ""
                model:SetAttribute("Flat", true)
                if not isNeon then d.Color = bodyColor end
            end
            local sa = d:FindFirstChildOfClass("SurfaceAppearance")
            if isNeon then
                if sa then sa:Destroy() end              -- flat glow so the rainbow / pulse can show
                d.Material = Enum.Material.Neon
                d.Transparency = 0.1
                d.Color = elementColor
            elseif recolour then
                if sa then sa.Color = bodyColor else d.Color = bodyColor end
            end
        end
    end

    model.PrimaryPart = root
    root.PivotOffset = root.CFrame:ToObjectSpace(CFrame.new(0, 5 * s, 0))
    model:SetAttribute("RigMode", mode)
    return model, root, mode, template:GetAttribute("TierAddOns") ~= false
end

local ELEMENT_LOOK = {
    Ember = { material = Enum.Material.Basalt,   accent = Color3.fromRGB(255, 120, 40),  accentMaterial = Enum.Material.Neon,  transparency = 0    },
    Stone = { material = Enum.Material.Slate,    accent = Color3.fromRGB(90, 140, 70),   accentMaterial = Enum.Material.Grass, transparency = 0    },
    Frost = { material = Enum.Material.Ice,      accent = Color3.fromRGB(220, 245, 255), accentMaterial = Enum.Material.Glass, transparency = 0.2  },
    Storm = { material = Enum.Material.Metal,    accent = Color3.fromRGB(190, 150, 255), accentMaterial = Enum.Material.Neon,  transparency = 0    },
    Void  = { material = Enum.Material.Glass,    accent = Color3.fromRGB(150, 70, 230),  accentMaterial = Enum.Material.Neon,  transparency = 0.15 },
    All   = { material = Enum.Material.Marble,   accent = Color3.fromRGB(255, 215, 90),  accentMaterial = Enum.Material.Neon,  transparency = 0    },
}

function GolemModel.Build(element, tier, options)
    options = options or {}
    tier = tier or 1
    local look = ELEMENT_LOOK[element] or ELEMENT_LOOK.Stone
    local color = Theme.Colors[element] or Color3.fromRGB(150, 150, 150)
    local elementColor = color
    local skinColor
    -- an equipped skin wins; otherwise a special Golem wears its own look
    local skinLook = (options.skin and GolemSkinData.Find(options.skin)) or GolemSkinData.Specials[element]
    if skinLook then
        -- a material skin replaces the element's surface, colour and glow (GolemSkinData)
        look = { material = skinLook.material, accent = skinLook.accent, accentMaterial = Enum.Material.Neon,
            transparency = skinLook.transparency or 0 }
        color = skinLook.color
    elseif options.skin then
        skinColor = CosmeticData.Describe(options.skin).color
        color = color:Lerp(skinColor, 0.65)
    end
    local dark  = color:Lerp(Color3.new(0, 0, 0), 0.35)
    local s     = 1 + (tier - 1) * 0.18
    local variant = options.variant
    local isNeon = variant == "Neon" or variant == "MegaNeon"

    local model, root, mode, addOns
    local template = GolemModel.FindAsset(element)
    if template then
        local ok, m, r, md, ao = pcall(PrepareAsset, template, s, elementColor, skinColor, isNeon, element, skinLook)
        if ok then
            model, root, mode, addOns = m, r, md, ao
        else
            WarnOnce("prep_" .. element, string.format("could not use the loaded '%s' model (%s); using the block Golem", template.Name, tostring(m)))
        end
    end
    local isAsset = model ~= nil
    if not isAsset then
        model = Instance.new("Model")
        model.Name = "GolemPreview"
    end
    local weldRoot = (mode == "Skinned") and root or nil    -- extras must follow a moving skeleton

    local function part(name, size, c, material, cf, transparency, tint)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size * s
        p.Color = c
        p.Material = material or look.material
        p.Transparency = transparency or 0
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.CFrame = cf
        if tint then p:SetAttribute("Tint", true) end
        p.Parent = model
        if weldRoot then
            p.Anchored = false
            local w = Instance.new("WeldConstraint")
            w.Part0 = weldRoot
            w.Part1 = p
            w.Parent = p
        end
        return p
    end
    local function at(x, y, z) return CFrame.new(x * s, y * s, z * s) end

    local bodyMaterial = isNeon and Enum.Material.Neon or look.material
    local bodyTransparency = isNeon and 0.1 or look.transparency

    local torso = root
    if not isAsset then
        torso = part("Torso", Vector3.new(3.2, 4, 2), color, bodyMaterial, at(0, 5, 0), bodyTransparency, true)
        part("Head", Vector3.new(2.4, 2.2, 2.4), dark, bodyMaterial, at(0, 8.3, 0), bodyTransparency, true)
        for _, side in ipairs({ -0.6, 0.6 }) do
            part("Eye", Vector3.new(0.5, 0.4, 0.2), look.accent:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon, at(side * 1.1, 8.5, -1.25))
        end
        for _, side in ipairs({ -0.85, 0.85 }) do
            part("Leg", Vector3.new(1.3, 3, 1.4), dark, bodyMaterial, at(side * 1, 1.5, 0), bodyTransparency, true)
        end
        part("ArmL", Vector3.new(1.1, 3, 1.1), dark, bodyMaterial,
            at(-2.2, 6.5, 0) * CFrame.Angles(-0.2, 0, 0) * CFrame.new(0, -1.5 * s, 0), bodyTransparency, true)
        local armR = part("ArmR", Vector3.new(1.1, 3, 1.1), dark, bodyMaterial,
            at(2.2, 6.5, 0) * CFrame.Angles(-1.1, 0, 0) * CFrame.new(0, -1.5 * s, 0), bodyTransparency, true)
        local hand = armR.CFrame * CFrame.new(0, -1.4 * s, -1.4 * s)
        part("PickHandle", Vector3.new(0.4, 0.4, 3.4), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, hand)
        part("PickHead", Vector3.new(2.8, 0.5, 0.5), Color3.fromRGB(190, 190, 200), Enum.Material.Metal, hand * CFrame.new(0, 0, -1.6 * s))

        -- ── Element details ───────────────────────────────────────────────────────
        if element == "Ember" then                         -- glowing cracks
            for i = -1, 1 do
                part("Crack", Vector3.new(0.25, 2.6, 0.12), look.accent, look.accentMaterial,
                    at(i * 0.9, 5, -1.02) * CFrame.Angles(0, 0, i * 0.25))
            end
        elseif element == "Stone" then                     -- moss patches
            part("Moss", Vector3.new(1.6, 0.5, 1.1), look.accent, look.accentMaterial, at(-0.7, 7.1, -0.3))
            part("Moss", Vector3.new(1.0, 0.4, 0.9), look.accent, look.accentMaterial, at(0.9, 3.1, -0.5))
        elseif element == "Frost" then                     -- icicle spikes on the back
            for i = -1, 1 do
                part("Icicle", Vector3.new(0.5, 1.6, 0.5), look.accent, look.accentMaterial,
                    at(i * 0.9, 7.6, 1.2) * CFrame.Angles(0.5, 0, i * 0.2), 0.25)
            end
        elseif element == "Storm" then                     -- spark strips
            for i = -1, 1, 2 do
                part("Spark", Vector3.new(0.15, 3, 0.15), look.accent, look.accentMaterial, at(i * 1.7, 5.2, -0.6) * CFrame.Angles(0, 0, i * 0.15))
            end
        elseif element == "Void" then                      -- floating shards
            for i = 1, 3 do
                part("Shard", Vector3.new(0.6, 1.1, 0.6), look.accent, look.accentMaterial,
                    at(math.cos(i * 2.1) * 2.8, 5 + i * 0.7, math.sin(i * 2.1) * 2.8) * CFrame.Angles(i, i * 0.6, 0), 0.2)
            end
        end
    end

    -- ── Uploaded model: surface, element details and tier pieces, placed from its real bounds ──
    local A                                             -- anchors (studs, world space, model at the origin facing -Z)
    if isAsset then
        local head = model:FindFirstChild("Head", true)
        local T, TS = root.Position, root.Size
        local H  = head and head.Position or (T + Vector3.new(0, TS.Y, 0))
        local HS = head and head.Size or Vector3.new(2.4, 2.2, 2.4) * s
        A = { T = T, hx = TS.X / 2, hy = TS.Y / 2, hz = TS.Z / 2, H = H, hhx = HS.X / 2, hhy = HS.Y / 2, hhz = HS.Z / 2 }

        if not isNeon then                              -- each element has its own surface (ART_BRIEF 4.3)
            for _, d in ipairs(BodyParts(model)) do
                if d:GetAttribute("Tint") and d.Name ~= "PickHandle" and d.Name ~= "PickHead" then
                    d.Material = look.material
                    if look.transparency > 0 then d.Transparency = look.transparency end
                end
            end
        end

        local function ap(name, size, c, material, pos, rot, transparency)
            return part(name, size / s, c, material, CFrame.new(pos) * (rot or CFrame.new()), transparency)
        end
        local front = T.Z - A.hz
        local acc, accMat = look.accent, look.accentMaterial

        if model:GetAttribute("Flat") then              -- the baked eyes went with the texture: glowing eyes (ART_BRIEF 4.1)
            for i = -1, 1, 2 do
                ap("Eye", Vector3.new(0.75, 0.6, 0.3), acc:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon,
                    Vector3.new(A.H.X + i * A.hhx * 0.42, A.H.Y + A.hhy * 0.05, A.H.Z - A.hhz - 0.05))
            end
        end

        local function skinDetail(kind)
            if kind == "cracks" then                    -- glowing fractures across chest and head
                for i = -1, 1 do
                    ap("Crack", Vector3.new(0.3, A.hy * 1.4, 0.15), acc, accMat,
                        Vector3.new(T.X + i * A.hx * 0.5, T.Y, front - 0.05), CFrame.Angles(0, 0, i * 0.35))
                end
                ap("Crack", Vector3.new(0.25, A.hhy * 1.2, 0.15), acc, accMat, Vector3.new(H.X + A.hhx * 0.5, H.Y + A.hhy * 0.2, H.Z - A.hhz - 0.05), CFrame.Angles(0, 0, 0.3))
            elseif kind == "rivets" then                -- a belly plate with rivets, plus shoulder bolts
                ap("BellyPlate", Vector3.new(A.hx * 1.6, A.hy * 0.7, 0.3), look.accentMaterial == Enum.Material.Neon and Color3.fromRGB(70, 74, 82) or acc,
                    Enum.Material.Metal, Vector3.new(T.X, T.Y - A.hy * 0.1, front - 0.1))
                for _, dx in ipairs({ -0.7, 0.7 }) do
                    for _, dy in ipairs({ -0.4, 0.2 }) do
                        local r = ap("Rivet", Vector3.new(0.7, 0.7, 0.4), Color3.fromRGB(150, 155, 165), Enum.Material.Metal,
                            Vector3.new(T.X + dx * A.hx * 0.8, T.Y + dy * A.hy, front - 0.35))
                        r.Shape = Enum.PartType.Ball
                    end
                end
                ap("FurnaceGlow", Vector3.new(A.hx * 0.8, A.hy * 0.25, 0.2), acc, Enum.Material.Neon, Vector3.new(T.X, T.Y - A.hy * 0.1, front - 0.3))
            elseif kind == "ribs" then                  -- a ribcage
                for i = -1, 2 do
                    ap("Rib", Vector3.new(A.hx * 1.5, 0.55, 0.4), Color3.fromRGB(250, 246, 226), Enum.Material.Limestone,
                        Vector3.new(T.X, T.Y + A.hy * (0.35 - i * 0.3), front - 0.15))
                end
                ap("Spine", Vector3.new(0.5, A.hy * 1.6, 0.4), Color3.fromRGB(250, 246, 226), Enum.Material.Limestone, Vector3.new(T.X, T.Y, front - 0.15))
            elseif kind == "leaves" then                -- leaves and a vine
                local green = Color3.fromRGB(90, 160, 70)
                for i = 1, 6 do
                    local a = i * 1.7
                    ap("Leaf", Vector3.new(1.6, 0.25, 0.9), green, Enum.Material.Grass,
                        Vector3.new(T.X + math.cos(a) * A.hx * 0.9, T.Y + A.hy * (0.9 - i * 0.28), front - 0.2),
                        CFrame.Angles(0, a, 0.5))
                end
                ap("CrownLeaf", Vector3.new(2.6, 0.4, 1.6), green, Enum.Material.Grass, Vector3.new(H.X, H.Y + A.hhy + 0.1, H.Z), CFrame.Angles(0, 0.6, 0.15))
            elseif kind == "facets" then                -- crystal spikes on the shoulders and back
                for i = -2, 2 do
                    ap("Facet", Vector3.new(0.9, 2.8 - math.abs(i) * 0.5, 0.9), acc, Enum.Material.Glass,
                        Vector3.new(T.X + i * A.hx * 0.4, T.Y + A.hy + 0.6 - math.abs(i) * 0.2, T.Z + A.hz * 0.3),
                        CFrame.Angles(0.15, i * 0.3, -i * 0.25), 0.2)
                end
                ap("ChestFacet", Vector3.new(1.4, 1.8, 0.8), acc, Enum.Material.Neon, Vector3.new(T.X, T.Y + A.hy * 0.25, front - 0.25), CFrame.Angles(0, 0, 0.785), 0.25)
            elseif kind == "runes" then                 -- glowing rune marks down the chest
                for i = -1, 1 do
                    ap("Rune", Vector3.new(0.8, 0.8, 0.15), acc, Enum.Material.Neon,
                        Vector3.new(T.X + (i % 2) * 0.4, T.Y - i * A.hy * 0.45, front - 0.05), CFrame.Angles(0, 0, 0.785 * (i + 2)))
                end
                ap("RuneBrow", Vector3.new(A.hhx * 1.2, 0.3, 0.15), acc, Enum.Material.Neon, Vector3.new(H.X, H.Y + A.hhy * 0.55, H.Z - A.hhz - 0.05))
            elseif kind == "shards" then                -- shards orbiting the body
                for i = 1, 5 do
                    local a = i / 5 * math.pi * 2
                    ap("Shard", Vector3.new(0.7, 1.4, 0.7), acc, Enum.Material.Neon,
                        Vector3.new(T.X + math.cos(a) * (A.hx + 2.2), T.Y + (i % 3 - 1) * A.hy * 0.8, T.Z + math.sin(a) * (A.hz + 2.2)), CFrame.Angles(i, i * 0.6, 0), 0.2)
                end
            elseif kind == "stitches" then              -- patchwork: mismatched patches held on with thread
                local thread = Color3.fromRGB(70, 48, 38)
                local patches = { Color3.fromRGB(205, 95, 95), Color3.fromRGB(95, 145, 205), Color3.fromRGB(235, 205, 95) }
                for i, c in ipairs(patches) do
                    ap("Patch", Vector3.new(A.hx * 0.7, A.hy * 0.5, 0.25), c, Enum.Material.Fabric,
                        Vector3.new(T.X + (i - 2) * A.hx * 0.75, T.Y + (i % 2 == 0 and -1 or 1) * A.hy * 0.25, front - 0.1))
                    for _, rot in ipairs({ 0.785, -0.785 }) do
                        ap("Stitch", Vector3.new(A.hx * 0.6, 0.12, 0.12), thread, Enum.Material.Fabric,
                            Vector3.new(T.X + (i - 2) * A.hx * 0.75, T.Y + (i % 2 == 0 and -1 or 1) * A.hy * 0.25, front - 0.28), CFrame.Angles(0, 0, rot))
                    end
                end
                ap("Patch", Vector3.new(A.hhx * 0.9, A.hhy * 0.8, 0.25), Color3.fromRGB(150, 205, 150), Enum.Material.Fabric,
                    Vector3.new(H.X + A.hhx * 0.45, H.Y + A.hhy * 0.55, H.Z - A.hhz - 0.05))
            elseif kind == "rope" then                  -- coils of rope wrapped round the body, with knots
                local rope = Color3.fromRGB(170, 128, 80)
                for i = 0, 3 do
                    ap("Coil", Vector3.new(A.hx * 2.15, 0.6, A.hz * 2.15), rope, Enum.Material.Fabric,
                        Vector3.new(T.X, T.Y + A.hy * (0.75 - i * 0.5), T.Z))
                end
                for i = 0, 1 do
                    local k = ap("Knot", Vector3.new(1.3, 1.3, 1.3), Color3.fromRGB(150, 110, 66), Enum.Material.Fabric,
                        Vector3.new(T.X + (i == 0 and -1 or 1) * A.hx * 0.45, T.Y + A.hy * (0.5 - i * 1.0), front - 0.3))
                    k.Shape = Enum.PartType.Ball
                end
                ap("HeadCoil", Vector3.new(A.hhx * 2.1, 0.5, A.hhz * 2.1), rope, Enum.Material.Fabric, Vector3.new(H.X, H.Y + A.hhy * 0.7, H.Z))
            elseif kind == "coral" then                 -- branching coral on the back and shoulders, a shell on the head
                local tips = { Color3.fromRGB(255, 140, 160), Color3.fromRGB(255, 170, 110), Color3.fromRGB(250, 100, 140) }
                for i = -2, 2 do
                    local h = 2.8 - math.abs(i) * 0.35
                    local x = T.X + i * A.hx * 0.42
                    local y = T.Y + A.hy + h * 0.4
                    ap("CoralBranch", Vector3.new(0.6, h, 0.6), Color3.fromRGB(240, 120, 130), Enum.Material.Sandstone,
                        Vector3.new(x, y, T.Z + A.hz * 0.3), CFrame.Angles(0.1, 0, -i * 0.22))
                    local tip = ap("CoralTip", Vector3.new(1.3, 1.3, 1.3), tips[(i + 2) % 3 + 1], Enum.Material.SmoothPlastic,
                        Vector3.new(x - i * 0.25, y + h * 0.5, T.Z + A.hz * 0.3))
                    tip.Shape = Enum.PartType.Ball
                end
                local shell = ap("Shell", Vector3.new(A.hhx * 1.5, 0.9, A.hhz * 1.2), Color3.fromRGB(255, 226, 205), Enum.Material.Marble,
                    Vector3.new(H.X, H.Y + A.hhy + 0.2, H.Z), CFrame.Angles(-0.25, 0, 0))
                shell.Shape = Enum.PartType.Ball
            elseif kind == "gears" then                 -- brass cogs on the chest and a wind-up key on the back
                local dark = Color3.fromRGB(150, 108, 48)
                local face = CFrame.Angles(0, math.pi / 2, 0)            -- cylinders lie along X; turn them to face forward
                local big = ap("Cog", Vector3.new(0.5, A.hx * 1.3, A.hx * 1.3), dark, Enum.Material.Metal,
                    Vector3.new(T.X - A.hx * 0.25, T.Y + A.hy * 0.1, front - 0.2), face)
                big.Shape = Enum.PartType.Cylinder
                for i = 0, 7 do
                    local a = i / 8 * math.pi * 2
                    ap("Tooth", Vector3.new(0.5, 0.5, 0.5), dark, Enum.Material.Metal,
                        Vector3.new(T.X - A.hx * 0.25 + math.cos(a) * A.hx * 0.68, T.Y + A.hy * 0.1 + math.sin(a) * A.hx * 0.68, front - 0.2))
                end
                local small = ap("Cog", Vector3.new(0.5, A.hx * 0.7, A.hx * 0.7), Color3.fromRGB(215, 172, 84), Enum.Material.Metal,
                    Vector3.new(T.X + A.hx * 0.5, T.Y - A.hy * 0.3, front - 0.2), face)
                small.Shape = Enum.PartType.Cylinder
                ap("KeyStem", Vector3.new(0.6, A.hy * 0.7, 0.6), Color3.fromRGB(215, 172, 84), Enum.Material.Metal, Vector3.new(T.X, T.Y + A.hy * 0.3, T.Z + A.hz + 0.6))
                ap("KeyHandle", Vector3.new(A.hx * 1.0, 0.7, 0.7), Color3.fromRGB(215, 172, 84), Enum.Material.Metal, Vector3.new(T.X, T.Y + A.hy * 0.7, T.Z + A.hz + 0.6))
            elseif kind == "vials" then                 -- glass vials of bubbling brew on the back and belt
                local brews = { Color3.fromRGB(120, 255, 120), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 180, 70) }
                for i = -1, 1 do
                    local tube = ap("Vial", Vector3.new(A.hy * 0.9, 1.2, 1.2), Color3.fromRGB(200, 240, 255), Enum.Material.Glass,
                        Vector3.new(T.X + i * A.hx * 0.6, T.Y + A.hy * 0.1, T.Z + A.hz + 0.8), CFrame.Angles(0, 0, math.pi / 2), 0.5)
                    tube.Shape = Enum.PartType.Cylinder
                    local liquid = ap("Brew", Vector3.new(A.hy * 0.55, 0.8, 0.8), brews[i + 2], Enum.Material.Neon,
                        Vector3.new(T.X + i * A.hx * 0.6, T.Y - A.hy * 0.1, T.Z + A.hz + 0.8), CFrame.Angles(0, 0, math.pi / 2), 0.15)
                    liquid.Shape = Enum.PartType.Cylinder
                end
                local belt = ap("BeltVial", Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(130, 255, 130), Enum.Material.Neon,
                    Vector3.new(T.X - A.hx * 0.6, T.Y - A.hy * 0.65, front - 0.3), nil, 0.2)
                belt.Shape = Enum.PartType.Ball
                local bubbles = Instance.new("ParticleEmitter")
                bubbles.Color = ColorSequence.new(acc); bubbles.Rate = 5; bubbles.Lifetime = NumberRange.new(1.2, 2)
                bubbles.Speed = NumberRange.new(2, 4); bubbles.EmissionDirection = Enum.NormalId.Top
                bubbles.Size = NumberSequence.new(0.4, 0.1); bubbles.Transparency = NumberSequence.new(0.3, 1); bubbles.LightEmission = 0.6
                bubbles.Parent = root
            elseif kind == "wings" then                 -- stone wings and little horns
                local stone = Color3.fromRGB(86, 90, 102)
                for _, side in ipairs({ -1, 1 }) do
                    for i = 0, 2 do
                        ap("Wing", Vector3.new(0.6, A.hy * (1.5 - i * 0.3), A.hx * 0.6), stone, Enum.Material.Slate,
                            Vector3.new(T.X + side * (A.hx * 0.7 + i * A.hx * 0.45), T.Y + A.hy * (0.5 - i * 0.15), T.Z + A.hz + 0.7),
                            CFrame.Angles(0, side * (0.5 + i * 0.25), -side * (0.25 + i * 0.12)))
                    end
                    ap("Horn", Vector3.new(0.6, 1.6, 0.6), Color3.fromRGB(60, 62, 72), Enum.Material.Slate,
                        Vector3.new(H.X + side * A.hhx * 0.6, H.Y + A.hhy + 0.6, H.Z), CFrame.Angles(0, 0, -side * 0.4))
                end
            elseif kind == "jar" then                   -- a glass jar with a cork, full of storm cloud and sparks
                local dome = ap("Jar", Vector3.new(A.hhx * 3.0, A.hhy * 3.0, A.hhz * 3.0), Color3.fromRGB(200, 225, 255), Enum.Material.Glass,
                    Vector3.new(H.X, H.Y, H.Z), nil, 0.72)
                dome.Shape = Enum.PartType.Ball
                ap("Cork", Vector3.new(A.hhx * 1.2, 0.9, A.hhz * 1.2), Color3.fromRGB(150, 108, 66), Enum.Material.Wood,
                    Vector3.new(H.X, H.Y + A.hhy * 1.5 + 0.4, H.Z))
                for i = 1, 3 do
                    local a = i * 2.1
                    local cloud = ap("Cloud", Vector3.new(1.6, 1.0, 1.6), Color3.fromRGB(235, 235, 255), Enum.Material.Neon,
                        Vector3.new(H.X + math.cos(a) * A.hhx * 0.9, H.Y + math.sin(a * 1.3) * A.hhy * 0.8, H.Z + math.sin(a) * A.hhz * 0.9), nil, 0.6)
                    cloud.Shape = Enum.PartType.Ball
                end
                local sparks = Instance.new("ParticleEmitter")
                sparks.Color = ColorSequence.new(acc); sparks.Rate = 8; sparks.Lifetime = NumberRange.new(0.2, 0.4)
                sparks.Speed = NumberRange.new(3, 7); sparks.SpreadAngle = Vector2.new(180, 180); sparks.LightEmission = 1
                sparks.Size = NumberSequence.new(0.5, 0); sparks.Parent = root
            elseif kind == "skull" then                 -- swept-back dragon horns, a brow plate and a spine ridge
                local bone = Color3.fromRGB(248, 242, 222)
                for _, side in ipairs({ -1, 1 }) do
                    for i = 1, 3 do
                        ap("DragonHorn", Vector3.new(0.9 - i * 0.22, 1.5, 0.9 - i * 0.22), bone, Enum.Material.Limestone,
                            Vector3.new(H.X + side * (A.hhx * 0.6 + i * 0.35), H.Y + A.hhy + 0.2 + i * 1.0, H.Z + i * 0.45),
                            CFrame.Angles(0.35 * i, 0, -side * 0.25 * i))
                    end
                end
                ap("Brow", Vector3.new(A.hhx * 2.2, 0.55, 0.6), bone, Enum.Material.Limestone, Vector3.new(H.X, H.Y + A.hhy * 0.4, H.Z - A.hhz - 0.1))
                for i = 0, 4 do
                    ap("Fin", Vector3.new(0.5, 1.8 - i * 0.2, 1.3), bone, Enum.Material.Limestone,
                        Vector3.new(T.X, T.Y + A.hy * (0.85 - i * 0.42), T.Z + A.hz + 0.4), CFrame.Angles(0.25, 0, 0))
                end
            elseif kind == "trim" then                  -- shining trim: belt, head band, chest lines
                ap("Belt", Vector3.new(A.hx * 2.1, 0.45, A.hz * 2.1), acc, Enum.Material.Neon, Vector3.new(T.X, T.Y - A.hy * 0.6, T.Z), nil, 0.1)
                ap("Band", Vector3.new(A.hhx * 2.1, 0.4, A.hhz * 2.1), acc, Enum.Material.Neon, Vector3.new(H.X, H.Y + A.hhy * 0.75, H.Z), nil, 0.1)
                for i = -1, 1, 2 do
                    ap("Line", Vector3.new(0.25, A.hy * 1.6, 0.25), acc, Enum.Material.Neon, Vector3.new(T.X + i * A.hx * 0.95, T.Y, front - 0.05), nil, 0.1)
                end
            end
        end

        if skinLook then
            skinDetail(skinLook.detail)
        elseif element == "Ember" then                  -- glowing cracks on the chest, a few sparks
            for i = -1, 1 do
                ap("Crack", Vector3.new(0.3, A.hy * 1.3, 0.15), acc, accMat,
                    Vector3.new(T.X + i * A.hx * 0.5, T.Y + A.hy * 0.1, front - 0.05), CFrame.Angles(0, 0, i * 0.3))
            end
            ap("Crack", Vector3.new(A.hx * 0.9, 0.3, 0.15), acc, accMat, Vector3.new(T.X, T.Y - A.hy * 0.45, front - 0.05))
            local e = Instance.new("ParticleEmitter")
            e.Color = ColorSequence.new(acc); e.Rate = 6; e.Lifetime = NumberRange.new(0.8, 1.6)
            e.Speed = NumberRange.new(2, 4); e.EmissionDirection = Enum.NormalId.Top; e.LightEmission = 1
            e.Size = NumberSequence.new(0.35, 0); e.Parent = root
        elseif element == "Stone" then                  -- moss patches and small crystals
            ap("Moss", Vector3.new(A.hx * 1.1, 0.45, A.hz * 0.9), acc, accMat, Vector3.new(T.X - A.hx * 0.4, T.Y + A.hy, T.Z - 0.2))
            ap("Moss", Vector3.new(A.hx * 0.7, 0.4, A.hz * 0.6), acc, accMat, Vector3.new(A.H.X + A.hhx * 0.3, A.H.Y + A.hhy, A.H.Z))
            for i = -1, 1, 2 do
                ap("Crystal", Vector3.new(0.6, 1.8, 0.6), Color3.fromRGB(120, 230, 200), Enum.Material.Glass,
                    Vector3.new(T.X + i * A.hx * 0.55, T.Y + A.hy + 0.6, T.Z + A.hz * 0.6), CFrame.Angles(0.3, 0, -i * 0.35), 0.15)
            end
        elseif element == "Frost" then                  -- icicle spikes on the back, frosty cap and edges
            for i = -2, 2 do
                ap("Icicle", Vector3.new(0.7, 2.6 - math.abs(i) * 0.4, 0.7), acc, Enum.Material.Ice,
                    Vector3.new(T.X + i * A.hx * 0.42, T.Y + A.hy * 0.6, T.Z + A.hz + 0.5),
                    CFrame.Angles(0.7, 0, i * 0.15), 0.2)
            end
            ap("FrostCap", Vector3.new(A.hhx * 2.1, 0.5, A.hhz * 2.1), Color3.new(1, 1, 1), Enum.Material.Ice,
                Vector3.new(A.H.X, A.H.Y + A.hhy, A.H.Z), nil, 0.15)
            ap("FrostEdge", Vector3.new(A.hx * 2.1, 0.45, A.hz * 2.1), Color3.new(1, 1, 1), Enum.Material.Ice,
                Vector3.new(T.X, T.Y - A.hy, T.Z), nil, 0.2)
        elseif element == "Storm" then                  -- violet spark strips
            for i = -1, 1, 2 do
                ap("Spark", Vector3.new(0.22, A.hy * 1.7, 0.15), acc, accMat,
                    Vector3.new(T.X + i * A.hx * 0.6, T.Y, front - 0.05), CFrame.Angles(0, 0, i * 0.12))
            end
            ap("Spark", Vector3.new(A.hx * 1.3, 0.22, 0.15), acc, accMat, Vector3.new(T.X, T.Y + A.hy * 0.35, front - 0.05))
            local e = Instance.new("ParticleEmitter")
            e.Color = ColorSequence.new(acc); e.Rate = 5; e.Lifetime = NumberRange.new(0.2, 0.4)
            e.Speed = NumberRange.new(4, 8); e.SpreadAngle = Vector2.new(180, 180); e.LightEmission = 1
            e.Size = NumberSequence.new(0.5, 0); e.Parent = root
        elseif element == "Void" then                   -- shards floating around the body
            for i = 1, 5 do
                local a = i / 5 * math.pi * 2
                ap("Shard", Vector3.new(0.7, 1.4, 0.7), acc, accMat,
                    Vector3.new(T.X + math.cos(a) * (A.hx + 2.2), T.Y + (i % 3 - 1) * A.hy * 0.8, T.Z + math.sin(a) * (A.hz + 2.2)),
                    CFrame.Angles(i, i * 0.6, 0), 0.2)
            end
        elseif element == "All" then                    -- gold glowing trim
            ap("GoldBelt", Vector3.new(A.hx * 2.1, 0.45, A.hz * 2.1), acc, Enum.Material.Neon, Vector3.new(T.X, T.Y - A.hy * 0.6, T.Z), nil, 0.1)
            ap("GoldBand", Vector3.new(A.hhx * 2.1, 0.4, A.hhz * 2.1), acc, Enum.Material.Neon, Vector3.new(A.H.X, A.H.Y + A.hhy * 0.75, A.H.Z), nil, 0.1)
            for i = -1, 1, 2 do
                ap("GoldTrim", Vector3.new(0.25, A.hy * 1.6, 0.25), acc, Enum.Material.Neon,
                    Vector3.new(T.X + i * A.hx * 0.95, T.Y, front - 0.05), nil, 0.1)
            end
        end
    end

    -- ── Tier details ──────────────────────────────────────────────────────────
    if tier >= 2 and A then                            -- shoulder plates on the uploaded model
        for _, side in ipairs({ -1, 1 }) do
            local p = part("Shoulder", Vector3.new(1.7, 0.8, 1.9), dark:Lerp(Color3.new(1, 1, 1), 0.1), look.material,
                CFrame.new(A.T.X + side * (A.hx + 0.9 * s), A.T.Y + A.hy - 0.3 * s, A.T.Z), bodyTransparency, true)
        end
    end
    if tier >= 2 and not isAsset then                  -- shoulder plates (sized for the block body)
        for _, side in ipairs({ -1, 1 }) do
            part("Shoulder", Vector3.new(1.6, 0.7, 1.7), dark:Lerp(Color3.new(1, 1, 1), 0.1), bodyMaterial, at(side * 2.1, 7.2, 0), bodyTransparency, true)
        end
    end
    local extras = not isAsset or addOns               -- an uploaded model may bring its own tier pieces
    if tier >= 3 and extras then                       -- glowing chest core
        local corePos = A and CFrame.new(A.T.X, A.T.Y + A.hy * 0.25, A.T.Z - A.hz - 0.15 * s) or at(0, 5.4, -1.15)
        local core = part("Core", Vector3.new(1.1, 1.1, 0.5), look.accent, Enum.Material.Neon, corePos)
        core.Shape = Enum.PartType.Ball
    end
    if tier >= 4 and extras then                       -- horns
        for _, side in ipairs({ -1, 1 }) do
            local hornPos = A and CFrame.new(A.H.X + side * A.hhx * 0.6, A.H.Y + A.hhy + 0.7 * s, A.H.Z) or at(side * 0.9, 10.1, 0)
            part("Horn", Vector3.new(0.5, 1.8, 0.5), Color3.fromRGB(230, 225, 210), Enum.Material.Marble,
                hornPos * CFrame.Angles(0, 0, -side * 0.35))
        end
    end
    if tier >= 5 and extras then                       -- halo
        local haloPos = A and CFrame.new(A.H.X, A.H.Y + A.hhy + 1.6 * s, A.H.Z) or at(0, 11.2, 0)
        local halo = part("Halo", Vector3.new(0.3, 3.4, 3.4), look.accent, Enum.Material.Neon,
            haloPos * CFrame.Angles(0, 0, math.pi / 2), 0.1)
        halo.Shape = Enum.PartType.Cylinder
    end

    -- ── Equipped cosmetics (never affect stats) ───────────────────────────────
    if skinColor then                                  -- Golem skin: glowing trim that follows the skin colour
        for _, side in ipairs({ -1, 1 }) do
            part("SkinTrim", Vector3.new(0.18, 3.6, 2.1), skinColor, Enum.Material.Neon, at(side * 1.65, 5, 0), 0.15)
        end
        part("SkinBelt", Vector3.new(3.3, 0.35, 2.1), skinColor, Enum.Material.Neon, at(0, 3.3, 0), 0.15)
    end
    if options.accessory then
        local d = CosmeticData.Describe(options.accessory)
        local id = options.accessory
        local c = d.color
        -- block coordinates (head top at 9.4); on an uploaded model, re-centre on its real head and widen to fit
        local aw = A and (A.hhx * 2 / (2.4 * s)) or 1
        local function hat(x, y, z)
            if not A then return at(x, y, z) end
            return CFrame.new(A.H.X + x * s * aw, A.H.Y + A.hhy + (y - 9.4) * s, A.H.Z + z * s * aw)
        end
        local function wide(v) return Vector3.new(v.X * aw, v.Y, v.Z * aw) end
        if id:find("Crown") then
            part("CrownBand", wide(Vector3.new(2.6, 0.4, 2.6)), c, Enum.Material.Neon, hat(0, 9.5, 0), 0.1)
            for i = 0, 4 do
                local a = i / 5 * math.pi * 2
                part("CrownSpike", Vector3.new(0.4 * aw, 1.1, 0.4 * aw), c, Enum.Material.Neon, hat(math.cos(a) * 1.1, 10.1, math.sin(a) * 1.1))
            end
        elseif id:find("Helm") then
            local cap = part("Helm", wide(Vector3.new(2.8, 2.2, 2.8)), c, Enum.Material.Metal, hat(0, 9.0, 0), 0.05)
            cap.Shape = Enum.PartType.Ball
            part("HelmVisor", wide(Vector3.new(2.5, 0.35, 0.3)), c:Lerp(Color3.new(0, 0, 0), 0.5), Enum.Material.Metal, hat(0, 8.7, -1.3))
        elseif id:find("Hat") then
            part("HatBrim", wide(Vector3.new(3.4, 0.25, 3.4)), c, Enum.Material.Fabric, hat(0, 9.5, 0))
            part("HatTop", wide(Vector3.new(2, 1.4, 2)), c, Enum.Material.Fabric, hat(0, 10.2, 0))
        else
            local orb = part("Orb", Vector3.new(1.1, 1.1, 1.1), c, Enum.Material.Neon, hat(0, 11, 0), 0.1)
            orb.Shape = Enum.PartType.Ball
        end
    end
    if options.particle then
        local d = CosmeticData.Describe(options.particle)
        local target = model:FindFirstChild("PickHead", true) or root
        if target then
            local e = Instance.new("ParticleEmitter")
            e.Color = ColorSequence.new(d.color)
            e.Rate = 14
            e.Lifetime = NumberRange.new(0.6, 1.2)
            e.Speed = NumberRange.new(3, 7)
            e.SpreadAngle = Vector2.new(180, 180)
            e.LightEmission = 1
            e.Size = NumberSequence.new(0.5, 0)
            e.Parent = target
        end
    end

    -- ── Variant glow ──────────────────────────────────────────────────────────
    if isNeon then
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = variant == "MegaNeon" and 26 or 16
        light.Brightness = variant == "MegaNeon" and 3 or 2
        light.Parent = torso
        model:SetAttribute("Variant", variant)
    end

    model.PrimaryPart = torso
    return model
end

return GolemModel
