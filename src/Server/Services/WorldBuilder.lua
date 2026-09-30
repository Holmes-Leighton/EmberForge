-- Builds the shared world at runtime (no manual Studio work needed):
-- ground, spawn, mining-zone landmarks, scenery and lighting.
-- Forge plots are built separately by ForgeZoneService along the X axis at Z = 0.

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
        Size = Vector3.new(26, 26, 26), CFrame = CFrame.new(cx, 10, cz - 58) }, model)
    Part({ Name = "FurnaceGlow", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 50), Size = Vector3.new(9, 10, 1),
        CFrame = CFrame.new(cx, 6, cz - 45.5), CanCollide = false }, model)
    for _, dx in ipairs({ -12, 12 }) do
        local chimney = Part({ Name = "Chimney", Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 58, 62), Size = Vector3.new(4, 30, 4),
            CFrame = CFrame.new(cx + dx, 18, cz - 58) }, model)
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
    if props then props(model, cx, ZONE_Z, Random.new(index * 31), layout.color) end

    Sign(model, zone.displayName, UnlockText(zone), Vector3.new(cx, 36, ZONE_Z), layout.color)
end

local function BuildScenery(world)
    local rng = Random.new(2024)
    local folder = Instance.new("Folder")
    folder.Name = "Scenery"
    folder.Parent = world

    for _ = 1, 160 do
        local x = rng:NextInteger(-600, 1700)
        local z = rng:NextInteger(-380, 420)
        local inPlots   = math.abs(z) < 60
        local inZones   = z > ZONE_Z - 70 and z < ZONE_Z + 70 and x > -520 and x < 520
        local nearSpawn = math.abs(x) < 170 and z < -20 and z > -230
        if not (inPlots or inZones or nearSpawn) then
            if rng:NextNumber() < 0.6 then
                -- tree
                local trunkH = rng:NextInteger(8, 14)
                Part({ Name = "Trunk", Material = Enum.Material.Wood,
                    Color = Color3.fromRGB(90, 60, 40), Size = Vector3.new(2, trunkH, 2),
                    CFrame = CFrame.new(x, trunkH / 2, z) }, folder)
                Part({ Name = "Leaves", Shape = Enum.PartType.Ball, Material = Enum.Material.Grass,
                    Color = Color3.fromRGB(60, 110 + rng:NextInteger(0, 40), 60),
                    Size = Vector3.new(10, 10, 10) * rng:NextNumber(0.9, 1.4),
                    CFrame = CFrame.new(x, trunkH + 3, z) }, folder)
            else
                -- boulder
                local s = rng:NextInteger(4, 12)
                Part({ Name = "Rock", Material = Enum.Material.Slate,
                    Color = Color3.fromRGB(100, 100, 105), Size = Vector3.new(s, s * 0.7, s),
                    CFrame = CFrame.new(x, s * 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) }, folder)
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

    -- Ground (top surface at Y = 0)
    Part({
        Name = "Ground", Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 105, 60),
        Size = Vector3.new(2400, 2, 1100), CFrame = CFrame.new(550, -1, 40),
    }, world)

    -- Path from spawn to the first forge plot
    Part({
        Name = "Path", Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(120, 105, 90),
        Size = Vector3.new(12, 0.2, 2400), CFrame = CFrame.new(0, 0.1, 40),
    }, world).CanCollide = false

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
    BuildDiscoveryBoard(world)

    for i, layout in ipairs(ZONE_LAYOUT) do
        BuildLandmark(world, i, layout)
    end
    Sign(world, "Mining Zones", "Walk north to see where your Golems can work",
        Vector3.new(0, 24, ZONE_Z - 110), Color3.fromRGB(255, 200, 80))

    BuildScenery(world)

    -- Lighting: warm evening
    Lighting.ClockTime = 17.5
    Lighting.Brightness = 2.5
    Lighting.Ambient = Color3.fromRGB(90, 70, 60)
    Lighting.OutdoorAmbient = Color3.fromRGB(120, 100, 90)
    if not Lighting:FindFirstChildOfClass("Atmosphere") then
        local atm = Instance.new("Atmosphere")
        atm.Density = 0.3
        atm.Color = Color3.fromRGB(255, 190, 140)
        atm.Decay = Color3.fromRGB(120, 60, 40)
        atm.Haze = 1.2
        atm.Parent = Lighting
    end
end

return WorldBuilder
