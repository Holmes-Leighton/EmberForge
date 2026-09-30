-- Builds the shared world at runtime (no manual Studio work needed):
-- ground, spawn, mining-zone landmarks, scenery and lighting.
-- Forge plots are built separately by ForgeZoneService along the X axis at Z = 0.

local Lighting = game:GetService("Lighting")
local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)

local WorldBuilder = {}

local ZONE_LAYOUT = {   -- order matches the row of landmarks
    { id = "EmberDepths",     color = Color3.fromRGB(255, 110, 40)  },
    { id = "GraniteCaverns",  color = Color3.fromRGB(150, 140, 130) },
    { id = "GlacialPeaks",    color = Color3.fromRGB(140, 210, 255) },
    { id = "StormriftCliffs", color = Color3.fromRGB(190, 160, 255) },
    { id = "TheHollow",       color = Color3.fromRGB(120, 60, 200)  },
    { id = "TheDeepForge",    color = Color3.fromRGB(255, 200, 60)  },
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

local function BuildLandmark(world, index, layout)
    local zone = MiningZoneData.Zones[layout.id]
    if not zone then return end
    local cx = (index - 3.5) * ZONE_SPACING
    local model = Instance.new("Model")
    model.Name = "Zone_" .. layout.id
    model.Parent = world

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
