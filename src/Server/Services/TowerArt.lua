-- Builds the Sky Tower out of parts: every level's platforms and obstacles (the same pieces as the Courier courses), a big numbered sign at each level's start, a colour
-- that changes with height, a glowing summit, and the portals (one in the hub, one back down). Everything static; the moving pieces are tagged for CourierController.
local TowerSkin = require(script.Parent.TowerSkin)
local CourierArt = require(script.Parent.CourierArt)
local TowerData  = require(game.ReplicatedStorage.Shared.Data.TowerData)

local TowerArt = {}

local P, Sign = CourierArt.P, CourierArt.Sign
local TIMBER = Color3.fromRGB(100, 70, 44)

-- Each level design has its own look: platform material and colours, and the glow colour of its edges
TowerArt.Themes = {
    wood      = { material = Enum.Material.Wood,         color = Color3.fromRGB(150, 104, 64),  rest = Color3.fromRGB(190, 140, 90),  accent = Color3.fromRGB(255, 190, 90), scaffold = true },
    sandstone = { material = Enum.Material.Sandstone,    color = Color3.fromRGB(196, 150, 100), rest = Color3.fromRGB(220, 180, 120), accent = Color3.fromRGB(255, 220, 130) },
    metal     = { material = Enum.Material.DiamondPlate, color = Color3.fromRGB(110, 116, 128), rest = Color3.fromRGB(150, 156, 168), accent = Color3.fromRGB(255, 160, 60), scaffold = true },
    neon      = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(70, 56, 110),  rest = Color3.fromRGB(96, 80, 150),   accent = Color3.fromRGB(120, 255, 230) },
    ice       = { material = Enum.Material.Ice,          color = Color3.fromRGB(150, 205, 245), rest = Color3.fromRGB(190, 230, 255), accent = Color3.fromRGB(170, 235, 255) },
    dark      = { material = Enum.Material.Basalt,       color = Color3.fromRGB(56, 48, 56),    rest = Color3.fromRGB(84, 72, 84),    accent = Color3.fromRGB(255, 120, 60), scaffold = true },
    glass     = { material = Enum.Material.Glass,        color = Color3.fromRGB(120, 200, 230), rest = Color3.fromRGB(160, 225, 245), accent = Color3.fromRGB(200, 250, 255) },
    slate     = { material = Enum.Material.Slate,        color = Color3.fromRGB(80, 84, 96),    rest = Color3.fromRGB(110, 114, 126), accent = Color3.fromRGB(200, 160, 255), scaffold = true },
    lava      = { material = Enum.Material.Basalt,       color = Color3.fromRGB(70, 36, 30),    rest = Color3.fromRGB(110, 52, 40),   accent = Color3.fromRGB(255, 90, 40), scaffold = true },
}

-- A hue that climbs through the rainbow with height, so players can see how high they are by colour
local function LevelColor(level, total)
    return Color3.fromHSV(0.02 + 0.72 * (level - 1) / math.max(1, total - 1), 0.75, 1)
end
TowerArt.LevelColor = LevelColor

local function Subset(list, level)
    local out = {}
    for _, item in ipairs(list) do if item.level == level then out[#out + 1] = item end end
    return out
end

-- The layout of one level, in the shape CourierArt's builders expect
local function LevelLayout(T, i, isLast)
    local lay = {
        platforms = Subset(T.platforms, i), movers = Subset(T.movers, i), crumbles = Subset(T.crumbles, i),
        spinners = Subset(T.spinners, i), crushers = Subset(T.crushers, i), checkpoints = Subset(T.checkpoints, i),
        trusses = Subset(T.trusses, i), bounces = Subset(T.bounces, i), sweepers = Subset(T.sweepers, i), walls = Subset(T.walls or {}, i),
        kills = Subset(T.kills or {}, i), lifts = Subset(T.lifts or {}, i), zmovers = Subset(T.zmovers or {}, i), orbiters = Subset(T.orbiters or {}, i),
        pendulums = Subset(T.pendulums or {}, i), beamfields = Subset(T.beamfields or {}, i),
        base = T.base,
    }
    if isLast then lay.finish = T.finish end
    return lay
end

-- ── The doorways ──────────────────────────────────────────────────────────────
-- A mine entrance in the cavern's own look: banded stone pillars, a carved stone lintel with a crystal keystone, a timber support frame, hanging lanterns, a plank sign,
-- and a rail track that runs straight into the glowing way through. The grand one (the Sky Tower door in the hub) adds a headframe (the winding wheel of a mine shaft)
-- above, flaming braziers, a cart heaped with ore and crates. Walk into the glow and `onEnter(player)` runs (no button).
-- The stone, lantern, brazier, headframe and crystal pieces are real meshes (DoorAssets); if one cannot be loaded its block version is built instead.
local AssetService      = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local DoorAssets        = require(game.ReplicatedStorage.Shared.Data.DoorAssets)

local STONE      = Color3.fromRGB(126, 108, 98)
local STONE_DARK = Color3.fromRGB(84, 70, 64)
local WOOD       = Color3.fromRGB(118, 80, 50)
local WOOD_DARK  = Color3.fromRGB(76, 50, 32)
local IRON       = Color3.fromRGB(50, 50, 58)
local LAMP       = Color3.fromRGB(255, 190, 100)

-- ── Meshes ────────────────────────────────────────────────────────────────────
local meshTemplates = {}            -- mesh id -> a MeshPart to clone, or false once it failed to load
local function MeshTemplate(def)
    if not def or not def.mesh or def.mesh <= 0 then return nil end
    local t = meshTemplates[def.mesh]
    if t == nil then
        local ok, part = pcall(function() return AssetService:CreateMeshPartAsync("rbxassetid://" .. def.mesh) end)
        if ok and part then
            part.Anchored = true
            part.Color = Color3.new(1, 1, 1)                                   -- (a new MeshPart is grey, which would darken its texture)
            if def.texture and def.texture > 0 then part.TextureID = "rbxassetid://" .. def.texture end
            t = part
        else
            warn("[TowerArt] could not load door mesh " .. tostring(def.mesh) .. ": " .. tostring(part))
            t = false
        end
        meshTemplates[def.mesh] = t
    end
    return t or nil
end

-- A mesh scaled to `size`, at `cf`. Decoration by default (no collision). Returns nil if the mesh is not available.
local function PlaceMesh(unit, def, size, cf, name, collide, tint)
    local t = MeshTemplate(def)
    if not t then return nil end
    local m = t:Clone()
    m.Name, m.Size, m.CFrame, m.CanCollide = name, size, cf, collide == true
    if tint then m.Color = tint end
    m.Parent = unit
    return m
end

-- A beam between two points (world space), as thick as `thick`
local function Beam(unit, a, b, thick, material, color, name)
    P({ Name = name, Material = material, Color = color, Size = Vector3.new(thick, thick, (b - a).Magnitude), CanCollide = false,
        CFrame = CFrame.lookAt((a + b) / 2, b) }, unit)
end

-- ── Fire and light ────────────────────────────────────────────────────────────
-- A flame that is alive: the built-in animated Fire, layered flame sprites that lick upward and spin, drifting embers, a little smoke, and a light that flickers
-- (the client animates every light tagged "EFFlicker", see TowerController). `scale` 1 is a brazier-sized flame.
local function Flame(unit, f, x, y, z, scale, smoke)
    local base = P({ Name = "Flame", Transparency = 1, CanCollide = false, CanQuery = false, Size = Vector3.new(1.2 * scale, 0.3, 1.2 * scale), CFrame = f * CFrame.new(x, y, z) }, unit)
    local fire = Instance.new("Fire")
    fire.Size, fire.Heat = 5.5 * scale, 6
    fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 190, 80), Color3.fromRGB(230, 70, 25)
    fire.Parent = base

    local tongues = Instance.new("ParticleEmitter")
    tongues.Name = "FlameTongues"
    tongues.Texture = "rbxasset://textures/particles/fire_main.dds"
    tongues.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 235, 150)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 130, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 30, 10)) })
    tongues.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.7 * scale), NumberSequenceKeypoint.new(0.4, 1.5 * scale), NumberSequenceKeypoint.new(1, 0.1) })
    tongues.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) })
    tongues.Lifetime, tongues.Rate, tongues.Speed, tongues.SpreadAngle = NumberRange.new(0.45, 0.85), 26 * scale, NumberRange.new(2, 4), Vector2.new(14, 14)
    tongues.Rotation, tongues.RotSpeed, tongues.Acceleration = NumberRange.new(0, 360), NumberRange.new(-90, 90), Vector3.new(0, 7, 0)
    tongues.LightEmission, tongues.EmissionDirection = 1, Enum.NormalId.Top
    tongues.Parent = base

    local embers = Instance.new("ParticleEmitter")
    embers.Name = "Embers"
    embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    embers.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 90, 30))
    embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * scale), NumberSequenceKeypoint.new(1, 0) })
    embers.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    embers.Lifetime, embers.Rate, embers.Speed, embers.SpreadAngle = NumberRange.new(1.2, 2.4), 7 * scale, NumberRange.new(3, 8), Vector2.new(25, 25)
    embers.Acceleration, embers.LightEmission, embers.EmissionDirection = Vector3.new(0, 4, 0), 1, Enum.NormalId.Top
    embers.Parent = base

    if smoke then
        local puff = Instance.new("ParticleEmitter")
        puff.Name = "Smoke"
        puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
        puff.Color = ColorSequence.new(Color3.fromRGB(70, 62, 60))
        puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 4.5 * scale) })
        puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
        puff.Lifetime, puff.Rate, puff.Speed, puff.SpreadAngle = NumberRange.new(2, 3.6), 3 * scale, NumberRange.new(2, 3.5), Vector2.new(10, 10)
        puff.Rotation, puff.RotSpeed, puff.Acceleration = NumberRange.new(0, 360), NumberRange.new(-30, 30), Vector3.new(0, 2.5, 0)
        puff.Parent = base
    end

    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 160, 70), 34 * math.max(scale, 0.7), 2, false
    light.Parent = base
    CollectionService:AddTag(light, "EFFlicker")
    return base
end

-- A hanging lantern with real glass and a living flame inside (a block lantern if the mesh is missing)
local function Lantern(unit, f, x, y, z, hang)
    if hang and hang > 0 then
        P({ Name = "LanternChain", Material = Enum.Material.Metal, Color = IRON, Size = Vector3.new(0.3, hang, 0.3), CanCollide = false, CFrame = f * CFrame.new(x, y + 1.9 + hang / 2, z) }, unit)
    end
    local def = DoorAssets.lantern
    local body = PlaceMesh(unit, def, def.size * 1.4, f * CFrame.new(x, y, z), "MineLantern", false)
    if body then
        local glow = P({ Name = "LanternGlow", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 175, 80), Transparency = 0.15, Shape = Enum.PartType.Ball,
            Size = Vector3.new(1.3, 1.3, 1.3), CanCollide = false, CFrame = f * CFrame.new(x, y - 0.2, z) }, unit)
        Flame(unit, f, x, y - 0.9, z, 0.32, false)
        return
    end
    local lamp = P({ Name = "MineLantern", Material = Enum.Material.Neon, Color = LAMP, Size = Vector3.new(1.6, 2.2, 1.6), CanCollide = false, CFrame = f * CFrame.new(x, y, z) }, unit)
    P({ Name = "MineLanternCap", Material = Enum.Material.Metal, Color = IRON, Size = Vector3.new(2.2, 0.5, 2.2), CanCollide = false, CFrame = f * CFrame.new(x, y + 1.4, z) }, unit)
    P({ Name = "MineLanternBase", Material = Enum.Material.Metal, Color = IRON, Size = Vector3.new(2, 0.4, 2), CanCollide = false, CFrame = f * CFrame.new(x, y - 1.3, z) }, unit)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 190, 110), 38, 1.6
    light.Parent = lamp
    CollectionService:AddTag(light, "EFFlicker")
end

-- A cluster of crystals standing out of the rock: the real crystal mesh, or tilted blocks if it is missing
local function Crystals(unit, f, x, y, z, color, seed, scale)
    local rng = Random.new(seed)
    local def = DoorAssets.crystals
    local tint = color:Lerp(Color3.fromRGB(255, 255, 255), 0.4)
    if MeshTemplate(def) then
        for k = 1, 2 do
            local s = (1 + rng:NextNumber(0, 0.5)) * scale * (k == 1 and 1.15 or 0.8)
            PlaceMesh(unit, def, def.size * s, f * CFrame.new(x + (k == 1 and 0 or rng:NextNumber(-1.6, 1.6)), y + def.size.Y * s / 2 - 0.3, z + rng:NextNumber(-1, 1))
                * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0), "PortalCrystal", false, tint)
        end
        return
    end
    for _ = 1, 4 do
        local h = (3 + rng:NextNumber(0, 3.5)) * scale
        local tilt = CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), math.rad(rng:NextNumber(0, 90)), math.rad(rng:NextNumber(-22, 22)))
        P({ Name = "PortalCrystal", Material = Enum.Material.Neon, Color = color:Lerp(Color3.fromRGB(255, 255, 255), rng:NextNumber(0, 0.15)), Transparency = 0.12,
            Size = Vector3.new(1.1 * scale, h, 1.1 * scale), CanCollide = false,
            CFrame = f * CFrame.new(x + rng:NextNumber(-1.6, 1.6), y + h / 2 - 0.4, z + rng:NextNumber(-1.2, 1.2)) * tilt }, unit)
    end
end

local function PlankSign(unit, f, label, color, localCFrame, size)
    local plank = P({ Name = "PortalSign", Material = Enum.Material.Wood, Color = WOOD_DARK, Size = size, CFrame = f * localCFrame }, unit)
    for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do          -- readable from both sides
        local gui = Instance.new("SurfaceGui")
        gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence, gui.MaxDistance = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, 0.2, 160
        gui.Parent = plank
        local t = Instance.new("TextLabel")
        t.Name = "Text"
        t.BackgroundTransparency, t.Size, t.Text = 1, UDim2.new(1, -24, 1, -12), label
        t.Position = UDim2.new(0, 12, 0, 6)
        t.Font, t.TextScaled, t.TextWrapped, t.TextColor3 = Enum.Font.GothamBlack, true, true, color:Lerp(Color3.fromRGB(255, 236, 190), 0.55)
        t.TextStrokeTransparency, t.TextStrokeColor3 = 0.35, Color3.fromRGB(30, 18, 10)
        t.Parent = gui
    end
    for _, sx in ipairs({ -1, 1 }) do                                                   -- iron rivets at the corners
        for _, sy in ipairs({ -1, 1 }) do
            P({ Name = "Rivet", Material = Enum.Material.Metal, Color = IRON, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.9, 0.9), CanCollide = false,
                CFrame = f * localCFrame * CFrame.new(sx * (size.X / 2 - 1), sy * (size.Y / 2 - 0.8), -size.Z / 2 - 0.05) * CFrame.Angles(0, math.rad(90), 0) }, unit)
        end
    end
end

function TowerArt.Portal(parent, position, facing, label, color, onEnter, grand)
    local unit = Instance.new("Model")
    unit.Name = "TowerPortal"
    local f = CFrame.lookAt(position, position + facing)           -- local -Z is the front (where you walk up from)
    local PW = grand and 3.5 or 2.5                               -- half width of a pillar
    local PX = 7 + PW                                             -- pillar centres: the pillars' inner faces frame the 14-wide opening
    local rng = Random.new(11)
    local lintelW = (PX + PW) * 2 + 2
    local pillarDef, lintelDef = DoorAssets.pillar, DoorAssets.lintel
    local meshStone = MeshTemplate(pillarDef) ~= nil and MeshTemplate(lintelDef) ~= nil     -- the real stone, or the block stone if either is missing

    -- stone floor, a step at the front, and the rails that lead into the glow
    local floorW = (PX + PW) * 2 + 6
    P({ Name = "PortalBase", Material = Enum.Material.Cobblestone, Color = STONE_DARK, Size = Vector3.new(floorW, 1, 20), CFrame = f * CFrame.new(0, 0.5, 0) }, unit)
    P({ Name = "PortalStep", Material = Enum.Material.Slate, Color = STONE, Size = Vector3.new(floorW - 6, 0.7, 4), CFrame = f * CFrame.new(0, 0.35, -11.5) }, unit)
    for _, sx in ipairs({ -2.3, 2.3 }) do
        P({ Name = "Rail", Material = Enum.Material.Metal, Color = IRON, Size = Vector3.new(0.5, 0.45, 24), CanCollide = false, CFrame = f * CFrame.new(sx, 1.2, -2) }, unit)
    end
    for z = -13, 8, 2.6 do
        P({ Name = "Sleeper", Material = Enum.Material.Wood, Color = WOOD_DARK, Size = Vector3.new(7.2, 0.35, 0.9), CanCollide = false, CFrame = f * CFrame.new(0, 1.15, z) }, unit)
    end

    for _, side in ipairs({ -1, 1 }) do
        local x = side * PX
        if meshStone then
            -- the real pillar: banded stone blocks stacked to the lintel, with an invisible collider so it is solid
            local s = (PW * 2) / pillarDef.size.X
            local n = math.max(2, math.floor(26 / (pillarDef.size.Y * s) + 0.5))
            local h = 26 / n
            for i = 1, n do
                PlaceMesh(unit, pillarDef, Vector3.new(PW * 2, h, pillarDef.size.Z * s), f * CFrame.new(x, 1 + (i - 0.5) * h, 0) * CFrame.Angles(0, math.rad(i % 2 == 0 and 180 or 0), 0), "PortalPillar", false)
            end
            P({ Name = "PillarCollider", Transparency = 1, CanQuery = false, Size = Vector3.new(PW * 2, 26, pillarDef.size.Z * s * 0.95), CFrame = f * CFrame.new(x, 14, 0) }, unit)
        else
            P({ Name = "PortalPillar", Material = Enum.Material.Cobblestone, Color = STONE, Size = Vector3.new(PW * 2 + 1, 10, 8), CFrame = f * CFrame.new(x, 6, 0) }, unit)
            P({ Name = "PortalPillar", Material = Enum.Material.Slate, Color = STONE_DARK, Size = Vector3.new(PW * 2, 10, 7.4), CFrame = f * CFrame.new(x, 16, 0) * CFrame.Angles(0, math.rad(side * 3), 0) }, unit)
            P({ Name = "PortalPillar", Material = Enum.Material.Cobblestone, Color = STONE, Size = Vector3.new(PW * 2 + 1, 5, 8), CFrame = f * CFrame.new(x, 23.5, 0) * CFrame.Angles(0, math.rad(-side * 2), 0) }, unit)
            for _, y in ipairs({ 2.6, 11, 21 }) do
                P({ Name = "IronBand", Material = Enum.Material.Metal, Color = IRON, Size = Vector3.new(PW * 2 + 1.5, 1, 8.5), CFrame = f * CFrame.new(x, y, 0) }, unit)
            end
        end
        for _ = 1, grand and 5 or 3 do                                                       -- ore seams on the front face
            local sy, sx = rng:NextNumber(4, 24), rng:NextNumber(-PW + 0.8, PW - 0.8)
            P({ Name = "OreSeam", Material = Enum.Material.Neon, Color = color, Transparency = 0.15, CanCollide = false,
                Size = Vector3.new(0.3, rng:NextNumber(2, 4.5), 0.3), CFrame = f * CFrame.new(x + sx, sy, -4.15) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))) }, unit)
        end
        -- the timber support frame just inside the stone
        P({ Name = "TimberPost", Material = Enum.Material.Wood, Color = WOOD, Size = Vector3.new(1.8, 25, 1.8), CFrame = f * CFrame.new(side * 7.9, 13, -1.4) }, unit)
        Beam(unit, f * Vector3.new(side * 7.9, 17, -1.4), f * Vector3.new(side * 4.2, 24.6, -1.4), 1.2, Enum.Material.Wood, WOOD, "TimberBrace")
        Lantern(unit, f, side * 4.6, 20.8, -2.4, 3)
        Crystals(unit, f, x, 27.2, -1, color, 40 + side, grand and 1 or 0.7)                  -- crystals growing out of the pillar tops
        Crystals(unit, f, side * (PX + PW + 2), 1, -5, color, 70 + side, grand and 0.9 or 0.6) -- and out of the floor beside them
    end

    -- the header: timber across the opening, then the heavy stone lintel with its keystone
    P({ Name = "TimberHeader", Material = Enum.Material.Wood, Color = WOOD_DARK, Size = Vector3.new(18.4, 2.4, 2.4), CFrame = f * CFrame.new(0, 25.2, -1.4) }, unit)
    if meshStone then
        PlaceMesh(unit, lintelDef, Vector3.new(lintelW, 7.4, 8.8), f * CFrame.new(0, 29.7, 0), "StoneLintel", false, Color3.fromRGB(195, 190, 190))
        P({ Name = "LintelCollider", Transparency = 1, CanQuery = false, Size = Vector3.new(lintelW, 6.6, 8.2), CFrame = f * CFrame.new(0, 29.7, 0) }, unit)
    else
        P({ Name = "StoneLintel", Material = Enum.Material.Cobblestone, Color = STONE, Size = Vector3.new(lintelW, 5, 8.4), CFrame = f * CFrame.new(0, 29.5, 0) }, unit)
        P({ Name = "Keystone", Material = Enum.Material.Slate, Color = STONE_DARK, Size = Vector3.new(8, 3, 8.8), CFrame = f * CFrame.new(0, 33, 0) }, unit)
    end
    local key = P({ Name = "KeystoneCrystal", Material = Enum.Material.Neon, Color = color, Transparency = 0.1, CanCollide = false,
        Size = Vector3.new(2.6, 6.4, 2.6), CFrame = f * CFrame.new(0, 37.6, 0) * CFrame.Angles(0, math.rad(45), math.rad(8)) }, unit)
    local keyLight = Instance.new("PointLight")
    keyLight.Color, keyLight.Range, keyLight.Brightness = color, 36, 1.1
    keyLight.Parent = key
    PlankSign(unit, f, label, color, CFrame.new(0, 29.7, -4.9), Vector3.new(math.min(lintelW - 5, 22), 4.2, 0.9))

    -- the glowing way through (this is the part that sends you off), with a lighter curtain in front of it for depth
    local gate = P({ Name = "PortalGlow", Material = Enum.Material.Neon, Color = color, Transparency = 0.5, Size = Vector3.new(14, 23, 2.2), CanCollide = false, CFrame = f * CFrame.new(0, 12.5, 0) }, unit)
    P({ Name = "PortalCurtain", Material = Enum.Material.Neon, Color = color:Lerp(Color3.fromRGB(255, 255, 255), 0.45), Transparency = 0.78, Size = Vector3.new(14, 23, 0.3), CanCollide = false, CFrame = f * CFrame.new(0, 12.5, -1.4) }, unit)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = color, 42, 1.5          -- (stronger washed the stone pink)
    light.Parent = gate
    local motes = Instance.new("ParticleEmitter")
    motes.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.5), color)
    motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
    motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
    motes.Lifetime, motes.Rate, motes.Speed, motes.SpreadAngle = NumberRange.new(2.2, 3.6), 22, NumberRange.new(2, 5), Vector2.new(10, 10)
    motes.LightEmission, motes.EmissionDirection, motes.LockedToPart = 1, Enum.NormalId.Top, false
    motes.Parent = gate

    if grand then
        -- the headframe: a timber A-frame with the winding wheel at the top, like the top of a mine shaft (the real mesh, or an A-frame built from beams)
        local hf = DoorAssets.headframe
        local top = 33.4
        if not PlaceMesh(unit, hf, Vector3.new(20, 25, 9.5), f * CFrame.new(0, top + 12.5, 0), "Headframe", false) then
            local apex = Vector3.new(0, 52, 0)
            for _, side in ipairs({ -1, 1 }) do
                Beam(unit, f * Vector3.new(side * 12, 32, 1.8), f * apex, 2, Enum.Material.Wood, WOOD, "HeadframeLeg")
                Beam(unit, f * Vector3.new(side * 12, 32, -1.8), f * apex, 2, Enum.Material.Wood, WOOD, "HeadframeLeg")
            end
            for _, h in ipairs({ { 38, 9 }, { 45, 5.2 } }) do
                P({ Name = "HeadframeCross", Material = Enum.Material.Wood, Color = WOOD_DARK, Size = Vector3.new(h[2] * 2, 1.3, 4.6), CFrame = f * CFrame.new(0, h[1], 0) }, unit)
            end
            local wheelAt = f * CFrame.new(0, 49, 0) * CFrame.Angles(0, math.rad(90), 0)
            P({ Name = "WindingWheel", Material = Enum.Material.Metal, Color = IRON, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 9, 9), CanCollide = false, CFrame = wheelAt }, unit)
            P({ Name = "WheelHub", Material = Enum.Material.Neon, Color = color, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.9, 2.4, 2.4), CanCollide = false, CFrame = wheelAt }, unit)
        end

        -- braziers on the front step, each with a living fire
        for _, side in ipairs({ -1, 1 }) do
            local bx = side * (PX + PW + 1.5)
            local bd = DoorAssets.brazier
            if PlaceMesh(unit, bd, bd.size * 1.9, f * CFrame.new(bx, 0.7 + bd.size.Y * 1.9 / 2, -12), "Brazier", false) then
                P({ Name = "BrazierCollider", Transparency = 1, CanQuery = false, Size = Vector3.new(4, 4, 4), CFrame = f * CFrame.new(bx, 2.8, -12) }, unit)
                Flame(unit, f, bx, 0.7 + bd.size.Y * 1.9 * 0.8, -12, 1.5, true)
            else
                P({ Name = "BrazierStand", Material = Enum.Material.Metal, Color = IRON, Size = Vector3.new(1.2, 4, 1.2), CFrame = f * CFrame.new(bx, 2.8, -12) }, unit)
                P({ Name = "BrazierBowl", Material = Enum.Material.Metal, Color = IRON, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 3.4, 3.4), CFrame = f * CFrame.new(bx, 5, -12) * CFrame.Angles(0, 0, math.rad(90)) }, unit)
                Flame(unit, f, bx, 5.4, -12, 1.2, true)
            end
        end

        -- a mine cart heaped with glowing ore on the left, crates and a barrel on the right
        local cartAt = f * CFrame.new(-PX - PW - 3.5, 0, -7) * CFrame.Angles(0, math.rad(18), 0)
        P({ Name = "CartBody", Material = Enum.Material.Metal, Color = Color3.fromRGB(86, 72, 66), Size = Vector3.new(6.4, 3, 4.2), CFrame = cartAt * CFrame.new(0, 3.1, 0) }, unit)
        P({ Name = "CartRim", Material = Enum.Material.Metal, Color = IRON, Size = Vector3.new(6.9, 0.5, 4.7), CFrame = cartAt * CFrame.new(0, 4.7, 0) }, unit)
        for _, wx in ipairs({ -2.2, 2.2 }) do
            for _, wz in ipairs({ -2.3, 2.3 }) do
                P({ Name = "CartWheel", Material = Enum.Material.Metal, Color = IRON, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.8, 1.8), CanCollide = false,
                    CFrame = cartAt * CFrame.new(wx, 1.6, wz) * CFrame.Angles(0, math.rad(90), 0) }, unit)
            end
        end
        for k = 1, 7 do
            local c = (k % 2 == 0) and color or Color3.fromRGB(255, 170, 70)
            P({ Name = "OreChunk", Material = Enum.Material.Neon, Color = c, Transparency = 0.08, Size = Vector3.new(rng:NextNumber(1, 1.9), rng:NextNumber(1, 1.9), rng:NextNumber(1, 1.9)), CanCollide = false,
                CFrame = cartAt * CFrame.new(rng:NextNumber(-2.4, 2.4), 5.3 + rng:NextNumber(0, 0.8), rng:NextNumber(-1.4, 1.4)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)) }, unit)
        end
        local cx = PX + PW + 4
        P({ Name = "Crate", Material = Enum.Material.Wood, Color = WOOD, Size = Vector3.new(4, 3.6, 4), CFrame = f * CFrame.new(cx, 2.8, -7) * CFrame.Angles(0, math.rad(-12), 0) }, unit)
        P({ Name = "Crate", Material = Enum.Material.Wood, Color = WOOD_DARK, Size = Vector3.new(3.4, 3.2, 3.4), CFrame = f * CFrame.new(cx + 0.4, 6.2, -7.2) * CFrame.Angles(0, math.rad(21), 0) }, unit)
        P({ Name = "Crate", Material = Enum.Material.Wood, Color = WOOD, Size = Vector3.new(3.6, 3.4, 3.6), CFrame = f * CFrame.new(cx - 4.4, 2.7, -9) * CFrame.Angles(0, math.rad(35), 0) }, unit)
        P({ Name = "Barrel", Material = Enum.Material.Wood, Color = WOOD, Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.8, 3.2, 3.2), CFrame = f * CFrame.new(cx + 3.6, 3.2, -10) * CFrame.Angles(0, 0, math.rad(90)) }, unit)
        for _, by in ipairs({ 2.4, 4.0 }) do
            P({ Name = "BarrelBand", Material = Enum.Material.Metal, Color = IRON, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 3.4, 3.4), CanCollide = false, CFrame = f * CFrame.new(cx + 3.6, by + 0.4, -10) * CFrame.Angles(0, 0, math.rad(90)) }, unit)
        end
        -- two pickaxes crossed on the left pillar's face
        for _, tilt in ipairs({ 38, -38 }) do
            local at = f * CFrame.new(-PX, 14, -4.5) * CFrame.Angles(0, 0, math.rad(tilt))
            P({ Name = "PickHandle", Material = Enum.Material.Wood, Color = WOOD, Size = Vector3.new(0.5, 7, 0.5), CanCollide = false, CFrame = at }, unit)
            P({ Name = "PickHead", Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 150, 160), Size = Vector3.new(3.8, 0.7, 0.7), CanCollide = false, CFrame = at * CFrame.new(0, 3.2, 0) }, unit)
        end
    end

    local recent = {}                                                 -- userId -> last time it fired (so one step through is one trip)
    gate.Touched:Connect(function(hit)
        local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
        if not player or not onEnter then return end
        local now = os.clock()
        if recent[player.UserId] and now - recent[player.UserId] < 3 then return end
        recent[player.UserId] = now
        onEnter(player)
    end)
    unit.PrimaryPart = unit:FindFirstChild("PortalBase")
    unit.Parent = parent
    return unit
end

-- A construction scaffold around the whole tower: four tall steel poles at the corners with horizontal braces every few levels and X-braces between them, so the climb
-- happens inside a structure you can see all the way up (and down). Decorative: nothing here is solid, so it never blocks a jump.
local function Frame(folder, T)
    local lo, hi, zlo, zhi = 1e9, -1e9, 1e9, -1e9
    for _, p in ipairs(T.platforms) do
        lo, hi = math.min(lo, p.x - p.sx / 2), math.max(hi, p.x + p.sx / 2)
        zlo, zhi = math.min(zlo, p.z - p.sz / 2), math.max(zhi, p.z + p.sz / 2)
    end
    local m = 16
    lo, hi, zlo, zhi = lo - m, hi + m, zlo - m, zhi + m
    local y0, y1 = T.base.y - 40, (T.finish and T.finish.y or T.base.y) + 60
    local group = Instance.new("Folder")
    group.Name = "ScaffoldFrame"
    group.Parent = folder
    local STEEL, YELLOW = Color3.fromRGB(255, 176, 40), Color3.fromRGB(255, 255, 255)
    local function pole(x, z)                                                -- in 40-stud girder sections (each one a mesh once it has loaded)
        local seg = 40
        local y = y0
        while y < y1 do
            local len = math.min(seg, y1 - y)
            local part = P({ Name = "ScaffoldPole", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = STEEL, Size = Vector3.new(len, 3, 3), CanCollide = false,
                CFrame = CFrame.new(x, y + len / 2, z) * CFrame.Angles(0, 0, math.pi / 2) }, group)
            -- (the girder mesh's long axis is local Z: stand it upright)
            TowerSkin.Piece("Girder", Vector3.new(3, 3, len), CFrame.new(x, y + len / 2, z) * CFrame.Angles(math.pi / 2, 0, 0), group, { part })
            y += len
        end
    end
    pole(lo, zlo) pole(lo, zhi) pole(hi, zlo) pole(hi, zhi)
    local function bar(a, b, name)
        local mid, span = (a + b) / 2, (b - a)
        local part = P({ Name = name, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = STEEL, Size = Vector3.new(span.Magnitude, 1.4, 1.4), CanCollide = false,
            CFrame = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0) }, group)
        TowerSkin.Piece("Girder", Vector3.new(1.6, 1.6, span.Magnitude), CFrame.lookAt(mid, b), group, { part })
    end
    local step = 40
    local flip = false
    for y = y0 + step, y1, step do
        bar(Vector3.new(lo, y, zlo), Vector3.new(hi, y, zlo), "BraceX")
        bar(Vector3.new(lo, y, zhi), Vector3.new(hi, y, zhi), "BraceX")
        bar(Vector3.new(lo, y, zlo), Vector3.new(lo, y, zhi), "BraceZ")
        bar(Vector3.new(hi, y, zlo), Vector3.new(hi, y, zhi), "BraceZ")
        if y + step <= y1 then                                              -- a diagonal in each bay, alternating, on the two long faces
            local a, b = flip and lo or hi, flip and hi or lo
            bar(Vector3.new(a, y, zlo), Vector3.new(b, y + step, zlo), "Diagonal")
            bar(Vector3.new(b, y, zhi), Vector3.new(a, y + step, zhi), "Diagonal")
            flip = not flip
        end
        for _, corner in ipairs({ { lo, zlo }, { lo, zhi }, { hi, zlo }, { hi, zhi } }) do      -- a yellow coupling band where the braces meet the poles
            P({ Name = "PoleBand", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = YELLOW, Size = Vector3.new(2, 3.6, 3.6), CanCollide = false,
                CFrame = CFrame.new(corner[1], y, corner[2]) * CFrame.Angles(0, 0, math.pi / 2) }, group)
        end
    end
end

-- A giant rainbow ring, standing across the course (a gate you run through): `segs` colour blocks around a circle of `radius`, in the YZ plane at x
function TowerArt.RainbowRing(parent, x, y, z, radius, segs)
    local arc = 2 * math.pi * radius / segs
    local blocks = {}
    for k = 0, segs - 1 do
        local t = 2 * math.pi * k / segs
        table.insert(blocks, P({ Name = "RingBlock", Material = Enum.Material.SmoothPlastic, Color = Color3.fromHSV(k / segs, 0.85, 1), Size = Vector3.new(3.2, arc + 0.5, 3.2), CanCollide = false,
            CFrame = CFrame.new(x, y + radius * math.sin(t), z + radius * math.cos(t)) * CFrame.Angles(-t, 0, 0) }, parent))
    end
    -- a single glowing ring mesh replaces the colour blocks once it has loaded (they stay as the fallback)
    -- (the ring mesh lies in its local XY plane; the course's rings stand in the YZ plane, so it is turned a quarter turn)
    TowerSkin.Piece("Ring", Vector3.new(radius * 2 + 3, radius * 2 + 3, 5), CFrame.new(x, y, z) * CFrame.Angles(0, math.pi / 2, 0), parent, blocks)
end

-- Soft clouds all round the tower, and a sea of cloud below it hiding the cavern floor far underneath. Decorative: nothing is solid.
local function Clouds(folder, T)
    local lo, hi, zlo, zhi = 1e9, -1e9, 1e9, -1e9
    for _, p in ipairs(T.platforms) do
        lo, hi = math.min(lo, p.x), math.max(hi, p.x)
        zlo, zhi = math.min(zlo, p.z), math.max(zhi, p.z)
    end
    local group = Instance.new("Folder")
    group.Name = "Clouds"
    group.Parent = folder
    local rng = Random.new(T.seed + 17)
    local top = (T.finish and T.finish.y or T.base.y)
    for _ = 1, 110 do
        local cx = rng:NextNumber(lo - 420, hi + 420)
        local cz = rng:NextNumber(zlo - 420, zhi + 420)
        local cy = rng:NextNumber(T.base.y - 110, top + 140)
        if math.abs(cx - (lo + hi) / 2) > 130 or math.abs(cz - (zlo + zhi) / 2) > 60 then          -- (keep the climbing space itself clear)
            local s = rng:NextNumber(26, 60)
            local balls = {}
            for k = 1, 3 do
                table.insert(balls, P({ Name = "Cloud", Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(252, 253, 255), Transparency = 0.08,
                    Size = Vector3.new(s * rng:NextNumber(1, 1.6), s * 0.55, s), CanCollide = false, CastShadow = false,
                    CFrame = CFrame.new(cx + (k - 2) * s * 0.7, cy + (k % 2) * 4, cz + rng:NextNumber(-8, 8)) }, group))
            end
            TowerSkin.Piece("Cloud", Vector3.new(s * 2.6, s * 0.9, s * 1.3), CFrame.new(cx, cy + 2, cz), group, balls)
        end
    end
    P({ Name = "CloudSea", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 247, 255), Transparency = 0.12, Size = Vector3.new(4000, 8, 4000), CanCollide = false, CastShadow = false,
        CFrame = CFrame.new((lo + hi) / 2, T.base.y - 180, (zlo + zhi) / 2) }, group)
end

-- Builds the whole tower for a layout T under `parent`. Returns the folder.
function TowerArt.Build(parent, T)
    local folder = Instance.new("Folder")
    folder.Name = "SkyTower"
    Frame(folder, T)
    Clouds(folder, T)
    for i, lv in ipairs(T.levels) do
        local color = LevelColor(i, T.total)
        local theme = TowerArt.Themes[lv.theme] or TowerArt.Themes.slate
        -- the big obbies are bright: each level is a saturated rainbow colour (by height) in smooth plastic with glowing white-ish edges; the design's theme only decides the extras (scaffold, pipes)
        local h = 0.02 + 0.82 * (i - 1) / math.max(1, T.total - 1)
        local look = {
            material = Enum.Material.SmoothPlastic, color = Color3.fromHSV(h, 0.82, 1), rest = Color3.fromHSV(h, 0.38, 1),
            accent = Color3.fromHSV((h + 0.5) % 1, 0.35, 1), scaffold = theme.scaffold, beam = Color3.fromHSV(h, 0.9, 0.85),
        }
        local r = { id = "Tower", def = { tier = lv.tier, color = look.accent, look = look }, layout = LevelLayout(T, i, i == T.total) }
        local group = Instance.new("Folder")
        group.Name = "Level" .. i
        group.Parent = folder
        CourierArt.Platforms(group, r)
        CourierArt.Obstacles(group, r)
        -- the level's number, big on a sign above its start platform (readable from the level below)
        local cp = r.layout.checkpoints[1]
        if cp then
            TowerArt.RainbowRing(group, cp.x, cp.y - 3 + 13, cp.z, 17, 26)
            local anchor = P({ Name = "LevelSignAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(cp.x, cp.y + 14, cp.z) }, group)
            Sign(group, anchor, "LEVEL " .. i .. "\n" .. (lv.design or ""), UDim2.new(0, 280, 0, 84), Vector3.new(0, 0, 0), color, 220)
            local beam = P({ Name = "LevelBeam", Material = Enum.Material.Neon, Color = color, Transparency = 0.75, Size = Vector3.new(2, 40, 2), CanCollide = false,
                CFrame = CFrame.new(cp.x, cp.y + 17, cp.z) }, group)
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness = color, 40, 1.4
            light.Parent = beam
        end
    end
    -- the summit: the drop-off ring and arch from the Courier art, in gold
    local lastLayout = LevelLayout(T, T.total, true)
    CourierArt.Finish(folder, { id = "Tower", def = { tier = 3, color = Color3.fromRGB(255, 215, 90) }, layout = lastLayout })
    folder.Parent = parent
    return folder
end

return TowerArt
