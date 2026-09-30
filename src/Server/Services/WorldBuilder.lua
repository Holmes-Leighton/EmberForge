-- Builds the shared world at runtime (no manual Studio work needed).
--
-- The whole game happens inside one enormous cavern (the hub): spawn, the Golem Anvil, the Pad Plaza
-- and every player's forge plot (built separately by ForgeZoneService along the X axis at Z = 0).
-- Along its north wall six tunnels lead to break-out caves, one per mining zone, each with its own
-- biome, lighting and scenery.

local Lighting = game:GetService("Lighting")
local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)

local WorldBuilder = {}

local ZONE_LAYOUT = {   -- order matches the row of landmarks
    { id = "EmberDepths",     color = Color3.fromRGB(255, 110, 40),  ground = Color3.fromRGB(70, 32, 24),  groundMaterial = Enum.Material.Basalt },
    { id = "GraniteCaverns",  color = Color3.fromRGB(150, 140, 130), ground = Color3.fromRGB(95, 92, 88),  groundMaterial = Enum.Material.Slate  },
    { id = "GlacialPeaks",    color = Color3.fromRGB(140, 210, 255), ground = Color3.fromRGB(225, 240, 250), groundMaterial = Enum.Material.Snow },
    { id = "StormriftCliffs", color = Color3.fromRGB(190, 160, 255), ground = Color3.fromRGB(58, 58, 74),  groundMaterial = Enum.Material.Rock   },
    { id = "TheHollow",       color = Color3.fromRGB(120, 60, 200),  ground = Color3.fromRGB(28, 20, 40),  groundMaterial = Enum.Material.Basalt },
    { id = "TheDeepForge",    color = Color3.fromRGB(255, 200, 60),  ground = Color3.fromRGB(60, 58, 62),  groundMaterial = Enum.Material.DiamondPlate },
}
local ZONE_Z       = 260
local ZONE_SPACING = 140

local function Part(props, parent)
    local p = Instance.new("Part")
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = parent
    return p
end

local function Sign(parent, text, subText, position, color)
    local anchor = Part({
        Name = "SignAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1,
        CanCollide = false, CFrame = CFrame.new(position),
    }, parent)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 320, 0, 90)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 250
    bb.Parent = anchor

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = color or Color3.fromRGB(255, 200, 80)
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.TextStrokeTransparency = 0.3
    title.Parent = bb

    local sub = Instance.new("TextLabel")
    sub.Position = UDim2.new(0, 0, 0.55, 0)
    sub.Size = UDim2.new(1, 0, 0.45, 0)
    sub.BackgroundTransparency = 1
    sub.Text = subText or ""
    sub.TextColor3 = Color3.fromRGB(235, 235, 235)
    sub.Font = Enum.Font.Gotham
    sub.TextScaled = true
    sub.TextStrokeTransparency = 0.5
    sub.Parent = bb
end

-- ── Starter station: the Golem Anvil ──────────────────────────────────────────
local function AddPrompt(part, action, objectText, hold)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = action
    prompt.ObjectText = objectText
    prompt.HoldDuration = hold
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = part
    return prompt
end

local function BuildStarterStation(world)
    local anvil = Part({
        Name = "GolemAnvil", Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 70, 78),
        Size = Vector3.new(8, 5, 5), CFrame = CFrame.new(0, 2.5, -100),
    }, world)
    Part({ Name = "AnvilTop", Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 110, 120),
        Size = Vector3.new(10, 1.5, 6), CFrame = CFrame.new(0, 5.7, -100) }, world)
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(255, 140, 50); glow.Range = 24; glow.Parent = anvil
    Sign(world, "Golem Anvil", "Press E to choose a Golem to forge",
        Vector3.new(0, 13, -100), Color3.fromRGB(255, 170, 60))

    -- The menu itself is client-side: AnvilMenuBuilder opens when this prompt fires
    local prompt = AddPrompt(anvil, "Use Anvil", "Golem Anvil", 0)
    prompt.Name = "AnvilPrompt"
end

local function UnlockText(zone)
    local r = zone.unlockRequirement
    if r.type == "craft_golem" then
        return "Craft a " .. r.element .. " Golem (Tier " .. r.minTier .. "+)"
    elseif r.type == "forge_level" then
        return "Reach Forge Level " .. r.level
    end
    return ""
end

-- ── Zone environments: each biome gets its own scenery (spec 10.1: one environment per zone) ─
local function Emitter(parent, props)
    local e = Instance.new("ParticleEmitter")
    for k, v in pairs(props) do e[k] = v end
    e.Parent = parent
    return e
end

local function Anchor(model, position)
    return Part({ Name = "FxAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false,
        CFrame = CFrame.new(position) }, model)
end

local ZoneProps = {}

ZoneProps.EmberDepths = function(model, cx, cz, rng, color)
    for i = 1, 6 do                                   -- lava pools
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextInteger(52, 64)
        Part({ Name = "LavaPool", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 90, 20),
            Size = Vector3.new(0.4, rng:NextInteger(9, 15), rng:NextInteger(9, 15)), CanCollide = false,
            CFrame = CFrame.new(cx + math.cos(a) * r, 0.4, cz + math.sin(a) * r) * CFrame.Angles(0, 0, math.pi / 2) }, model)
    end
    for i = 1, 8 do                                   -- obsidian spires
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextInteger(50, 66)
        local h = rng:NextInteger(14, 30)
        Part({ Name = "Spire", Material = Enum.Material.Basalt, Color = Color3.fromRGB(25, 20, 22), Size = Vector3.new(5, h, 5),
            CFrame = CFrame.new(cx + math.cos(a) * r, h / 2, cz + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), a, rng:NextNumber(-0.15, 0.15)) }, model)
    end
    Emitter(Anchor(model, Vector3.new(cx, 3, cz)), { Color = ColorSequence.new(Color3.fromRGB(255, 140, 40)), Rate = 25,
        Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(35, 35),
        EmissionDirection = Enum.NormalId.Top, LightEmission = 1, Size = NumberSequence.new(0.5), Acceleration = Vector3.new(0, 2, 0) })
end

ZoneProps.GraniteCaverns = function(model, cx, cz, rng, color)
    for i = 1, 10 do
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextInteger(50, 66)
        local h = rng:NextInteger(10, 26)
        Part({ Name = "Stalagmite", Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 115, 108), Size = Vector3.new(4, h, 4),
            CFrame = CFrame.new(cx + math.cos(a) * r, h / 2, cz + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), a, rng:NextNumber(-0.2, 0.2)) }, model)
    end
    for i = 1, 8 do
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextInteger(48, 68)
        local d = rng:NextInteger(6, 12)
        Part({ Name = "Boulder", Shape = Enum.PartType.Ball, Material = Enum.Material.Rock, Color = Color3.fromRGB(105, 100, 96),
            Size = Vector3.new(d, d * 0.8, d), CFrame = CFrame.new(cx + math.cos(a) * r, d * 0.3, cz + math.sin(a) * r) }, model)
    end
end

ZoneProps.GlacialPeaks = function(model, cx, cz, rng, color)
    for i = 1, 12 do
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextInteger(50, 68)
        local h = rng:NextInteger(16, 38)
        Part({ Name = "IceSpike", Material = Enum.Material.Ice, Color = Color3.fromRGB(170, 220, 255), Transparency = 0.25, Size = Vector3.new(4, h, 4),
            CFrame = CFrame.new(cx + math.cos(a) * r, h / 2, cz + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), a, rng:NextNumber(-0.25, 0.25)) }, model)
    end
    Emitter(Anchor(model, Vector3.new(cx, 60, cz)), { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), Rate = 60,
        Lifetime = NumberRange.new(6, 8), Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(60, 60),
        EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(0.6), Shape = Enum.ParticleEmitterShape.Box,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume })
end

ZoneProps.StormriftCliffs = function(model, cx, cz, rng, color)
    for i = 1, 6 do                                    -- lightning rods
        local a = (i / 6) * math.pi * 2
        local r = 56
        local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
        Part({ Name = "Rod", Material = Enum.Material.Metal, Color = Color3.fromRGB(90, 90, 100), Size = Vector3.new(1, 34, 1), CFrame = CFrame.new(x, 17, z) }, model)
        local tip = Part({ Name = "RodTip", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 170, 255),
            Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(x, 35, z), CanCollide = false }, model)
        Emitter(tip, { Color = ColorSequence.new(Color3.fromRGB(210, 180, 255)), Rate = 14, Lifetime = NumberRange.new(0.4, 0.8),
            Speed = NumberRange.new(8, 16), SpreadAngle = Vector2.new(180, 180), LightEmission = 1, Size = NumberSequence.new(0.35) })
    end
    for i = 1, 6 do                                    -- cliffs
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextInteger(62, 70)
        local h = rng:NextInteger(18, 34)
        Part({ Name = "Cliff", Material = Enum.Material.Rock, Color = Color3.fromRGB(70, 72, 84), Size = Vector3.new(16, h, 12),
            CFrame = CFrame.new(cx + math.cos(a) * r, h / 2, cz + math.sin(a) * r) * CFrame.Angles(0, a, 0) }, model)
    end
end

ZoneProps.TheHollow = function(model, cx, cz, rng, color)
    for i = 1, 14 do
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextInteger(46, 68)
        local s = rng:NextNumber(3, 7)
        Part({ Name = "VoidShard", Material = Enum.Material.Glass, Color = Color3.fromRGB(70, 30, 120), Transparency = 0.2, Size = Vector3.new(s, s * 2.2, s),
            CanCollide = false, CFrame = CFrame.new(cx + math.cos(a) * r, rng:NextInteger(8, 30), cz + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0) }, model)
    end
    Emitter(Anchor(model, Vector3.new(cx, 2, cz)), { Color = ColorSequence.new(Color3.fromRGB(110, 50, 170)), Rate = 10,
        Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new(14), Transparency = NumberSequence.new(0.8, 1), LightEmission = 0.4, Rotation = NumberRange.new(0, 360) })
end

ZoneProps.TheDeepForge = function(model, cx, cz, rng, color)
    local furnace = Part({ Name = "DeepFurnace", Shape = Enum.PartType.Ball, Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 68, 74),
        Size = Vector3.new(26, 26, 26), CFrame = CFrame.new(cx, 10, cz + 58) }, model)
    Part({ Name = "FurnaceGlow", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 50), Size = Vector3.new(9, 10, 1),
        CFrame = CFrame.new(cx, 6, cz + 45.5), CanCollide = false }, model)
    for _, dx in ipairs({ -12, 12 }) do
        local chimney = Part({ Name = "Chimney", Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 58, 62), Size = Vector3.new(4, 30, 4),
            CFrame = CFrame.new(cx + dx, 18, cz + 58) }, model)
        Emitter(chimney, { Color = ColorSequence.new(Color3.fromRGB(80, 80, 80)), Rate = 12, Lifetime = NumberRange.new(4, 6),
            Speed = NumberRange.new(4, 7), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(4), Transparency = NumberSequence.new(0.4, 1) })
    end
    local fire = Instance.new("Fire")
    fire.Size, fire.Heat = 18, 12
    fire.Parent = furnace
end

local function BuildLandmark(world, index, layout)
    local zone = MiningZoneData.Zones[layout.id]
    if not zone then return end
    local cx = (index - 3.5) * ZONE_SPACING
    local model = Instance.new("Model")
    model.Name = "Zone_" .. layout.id
    model.Parent = world

    -- Biome ground under and around the pad
    Part({ Name = "Biome", Material = layout.groundMaterial, Color = layout.ground, Size = Vector3.new(136, 0.4, 136),
        CFrame = CFrame.new(cx, 0.2, ZONE_Z), CanCollide = false }, model)

    -- Circular pad
    local pad = Part({
        Name = "Pad", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Slate,
        Color = layout.color:Lerp(Color3.new(0, 0, 0), 0.6),
        Size = Vector3.new(2, 90, 90),
        CFrame = CFrame.new(cx, 1, ZONE_Z) * CFrame.Angles(0, 0, math.pi / 2),
    }, model)

    -- Glowing crystal cluster
    local rng = Random.new(index * 97)
    for i = 1, 7 do
        local h = rng:NextInteger(10, 26)
        local angle = (i / 7) * math.pi * 2
        local r = i == 1 and 0 or rng:NextInteger(8, 22)
        local crystal = Part({
            Name = "Crystal", Material = Enum.Material.Neon, Color = layout.color,
            Transparency = 0.15, Size = Vector3.new(4, h, 4),
            CFrame = CFrame.new(cx + math.cos(angle) * r, 2 + h / 2, ZONE_Z + math.sin(angle) * r)
                * CFrame.Angles(rng:NextNumber(-0.25, 0.25), angle, rng:NextNumber(-0.25, 0.25)),
        }, model)
        crystal.CanCollide = false
    end
    local light = Instance.new("PointLight")
    light.Color = layout.color
    light.Range = 60
    light.Brightness = 2
    light.Parent = model:FindFirstChild("Crystal")

    local props = ZoneProps[layout.id]
    if props then
        local before = {}
        for _, c in ipairs(model:GetChildren()) do before[c] = true end
        props(model, cx, ZONE_Z, Random.new(index * 31), layout.color)
        -- nothing may stand in the corridor between the tunnel and the pad
        for _, c in ipairs(model:GetChildren()) do
            if not before[c] and c:IsA("BasePart") and c.Name ~= "FxAnchor" then
                local ok, pos = pcall(function() return c.Position end)
                if ok and pos and math.abs(pos.X - cx) < 26 + c.Size.X / 2 and pos.Z < ZONE_Z - 32 then
                    c:Destroy()
                end
            end
        end
    end

    Sign(model, zone.displayName, UnlockText(zone), Vector3.new(cx, 36, ZONE_Z), layout.color)
end

-- ── The cavern ────────────────────────────────────────────────────────────────
local HUB_X1, HUB_X2 = -450, 2100        -- west / east walls
local HUB_Z1, HUB_Z2 = -260, 190         -- south wall / the wall the tunnels pierce
local HUB_CEIL       = 110
local CH_Z2          = 334               -- back wall of the zone caves
local CH_CEIL        = 60
local ARCH_W, ARCH_H = 36, 28
local ROCK           = Color3.fromRGB(62, 54, 52)

-- A box from corner to corner, split so no single part exceeds Roblox's 2048-stud limit
local function Slab(parent, name, x1, x2, y1, y2, z1, z2, color, material)
    local pieces = math.max(1, math.ceil((x2 - x1) / 900))
    for i = 0, pieces - 1 do
        local a = x1 + (x2 - x1) * i / pieces
        local b = x1 + (x2 - x1) * (i + 1) / pieces
        Part({ Name = name, Material = material or Enum.Material.Slate, Color = color or ROCK,
            Size = Vector3.new(b - a, y2 - y1, z2 - z1), CFrame = CFrame.new((a + b) / 2, (y1 + y2) / 2, (z1 + z2) / 2) }, parent)
    end
end

local function ZoneX(index) return (index - 3.5) * ZONE_SPACING end

local function BuildCave(world)
    local cave = Instance.new("Folder")
    cave.Name = "Cave"
    cave.Parent = world
    local rng = Random.new(77)

    -- floor (named Ground)
    Slab(world, "Ground", HUB_X1, HUB_X2, -2, 0, HUB_Z1, CH_Z2 + 4, Color3.fromRGB(58, 50, 47), Enum.Material.Slate)

    -- outer walls and ceiling
    Slab(cave, "WallSouth", HUB_X1 - 6, HUB_X2 + 6, 0, HUB_CEIL + 6, HUB_Z1 - 6, HUB_Z1)
    Slab(cave, "WallWest", HUB_X1 - 6, HUB_X1, 0, HUB_CEIL + 6, HUB_Z1, CH_Z2 + 4)
    Slab(cave, "WallEast", HUB_X2, HUB_X2 + 6, 0, HUB_CEIL + 6, HUB_Z1, CH_Z2 + 4)
    Slab(cave, "Ceiling", HUB_X1 - 6, HUB_X2 + 6, HUB_CEIL, HUB_CEIL + 6, HUB_Z1 - 6, HUB_Z2 + 10, Color3.fromRGB(46, 40, 40))

    -- the north wall, pierced by an archway for each zone
    local cursor = HUB_X1 - 6
    for i = 1, #ZONE_LAYOUT do
        local cx = ZoneX(i)
        Slab(cave, "WallNorth", cursor, cx - ARCH_W / 2, 0, HUB_CEIL + 6, HUB_Z2 - 10, HUB_Z2 + 10)
        Slab(cave, "ArchLintel", cx - ARCH_W / 2, cx + ARCH_W / 2, ARCH_H, HUB_CEIL + 6, HUB_Z2 - 10, HUB_Z2 + 10)
        cursor = cx + ARCH_W / 2
    end
    Slab(cave, "WallNorth", cursor, HUB_X2 + 6, 0, HUB_CEIL + 6, HUB_Z2 - 10, HUB_Z2 + 10)

    -- zone caves: shared side walls, back wall and a lower roof
    for k = 0, #ZONE_LAYOUT do
        local x = ZoneX(1) - ZONE_SPACING / 2 + k * ZONE_SPACING
        Slab(cave, "ChamberWall", x - 2, x + 2, 0, CH_CEIL + 4, HUB_Z2 + 10, CH_Z2 + 4)
    end
    Slab(cave, "ChamberBack", ZoneX(1) - ZONE_SPACING / 2 - 2, ZoneX(#ZONE_LAYOUT) + ZONE_SPACING / 2 + 2, 0, CH_CEIL + 4, CH_Z2, CH_Z2 + 4)
    Slab(cave, "ChamberRoof", ZoneX(1) - ZONE_SPACING / 2 - 2, ZoneX(#ZONE_LAYOUT) + ZONE_SPACING / 2 + 2, CH_CEIL, CH_CEIL + 4, HUB_Z2 + 10, CH_Z2 + 4, Color3.fromRGB(46, 40, 40))

    -- Rock outcrops break up the flat walls and ceiling so it reads as a cavern, not a box
    local function Rock(x, y, z, sx, sy, sz, tint)
        local c = ROCK:Lerp(Color3.fromRGB(110, 95, 85), rng:NextNumber(0, 0.5))
        c = c:Lerp(tint or c, 0.15)
        local isBall = rng:NextNumber() < 0.45
        Part({ Name = "Outcrop", Shape = isBall and Enum.PartType.Ball or Enum.PartType.Block,
            Material = rng:NextNumber() < 0.5 and Enum.Material.Rock or Enum.Material.Slate, Color = c,
            Size = Vector3.new(sx, sy, sz),
            CFrame = CFrame.new(x, y, z) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)) }, cave)
    end
    local STEP = 30
    for x = HUB_X1, HUB_X2, STEP do
        for layer = 0, 3 do
            local y = layer * 27 + rng:NextInteger(0, 12)
            local jx = x + rng:NextInteger(-8, 8)
            -- south wall
            Rock(jx, y, HUB_Z1 + rng:NextInteger(0, 5), rng:NextInteger(16, 34), rng:NextInteger(16, 34), rng:NextInteger(12, 24))
            -- north wall (leave every tunnel mouth clear)
            local blocked = false
            for i = 1, #ZONE_LAYOUT do
                if math.abs(jx - ZoneX(i)) < ARCH_W / 2 + 14 and y < ARCH_H + 16 then blocked = true end
            end
            if not blocked then
                Rock(jx, y, HUB_Z2 - 10 - rng:NextInteger(0, 5), rng:NextInteger(16, 34), rng:NextInteger(16, 34), rng:NextInteger(12, 24))
            end
        end
    end
    for z = HUB_Z1, HUB_Z2, STEP do
        for layer = 0, 3 do
            local y = layer * 27 + rng:NextInteger(0, 12)
            Rock(HUB_X1 + rng:NextInteger(0, 5), y, z + rng:NextInteger(-8, 8), rng:NextInteger(12, 24), rng:NextInteger(16, 34), rng:NextInteger(16, 34))
            Rock(HUB_X2 - rng:NextInteger(0, 5), y, z + rng:NextInteger(-8, 8), rng:NextInteger(12, 24), rng:NextInteger(16, 34), rng:NextInteger(16, 34))
        end
    end
    for _ = 1, 230 do                       -- lumpy ceiling
        local sx, sz = rng:NextInteger(26, 60), rng:NextInteger(26, 60)
        Rock(rng:NextInteger(HUB_X1, HUB_X2), HUB_CEIL - rng:NextInteger(0, 8), rng:NextInteger(HUB_Z1, HUB_Z2 - 12), sx, rng:NextInteger(14, 26), sz)
    end
    for i = 1, #ZONE_LAYOUT do              -- rough rock around the caves' inner walls and roofs
        local cx = ZoneX(i)
        for _ = 1, 14 do
            Rock(cx + rng:NextInteger(-64, 64), rng:NextInteger(0, CH_CEIL - 6), CH_Z2 - rng:NextInteger(0, 4), rng:NextInteger(10, 22), rng:NextInteger(12, 26), rng:NextInteger(8, 16))
        end
        for _ = 1, 10 do
            Rock(cx + rng:NextInteger(-60, 60), CH_CEIL - rng:NextInteger(0, 4), rng:NextInteger(HUB_Z2 + 16, CH_Z2 - 6), rng:NextInteger(16, 30), rng:NextInteger(8, 16), rng:NextInteger(16, 30))
        end
    end

    -- stalactites hanging from the great ceiling
    for _ = 1, 170 do
        local x = rng:NextInteger(HUB_X1 + 10, HUB_X2 - 10)
        local z = rng:NextInteger(HUB_Z1 + 10, HUB_Z2 - 16)
        local h = rng:NextInteger(14, 42)
        local w = rng:NextInteger(6, 12)
        Part({ Name = "StalactiteBase", Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 62, 58), Size = Vector3.new(w, h * 0.55, w),
            CFrame = CFrame.new(x, HUB_CEIL - h * 0.275, z), CanCollide = false }, cave)
        Part({ Name = "StalactiteTip", Material = Enum.Material.Slate, Color = Color3.fromRGB(78, 68, 62), Size = Vector3.new(w * 0.5, h * 0.5, w * 0.5),
            CFrame = CFrame.new(x, HUB_CEIL - h * 0.8, z), CanCollide = false }, cave)
    end

    -- glowing ceiling veins and hanging lanterns give the cavern its light
    for i = 0, 55 do
        local x = HUB_X1 + 30 + i * ((HUB_X2 - HUB_X1 - 60) / 55)
        local z = rng:NextInteger(-200, 150)
        local glow = Part({ Name = "CeilingLamp", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon,
            Color = i % 3 == 0 and Color3.fromRGB(255, 150, 70) or Color3.fromRGB(255, 200, 130),
            Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(x, HUB_CEIL - 8, z), CanCollide = false }, cave)
        local l = Instance.new("PointLight")
        l.Color = glow.Color
        l.Range = 90
        l.Brightness = 1.6
        l.Parent = glow
    end
end

-- Arch trim, sign and roof lights for one zone cave
local function BuildChamber(world, index, layout)
    local cx = ZoneX(index)
    local model = world:FindFirstChild("Zone_" .. layout.id)
    if not model then return end
    for _, dx in ipairs({ -ARCH_W / 2, ARCH_W / 2 }) do
        Part({ Name = "ArchTrim", Material = Enum.Material.Neon, Color = layout.color, Size = Vector3.new(1.4, ARCH_H, 1.4),
            CFrame = CFrame.new(cx + dx, ARCH_H / 2, HUB_Z2 - 10), CanCollide = false }, model)
    end
    Part({ Name = "ArchTrim", Material = Enum.Material.Neon, Color = layout.color, Size = Vector3.new(ARCH_W + 1.4, 1.4, 1.4),
        CFrame = CFrame.new(cx, ARCH_H, HUB_Z2 - 10), CanCollide = false }, model)
    -- name plaque hung on the wall above the archway (a real part, so it can never clip into the rock)
    local plaque = Part({ Name = "ZonePlaque", Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(70, 48, 34),
        Size = Vector3.new(ARCH_W - 2, 9, 1.2), CFrame = CFrame.new(cx, ARCH_H + 8, HUB_Z2 - 10.9), CanCollide = false }, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 40
    sg.Parent = plaque
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, 0, 0.66, 0)
    name.BackgroundTransparency = 1
    name.Text = string.upper((layout.id:gsub("(%l)(%u)", "%1 %2")))
    name.TextColor3 = layout.color
    name.Font = Enum.Font.GothamBlack
    name.TextScaled = true
    name.TextStrokeTransparency = 0.2
    name.Parent = sg
    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.new(0, 0, 0.66, 0)
    hint.Size = UDim2.new(1, 0, 0.3, 0)
    hint.BackgroundTransparency = 1
    hint.Text = "mining cave"
    hint.TextColor3 = Color3.fromRGB(240, 235, 225)
    hint.Font = Enum.Font.GothamBold
    hint.TextScaled = true
    hint.Parent = sg
    -- road from the hub road to the mouth of the tunnel
    Part({ Name = "TunnelRoad", Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(105, 92, 82),
        Size = Vector3.new(12, 0.2, HUB_Z2 - 60), CFrame = CFrame.new(cx, 0.1, 60 + (HUB_Z2 - 60) / 2), CanCollide = false }, model)
    -- cave roof lights in the zone's colour
    for _, dx in ipairs({ -40, 0, 40 }) do
        local lamp = Part({ Name = "CaveLamp", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = layout.color,
            Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(cx + dx, CH_CEIL - 5, 270), CanCollide = false }, model)
        local l = Instance.new("PointLight")
        l.Color = layout.color
        l.Range = 70
        l.Brightness = 1.8
        l.Parent = lamp
    end
end

-- The plaza the mining pads stand on, with a gateway so newcomers can't miss it
local function BuildPadPlaza(world)
    local plaza = Instance.new("Model")
    plaza.Name = "PadPlaza"
    plaza.Parent = world
    Part({ Name = "PlazaFloor", Material = Enum.Material.Basalt, Color = Color3.fromRGB(38, 32, 34), Size = Vector3.new(250, 0.5, 108),
        CFrame = CFrame.new(0, 0.25, -162) }, plaza)
    for _, dz in ipairs({ -54, 54 }) do
        Part({ Name = "PlazaEdge", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 170, 60), Size = Vector3.new(250, 0.3, 1.2),
            CFrame = CFrame.new(0, 0.6, -162 + dz), CanCollide = false }, plaza)
    end
    -- gateway over the plaza entrance
    for _, dx in ipairs({ -30, 30 }) do
        Part({ Name = "GatePost", Material = Enum.Material.Wood, Color = Color3.fromRGB(88, 60, 40), Size = Vector3.new(4, 28, 4),
            CFrame = CFrame.new(dx, 14, -108) }, plaza)
        local orb = Part({ Name = "GateOrb", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 90),
            Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(dx, 30, -108), CanCollide = false }, plaza)
        local l = Instance.new("PointLight"); l.Color = orb.Color; l.Range = 45; l.Brightness = 2; l.Parent = orb
    end
    local beam = Part({ Name = "GateBeam", Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 76, 50), Size = Vector3.new(68, 7, 3),
        CFrame = CFrame.new(0, 26, -108) }, plaza)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 30
    sg.Parent = beam
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 1, 0)
    t.BackgroundTransparency = 1
    t.Text = "MINING PADS  -  stand on one to mine"
    t.TextColor3 = Color3.fromRGB(255, 226, 140)
    t.Font = Enum.Font.GothamBlack
    t.TextScaled = true
    t.TextStrokeTransparency = 0.2
    t.Parent = sg
end

-- Cobbled roads: one along the cavern, spurs to the spawn (the tunnel roads are added per zone)
local function BuildRoads(world)
    local x1, x2, pieces = HUB_X1 + 10, HUB_X2 - 10, 3
    for i = 0, pieces - 1 do
        local a = x1 + (x2 - x1) * i / pieces
        local b = x1 + (x2 - x1) * (i + 1) / pieces
        Part({ Name = "Path", Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(105, 92, 82),
            Size = Vector3.new(b - a, 0.2, 12), CFrame = CFrame.new((a + b) / 2, 0.1, 60), CanCollide = false }, world)
    end
    Part({ Name = "SpawnRoad", Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(105, 92, 82),
        Size = Vector3.new(10, 0.2, 140), CFrame = CFrame.new(-45, 0.1, -10), CanCollide = false }, world)
end

-- Cave dressing: stalagmites, glowing crystals and mushrooms, kept clear of plots, pads, spawn and roads
local function BuildScenery(world)
    local rng = Random.new(2024)
    local folder = Instance.new("Folder")
    folder.Name = "Scenery"
    folder.Parent = world

    local palette = { Color3.fromRGB(255, 140, 70), Color3.fromRGB(120, 200, 255), Color3.fromRGB(190, 140, 255), Color3.fromRGB(120, 255, 170) }
    for n = 1, 260 do
        local x = rng:NextInteger(HUB_X1 + 12, HUB_X2 - 12)
        local z = rng:NextInteger(HUB_Z1 + 12, HUB_Z2 - 14)
        local inPlots   = math.abs(z) < 62 and x > -45
        local onRoad    = math.abs(z - 60) < 10 or math.abs(x + 45) < 9
        local inPads    = math.abs(x) < 140 and z < -105 and z > -220
        local nearSpawn = math.abs(x) < 60 and z < -20 and z > -105
        local inTunnels = z > 100
        if not (inPlots or onRoad or inPads or nearSpawn or inTunnels) then
            local roll = rng:NextNumber()
            if roll < 0.45 then
                local h = rng:NextInteger(6, 22)
                Part({ Name = "Stalagmite", Material = Enum.Material.Slate, Color = Color3.fromRGB(88, 78, 72), Size = Vector3.new(rng:NextInteger(3, 6), h, rng:NextInteger(3, 6)),
                    CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6), rng:NextNumber(-0.12, 0.12)) }, folder)
            elseif roll < 0.8 then
                local c = palette[rng:NextInteger(1, #palette)]
                local h = rng:NextInteger(4, 11)
                local first
                for i = 1, 3 do
                    local cr = Part({ Name = "CaveCrystal", Material = Enum.Material.Neon, Color = c, Transparency = 0.15, Size = Vector3.new(1.6, h - i, 1.6), CanCollide = false,
                        CFrame = CFrame.new(x + (i - 2) * 1.6, (h - i) / 2, z + (i % 2) * 1.2) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)) }, folder)
                    first = first or cr
                end
                if n % 3 == 0 and first then
                    local l = Instance.new("PointLight"); l.Color = c; l.Range = 38; l.Brightness = 1.4; l.Parent = first
                end
            else
                local d = rng:NextInteger(3, 6)
                Part({ Name = "MushroomStem", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 220, 200), Size = Vector3.new(1, d, 1),
                    CFrame = CFrame.new(x, d / 2, z), CanCollide = false }, folder)
                Part({ Name = "MushroomCap", Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 190, 255),
                    Size = Vector3.new(d * 1.8, d, d * 1.8), CFrame = CFrame.new(x, d, z), CanCollide = false }, folder)
            end
        end
    end
end

-- Centre of a mining zone's pad (ground level), used to place deployed Golems
function WorldBuilder.GetZoneCenter(zoneId)
    for i, layout in ipairs(ZONE_LAYOUT) do
        if layout.id == zoneId then
            return Vector3.new((i - 3.5) * ZONE_SPACING, 0, ZONE_Z)
        end
    end
    return nil
end

-- ── "Top Forges" discovery board (spec 7.2): the highest-level forges, refreshed every minute ──
local function BuildDiscoveryBoard(world)
    local LeaderboardService = require(script.Parent.LeaderboardService)

    local board = Part({ Name = "DiscoveryBoard", Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(70, 48, 32),
        Size = Vector3.new(1.4, 17, 27), CFrame = CFrame.new(-66, 10, -66) }, world)
    for _, dz in ipairs({ -12, 12 }) do
        Part({ Name = "Post", Material = Enum.Material.Wood, Color = Color3.fromRGB(50, 34, 22), Size = Vector3.new(1.6, 8, 1.6),
            CFrame = CFrame.new(-66, 3, -66 + dz) }, world)
    end

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Right
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.Parent = board

    local function label(text, y, h, size, color)
        local l = Instance.new("TextLabel")
        l.Position = UDim2.new(0, 10, 0, y)
        l.Size = UDim2.new(1, -20, 0, h)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color
        l.Font = Enum.Font.GothamBold
        l.TextSize = size
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = gui
        return l
    end
    label("TOP FORGES", 8, 60, 44, Color3.fromRGB(255, 200, 80))
    label("Highest Forge Level", 66, 30, 22, Color3.fromRGB(220, 200, 170))
    local rows = {}
    for i = 1, 5 do rows[i] = label("", 100 + (i - 1) * 86, 70, 32, Color3.fromRGB(245, 235, 220)) end

    local function refresh()
        local ok, entries = pcall(function() return LeaderboardService.GetTopEntries("ForgeLevel", 5) end)
        entries = ok and entries or {}
        for i = 1, 5 do
            local e = entries[i]
            rows[i].Text = e and string.format("%d.  %s  -  Forge Lv %d", i, tostring(e.displayName), e.value) or string.format("%d.  -", i)
        end
    end
    task.spawn(function()
        while true do
            refresh()
            task.wait(60)
        end
    end)
end

function WorldBuilder.Build()
    if workspace:FindFirstChild("EmberWorld") then return end

    -- Clear the default template
    local base = workspace:FindFirstChild("Baseplate")
    if base then base:Destroy() end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("SpawnLocation") then obj:Destroy() end
    end

    local world = Instance.new("Folder")
    world.Name = "EmberWorld"
    world.Parent = workspace

    BuildCave(world)
    BuildRoads(world)

    -- Spawn
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "EmberSpawn"
    spawn.Anchored = true
    spawn.Size = Vector3.new(14, 1, 14)
    spawn.Position = Vector3.new(0, 0.5, -60)
    spawn.Material = Enum.Material.Basalt
    spawn.Color = Color3.fromRGB(45, 35, 30)
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Parent = world

    Sign(world, "Welcome to EmberForge",
        "1) Stand on the Starter Pad  2) Press E at the Golem Anvil to forge a Golem  3) Deploy it in the Forge menu",
        Vector3.new(0, 22, -60), Color3.fromRGB(255, 170, 60))

    BuildStarterStation(world)
    BuildPadPlaza(world)
    BuildDiscoveryBoard(world)

    for i, layout in ipairs(ZONE_LAYOUT) do
        BuildLandmark(world, i, layout)
        BuildChamber(world, i, layout)
    end

    BuildScenery(world)

    -- Lighting: a lit cavern (no sun reaches in, so the ambient light does the work)
    Lighting.ClockTime = 14
    Lighting.Brightness = 1
    Lighting.Ambient = Color3.fromRGB(125, 108, 100)
    Lighting.OutdoorAmbient = Color3.fromRGB(125, 108, 100)
    Lighting.GlobalShadows = false
    if not Lighting:FindFirstChildOfClass("Atmosphere") then
        local atm = Instance.new("Atmosphere")
        atm.Density = 0.22
        atm.Color = Color3.fromRGB(190, 150, 120)
        atm.Decay = Color3.fromRGB(120, 60, 40)
        atm.Haze = 1.2
        atm.Parent = Lighting
    end
end

return WorldBuilder
