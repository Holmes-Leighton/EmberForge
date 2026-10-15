-- Themed 3D scenery for Forge Skins. Each skin family grows its own structures around the
-- plot (obsidian spires, ice crystals, tesla pylons, void shards, golden pillars) instead of
-- just recolouring the stone.
--
-- Every piece is built non-colliding, so players and Golems walk straight through the
-- scenery. Basic skins get the big landmark pieces; Standard / premium skins add the
-- smaller scatter pieces and ambient particles on top.

local ForgeSkinProps = {}

local PI = math.pi
local rgb = Color3.fromRGB

-- Which family a skin id belongs to (nil = plain recolour only)
local FAMILIES = {
    { name = "ember",  words = { "Ember", "Lava", "Magma", "Molten", "Fire" } },
    { name = "frost",  words = { "Frost", "Ice", "Blizzard", "Glacial" } },
    { name = "storm",  words = { "Storm", "Thunder", "Lightning" } },
    { name = "void",   words = { "Void", "Shadow", "Rift" } },
    { name = "ancient", words = { "Ancient", "Primordial", "Gold", "Titan", "Sovereign" } },
    { name = "bronze", words = { "Bronze", "Copper" } },
}

function ForgeSkinProps.Family(skinId)
    if not skinId then return nil end
    for _, fam in ipairs(FAMILIES) do
        for _, w in ipairs(fam.words) do
            if skinId:find(w) then return fam.name end
        end
    end
    return nil
end

-- Where the scenery stands. Chosen to stay clear of the path, pedestals and menus.
local TALL = { { -10, 23.5, 0.2 }, { 10, 23.5, -0.2 }, { -23.5, 12, 1.2 }, { 23.5, 12, -1.2 } }
local MID  = { { -23.5, 3, 1.4 }, { 23.5, 3, -1.4 }, { -23.5, -14, 1.0 }, { 14, -22.5, -0.4 } }
local SMALL = {
    { -7, 24.5 }, { 7, 24.5 }, { -17, 24 }, { 17, 24 }, { -24.5, 20 }, { 24.5, 18 },
    { -24, -4 }, { 24, -6 }, { -12, -24.5 }, { 12, -24.5 }, { -24.5, 8 }, { 24.5, 7 },
}

-- A generated piece of the forge's own structure: the Gate or a Fence section of a skin family (ServerStorage.ForgeSkinAssets.<family>.<piece>, see
-- AssetData.ForgeSkinMeshes; `familyKey` nil or unknown = "default", the plain timber one). Every family has its own design, so skins differ in shape,
-- not only in colour. The mesh is fitted to `size` (a single generated mesh is stretched to it), stands with its base centre at `baseCFrame`, and is put in
-- `parent`. Returns the placed model, or nil when that mesh has not loaded (the caller then builds the part-made version). Not solid: callers add colliders.
function ForgeSkinProps.Piece(familyKey, pieceName, size, baseCFrame, parent)
    local ServerStorage = game:GetService("ServerStorage")
    if not ServerStorage.FindFirstChild then return nil end            -- (the test environment's ServerStorage is a bare stub)
    local root = ServerStorage:FindFirstChild("ForgeSkinAssets")
    local fam = root and (root:FindFirstChild(familyKey or "default") or root:FindFirstChild("default"))
    local template = fam and fam:FindFirstChild(pieceName)
    if not template then return nil end
    local m = template:Clone()
    local meshes = {}
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide = true, false
            if d:IsA("MeshPart") then table.insert(meshes, d) end
        end
    end
    if #meshes == 1 then
        meshes[1].Size = size                                           -- one generated mesh: stretch it to the slot
    else
        local ext = m:GetExtentsSize()
        m:ScaleTo(m:GetScale() * size.Y / math.max(ext.Y, 0.01))
    end
    m.Name = "Skin" .. pieceName
    m:PivotTo(baseCFrame * CFrame.new(0, size.Y / 2, 0))
    m.Parent = parent
    return m
end

-- env = { part, ball, at, light, fireOn, spin, ground, skin, tier }  (tier: 1 = Basic, 2 = Standard+)
function ForgeSkinProps.Build(model, family, env)
    local ground = env.ground
    local tier = env.tier or 2
    local folder = Instance.new("Folder")
    folder.Name = "SkinScenery"
    folder.Parent = model

    -- Same helpers as the forge, but everything goes in the scenery folder and never collides.
    local function P(name, size, cf, color, material, props)
        props = props or {}
        props.CanCollide = false
        local p = env.part(name, size, cf, color, material, props)
        p.Parent = folder
        return p
    end
    local function B(name, d, cf, color, material, props)
        props = props or {}
        props.Shape = Enum.PartType.Ball
        return P(name, Vector3.new(d, d, d), cf, color, material, props)
    end
    local function Cyl(name, height, dia, cf, color, material, props)   -- upright cylinder
        props = props or {}
        props.Shape = Enum.PartType.Cylinder
        return P(name, Vector3.new(height, dia, dia), cf * CFrame.Angles(0, 0, PI / 2), color, material, props)
    end
    local function at(x, y, z) return env.at(x, ground + y, z) end
    local function emitter(parent, color, rate, speed, life, size, spread, accel)
        local e = Instance.new("ParticleEmitter")
        e.Color = ColorSequence.new(color)
        e.Rate = rate
        e.Speed = NumberRange.new(speed[1], speed[2])
        e.Lifetime = NumberRange.new(life[1], life[2])
        e.Size = NumberSequence.new(size, 0)
        e.SpreadAngle = Vector2.new(spread, spread)
        e.LightEmission = 1
        if accel then e.Acceleration = accel end
        e.Parent = parent
        return e
    end

    local C = {}

    -- ═══ EMBER: obsidian spires split by glowing magma ═══════════════════════
    if family == "ember" then
        local rock, magma, glow = rgb(38, 30, 32), rgb(255, 110, 30), rgb(255, 170, 60)
        C.tall = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            local h = 0
            for i, w in ipairs({ 5.2, 4, 2.8, 1.6 }) do
                local seg = 2.6
                P("EmberSpire", Vector3.new(w, seg, w), base * CFrame.new(0.25 * i, h + seg / 2, 0) * CFrame.Angles(0.04 * i, i * 0.5, 0.06 * i),
                    rock, Enum.Material.Basalt)
                h += seg - 0.2
            end
            for i = 1, 3 do   -- magma veins climbing the spire
                P("EmberVein", Vector3.new(0.3, 3.2, 0.3), base * CFrame.new(1.7 - i * 0.35, 2.4 + i * 0.7, 1.6 - i * 0.2) * CFrame.Angles(0.2, 0, 0.35 - i * 0.2),
                    magma, Enum.Material.Neon)
            end
            local flame = B("EmberFlame", 1.4, base * CFrame.new(0.9, h + 0.8, 0), glow, Enum.Material.Neon)
            env.light(flame, magma, 18, 1.4)
            env.fireOn(flame, 5, 7, magma)
            if tier >= 2 then emitter(flame, glow, 8, { 3, 6 }, { 2, 3.5 }, 0.5, 25, Vector3.new(0, 4, 0)) end
        end
        C.mid = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            B("EmberBoulder", 4.4, base * CFrame.new(0, 1.2, 0), rock, Enum.Material.Basalt)
            B("EmberBoulder", 3, base * CFrame.new(2.6, 0.8, 1), rock, Enum.Material.Slate)
            P("EmberCrack", Vector3.new(0.35, 0.2, 3.6), base * CFrame.new(0, 3.2, 0) * CFrame.Angles(0.3, 0.3, 0), magma, Enum.Material.Neon)
            local pool = Cyl("EmberPool", 0.2, 3.4, base * CFrame.new(-2.8, 0.15, -1.4), magma, Enum.Material.Neon)
            env.light(pool, magma, 12, 1)
        end
        C.small = function(x, z, i)
            B("EmberRock", 1.2 + (i % 3) * 0.4, at(x, 0.5, z), rock, Enum.Material.Basalt)
            if i % 2 == 0 then
                local e = B("EmberCoal", 0.55, at(x + 0.6, 1.3, z), magma, Enum.Material.Neon)
                env.light(e, magma, 7, 0.8)
            end
        end

    -- ═══ FROST: clusters of ice crystal and snow drifts ══════════════════════
    elseif family == "frost" then
        local ice, deep, snow = rgb(170, 225, 255), rgb(90, 160, 225), rgb(240, 248, 255)
        local function crystal(base, dx, dz, h, w, tiltX, tiltZ, color)
            local c = P("FrostCrystal", Vector3.new(w, h, w), base * CFrame.new(dx, h / 2 - 0.1, dz) * CFrame.Angles(tiltX, 0.6, tiltZ),
                color or ice, Enum.Material.Ice, { Transparency = 0.15 })
            P("FrostCrystalTip", Vector3.new(w * 0.7, w * 1.4, w * 0.7), base * CFrame.new(dx, h - 0.2, dz) * CFrame.Angles(tiltX, 0.6 + PI / 4, tiltZ),
                color or ice, Enum.Material.Ice, { Transparency = 0.1 })
            return c
        end
        C.tall = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            crystal(base, 0, 0, 10, 2.6, 0.05, 0.04)
            crystal(base, 2.4, 0.8, 7, 1.9, 0.0, -0.3, deep)
            crystal(base, -2.2, -0.6, 6, 1.8, 0.25, 0.28)
            crystal(base, 0.8, -2.2, 5, 1.5, -0.3, 0.1, deep)
            crystal(base, -1, 2.3, 4, 1.3, 0.35, -0.2)
            local core = B("FrostCore", 1.4, base * CFrame.new(0, 4, 0), snow, Enum.Material.Neon, { Transparency = 0.3 })
            env.light(core, ice, 20, 1.2)
            if tier >= 2 then
                emitter(core, snow, 10, { 1, 2.5 }, { 3, 5 }, 0.35, 180, Vector3.new(0, -2, 0))
            end
        end
        C.mid = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            P("FrostDrift", Vector3.new(7, 2.2, 5), base * CFrame.new(0, 0.3, 0), snow, Enum.Material.Snow, { Shape = Enum.PartType.Ball })
            crystal(base, 0.5, 0, 4.2, 1.4, 0.1, 0.1)
            crystal(base, -1.4, 0.7, 2.8, 1.0, -0.2, 0.2, deep)
        end
        C.small = function(x, z, i)
            P("FrostMound", Vector3.new(3, 1, 2.6), at(x, 0.1, z), snow, Enum.Material.Snow, { Shape = Enum.PartType.Ball })
            crystal(at(x, 0, z), 0, 0, 1.8 + (i % 3) * 0.6, 0.7, 0.15 * ((i % 2) * 2 - 1), 0.1, i % 2 == 0 and deep or ice)
        end

    -- ═══ STORM: tesla pylons crackling with lightning ════════════════════════
    elseif family == "storm" then
        local steel, volt, white = rgb(95, 100, 125), rgb(170, 130, 255), rgb(235, 225, 255)
        C.tall = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            P("StormFoot", Vector3.new(4.4, 0.8, 4.4), base * CFrame.new(0, 0.4, 0), steel, Enum.Material.DiamondPlate)
            Cyl("StormPylon", 11, 1.3, base * CFrame.new(0, 6, 0), steel, Enum.Material.Metal)
            for i = 1, 3 do
                local ring = Cyl("StormCoil", 0.5, 2.8 - i * 0.35, base * CFrame.new(0, 2 + i * 2.4, 0), volt, Enum.Material.Neon)
                if env.spin then env.spin(ring, i % 2 == 0 and 2 or -2) end
            end
            local orb = B("StormOrb", 2.6, base * CFrame.new(0, 12.6, 0), white, Enum.Material.Neon)
            env.light(orb, volt, 26, 2)
            for i = 1, 4 do   -- lightning arcs reaching out of the orb
                local a = i / 4 * PI * 2
                P("StormArc", Vector3.new(0.2, 3.6, 0.2),
                    base * CFrame.new(math.cos(a) * 1.8, 12.4, math.sin(a) * 1.8) * CFrame.Angles(math.sin(a) * 0.9, 0, -math.cos(a) * 0.9),
                    volt, Enum.Material.Neon)
            end
            if tier >= 2 then emitter(orb, white, 14, { 4, 9 }, { 0.4, 0.9 }, 0.25, 180) end
        end
        C.mid = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            P("StormBase", Vector3.new(3.6, 1, 3.6), base * CFrame.new(0, 0.5, 0), steel, Enum.Material.DiamondPlate)
            Cyl("StormCap", 4.5, 2.2, base * CFrame.new(0, 3.2, 0), steel, Enum.Material.Metal)
            local band = Cyl("StormBand", 0.4, 2.5, base * CFrame.new(0, 3.2, 0), volt, Enum.Material.Neon)
            env.light(band, volt, 12, 1)
            B("StormBulb", 1.3, base * CFrame.new(0, 5.8, 0), white, Enum.Material.Neon)
            P("StormRod", Vector3.new(0.25, 3.5, 0.25), base * CFrame.new(1.8, 2.2, 0.6) * CFrame.Angles(0, 0, -0.25), steel, Enum.Material.Metal)
        end
        C.small = function(x, z, i)
            P("StormStake", Vector3.new(0.35, 3 + (i % 3), 0.35), at(x, 1.6, z) * CFrame.Angles(0, 0, 0.05 * (i % 3)), steel, Enum.Material.Metal)
            local tip = B("StormSpark", 0.7, at(x, 3.2 + (i % 3), z), white, Enum.Material.Neon)
            env.light(tip, volt, 7, 0.9)
        end

    -- ═══ VOID: floating obsidian shards around a hungry purple rift ══════════
    elseif family == "void" then
        local dark, violet, bright = rgb(28, 18, 44), rgb(150, 70, 235), rgb(225, 170, 255)
        C.tall = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            Cyl("VoidPlinth", 1, 5, base * CFrame.new(0, 0.5, 0), dark, Enum.Material.Basalt)
            local ring = P("VoidRift", Vector3.new(0.5, 7, 7), base * CFrame.new(0, 6, 0), violet, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.25 })
            if env.spin then env.spin(ring, 0.7) end
            local eye = B("VoidEye", 2.6, base * CFrame.new(0, 6, 0), dark, Enum.Material.Glass, { Transparency = 0.1 })
            env.light(eye, violet, 22, 1.6)
            B("VoidPupil", 1, base * CFrame.new(0, 6, 0), bright, Enum.Material.Neon)
            for i = 1, 5 do   -- shards orbiting at different heights
                local a = i / 5 * PI * 2
                local shard = P("VoidShard", Vector3.new(0.9, 3 + (i % 2) * 1.2, 0.9),
                    base * CFrame.new(math.cos(a) * 4, 3 + i * 1.1, math.sin(a) * 4) * CFrame.Angles(0.4 * i, a, 0.3),
                    dark, Enum.Material.Basalt)
                P("VoidShardEdge", Vector3.new(0.18, 2.6, 0.18), shard.CFrame * CFrame.new(0.5, 0, 0), violet, Enum.Material.Neon)
            end
            if tier >= 2 then emitter(eye, violet, 12, { 1, 3 }, { 2, 4 }, 0.5, 180, Vector3.new(0, 1.5, 0)) end
        end
        C.mid = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            for i = 1, 3 do
                P("VoidSpike", Vector3.new(1.4, 4 + i, 1.4), base * CFrame.new((i - 2) * 1.8, (4 + i) / 2, (i % 2) * 0.8) * CFrame.Angles(0.15 * (i - 2), i, 0.2 * (2 - i)),
                    dark, Enum.Material.Basalt)
            end
            local orb = B("VoidOrb", 1.2, base * CFrame.new(0, 5.2, 0), violet, Enum.Material.Neon, { Transparency = 0.2 })
            env.light(orb, violet, 12, 1)
            if env.spin then env.spin(orb, 1) end
        end
        C.small = function(x, z, i)
            P("VoidSliver", Vector3.new(0.8, 2 + (i % 3) * 0.7, 0.8), at(x, 1.2, z) * CFrame.Angles(0.2, i, 0.15), dark, Enum.Material.Basalt)
            P("VoidSliverEdge", Vector3.new(0.15, 1.6 + (i % 3) * 0.5, 0.15), at(x + 0.4, 1.3, z) * CFrame.Angles(0.2, i, 0.15), violet, Enum.Material.Neon)
        end

    -- ═══ ANCIENT: gold-banded marble columns and floating relics ═════════════
    elseif family == "ancient" then
        local marble, gold = rgb(228, 220, 200), rgb(255, 200, 60)
        C.tall = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            P("AncientPlinth", Vector3.new(4.4, 1, 4.4), base * CFrame.new(0, 0.5, 0), marble, Enum.Material.Marble)
            Cyl("AncientColumn", 8.6, 2.2, base * CFrame.new(0, 5.3, 0), marble, Enum.Material.Marble)
            for _, y in ipairs({ 2.2, 5.3, 8.4 }) do Cyl("AncientBand", 0.4, 2.6, base * CFrame.new(0, y, 0), gold, Enum.Material.Metal) end
            P("AncientCap", Vector3.new(4, 0.9, 4), base * CFrame.new(0, 10, 0), marble, Enum.Material.Marble)
            local relic = P("AncientRelic", Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(0, 12.2, 0) * CFrame.Angles(0.6, 0.6, 0), gold, Enum.Material.Neon)
            env.light(relic, gold, 20, 1.4)
            if env.spin then env.spin(relic, 1.1) end
            if tier >= 2 then emitter(relic, gold, 8, { 1, 3 }, { 2, 3 }, 0.4, 180) end
        end
        C.mid = function(x, z, yaw)   -- a broken column lying beside its stump
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            P("AncientStump", Vector3.new(3.6, 0.8, 3.6), base * CFrame.new(0, 0.4, 0), marble, Enum.Material.Marble)
            Cyl("AncientStump", 3.4, 2.2, base * CFrame.new(0, 2.4, 0), marble, Enum.Material.Marble)
            P("AncientFallen", Vector3.new(5.5, 2.2, 2.2), base * CFrame.new(3.6, 1.1, 2.4) * CFrame.Angles(0, 0.5, 0), marble, Enum.Material.Marble, { Shape = Enum.PartType.Cylinder })
            P("AncientBand", Vector3.new(0.4, 2.6, 2.6), base * CFrame.new(2.2, 1.1, 1.6) * CFrame.Angles(0, 0.5, 0), gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
        end
        C.small = function(x, z, i)
            P("AncientRubble", Vector3.new(1.6, 0.8 + (i % 2) * 0.5, 1.2), at(x, 0.4, z) * CFrame.Angles(0, i, 0.1), marble, Enum.Material.Marble)
            if i % 3 == 0 then P("AncientCoin", Vector3.new(0.9, 0.9, 0.2), at(x, 1.3, z), gold, Enum.Material.Metal) end
        end

    -- ═══ BRONZE: workshop cogs and stacked ingots ════════════════════════════
    elseif family == "bronze" then
        local bronze, dark = rgb(176, 120, 70), rgb(80, 56, 38)
        C.tall = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            P("BronzePost", Vector3.new(1, 8, 1), base * CFrame.new(0, 4, 0), dark, Enum.Material.Metal)
            P("BronzeCog", Vector3.new(0.9, 6, 6), base * CFrame.new(0, 7, 0.6), bronze, Enum.Material.CorrodedMetal, { Shape = Enum.PartType.Cylinder })
            for i = 1, 8 do
                local a = i / 8 * PI * 2
                P("BronzeTooth", Vector3.new(0.9, 1, 1), base * CFrame.new(0, 7 + math.sin(a) * 3.3, 0.6 + math.cos(a) * 3.3) * CFrame.Angles(a, 0, 0),
                    bronze, Enum.Material.CorrodedMetal)
            end
        end
        C.mid = function(x, z, yaw)
            local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
            for row = 0, 2 do
                for col = 0, 2 - row do
                    P("BronzeIngot", Vector3.new(2.4, 0.9, 1.3), base * CFrame.new((col - (2 - row) / 2) * 2.6, 0.45 + row * 0.9, 0), bronze, Enum.Material.Metal)
                end
            end
        end
        C.small = function(x, z, i)
            P("BronzeScrap", Vector3.new(1.4, 0.7, 1), at(x, 0.35, z) * CFrame.Angles(0, i, 0), bronze, Enum.Material.CorrodedMetal)
        end
    else
        return folder
    end

    -- A real mesh (ServerStorage.ForgeSkinAssets.<family>.<Tall|Mid|Small>, see AssetData.ForgeSkinMeshes) replaces
    -- the part-built piece when it has loaded. Always walk-through.
    local function mesh(pieceName, x, z, yaw, height)
        local ServerStorage = game:GetService("ServerStorage")
        if not ServerStorage.FindFirstChild then return false end        -- (the test environment's ServerStorage is a bare stub)
        local root = ServerStorage:FindFirstChild("ForgeSkinAssets")
        local fam = root and root:FindFirstChild(family)
        local template = fam and fam:FindFirstChild(pieceName)
        if not template then return false end
        local m = template:Clone()
        m.Name = "Skin" .. pieceName
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
        end
        local ext = m:GetExtentsSize()
        m:ScaleTo(m:GetScale() * height / math.max(ext.Y, 0.01))
        m:PivotTo(m:GetPivot() * CFrame.Angles(0, yaw, 0))
        local box, size = m:GetBoundingBox()
        local spot = at(x, 0, z).Position
        m:PivotTo(m:GetPivot() + (Vector3.new(spot.X, spot.Y + size.Y / 2, spot.Z) - box.Position))
        m.Parent = folder
        return true
    end

    for _, s in ipairs(TALL) do
        if not mesh("Tall", s[1], s[2], s[3], 12) then C.tall(s[1], s[2], s[3]) end
    end
    for _, s in ipairs(MID) do
        if not mesh("Mid", s[1], s[2], s[3], 6) then C.mid(s[1], s[2], s[3]) end
    end
    if tier >= 2 then
        for i, s in ipairs(SMALL) do
            if not mesh("Small", s[1], s[2], i, 2.6) then C.small(s[1], s[2], i) end
        end
    end
    return folder
end

return ForgeSkinProps
