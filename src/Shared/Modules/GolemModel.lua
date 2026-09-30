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
local function PrepareAsset(template, s, elementColor, skinColor, isNeon)
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
    if skinColor then bodyColor = bodyColor:Lerp(skinColor, 0.5) end
    local recolour = tint > 0 or skinColor ~= nil

    for _, d in ipairs(BodyParts(model)) do
        d.CanCollide = false
        d.CastShadow = false
        d.Anchored = mode ~= "Skinned" or d == root      -- skinned rigs: only the root is fixed, joints move the rest
        if d.Material ~= Enum.Material.Neon then         -- eyes and other glowing bits keep their own look
            d:SetAttribute("Tint", true)
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
    if options.skin then
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
        local ok, m, r, md, ao = pcall(PrepareAsset, template, s, elementColor, skinColor, isNeon)
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

    -- ── Tier details ──────────────────────────────────────────────────────────
    if tier >= 2 and not isAsset then                  -- shoulder plates (sized for the block body)
        for _, side in ipairs({ -1, 1 }) do
            part("Shoulder", Vector3.new(1.6, 0.7, 1.7), dark:Lerp(Color3.new(1, 1, 1), 0.1), bodyMaterial, at(side * 2.1, 7.2, 0), bodyTransparency, true)
        end
    end
    local extras = not isAsset or addOns               -- an uploaded model may bring its own tier pieces
    if tier >= 3 and extras then                       -- glowing chest core
        local core = part("Core", Vector3.new(1.1, 1.1, 0.5), look.accent, Enum.Material.Neon, at(0, 5.4, -1.15))
        core.Shape = Enum.PartType.Ball
    end
    if tier >= 4 and extras then                       -- horns
        for _, side in ipairs({ -1, 1 }) do
            part("Horn", Vector3.new(0.5, 1.8, 0.5), Color3.fromRGB(230, 225, 210), Enum.Material.Marble,
                at(side * 0.9, 10.1, 0) * CFrame.Angles(0, 0, -side * 0.35))
        end
    end
    if tier >= 5 and extras then                       -- halo
        local halo = part("Halo", Vector3.new(0.3, 3.4, 3.4), look.accent, Enum.Material.Neon,
            at(0, 11.2, 0) * CFrame.Angles(0, 0, math.pi / 2), 0.1)
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
        if id:find("Crown") then
            part("CrownBand", Vector3.new(2.6, 0.4, 2.6), c, Enum.Material.Neon, at(0, 9.5, 0), 0.1)
            for i = 0, 4 do
                local a = i / 5 * math.pi * 2
                part("CrownSpike", Vector3.new(0.4, 1.1, 0.4), c, Enum.Material.Neon, at(math.cos(a) * 1.1, 10.1, math.sin(a) * 1.1))
            end
        elseif id:find("Helm") then
            local cap = part("Helm", Vector3.new(2.8, 2.2, 2.8), c, Enum.Material.Metal, at(0, 9.0, 0), 0.05)
            cap.Shape = Enum.PartType.Ball
            part("HelmVisor", Vector3.new(2.5, 0.35, 0.3), c:Lerp(Color3.new(0, 0, 0), 0.5), Enum.Material.Metal, at(0, 8.7, -1.3))
        elseif id:find("Hat") then
            part("HatBrim", Vector3.new(3.4, 0.25, 3.4), c, Enum.Material.Fabric, at(0, 9.5, 0))
            part("HatTop", Vector3.new(2, 1.4, 2), c, Enum.Material.Fabric, at(0, 10.2, 0))
        else
            local orb = part("Orb", Vector3.new(1.1, 1.1, 1.1), c, Enum.Material.Neon, at(0, 11, 0), 0.1)
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
