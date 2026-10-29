-- The Hall of Legends: three giant statues of the Golems everyone is chasing, beside the spawn so a new player sees them in their first ten seconds. Each has a plaque that
-- says what it is and how to get it. (Top games put the dream item in the hub: you always know what you are playing towards.)
-- The statues are built from the real Golem models; if a mesh has not loaded yet they start as blocks and are rebuilt when it does.
local CollectionService = game:GetService("CollectionService")

local GolemModel = require(game.ReplicatedStorage.Shared.Modules.GolemModel)

local HallOfLegends = {}

-- Spawn is at (0, 0.5, -60) and the hub keeps scenery off |x| < 60, -105 < z < -20 (WorldBuilder). The hall sits east of the spawn road, inside that clear patch, facing the spawn.
HallOfLegends.CENTRE = { x = 34, z = -86 }
HallOfLegends.FACING = { x = 0, z = -60 }

HallOfLegends.Statues = {
    { id = "Supreme", dx = 0, dz = -4, scale = 2.4, element = "Void", tier = 4, options = { variant = "MegaNeon", stage = "Ancient" },
      title = "SUPREME GOLEM", how = "Fuse four Elite Golems, which come from fusing four Golems of the same kind.", color = Color3.fromRGB(190, 120, 255) },
    { id = "Maze", dx = -18, dz = 6, scale = 1.9, element = "Maze", tier = 5, options = { stage = "Ancient" },
      title = "MAZE GOLEM", how = "Earn its pieces by escaping the Hollow Maze. Rare, but worth every run.", color = Color3.fromRGB(110, 230, 140) },
    { id = "Primordial", dx = 18, dz = 6, scale = 1.9, element = "All", tier = 5, options = { stage = "Ancient" },
      title = "PRIMORDIAL GOLEM", how = "The rarest Golem of all. Its blueprint comes from seasonal events.", color = Color3.fromRGB(255, 210, 90) },
}

local function Part(props, parent)
    local p = Instance.new("Part")
    p.Anchored = true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = parent
    return p
end

local function Label(parent, anchor, text, size, color, maxDistance)
    local gui = Instance.new("BillboardGui")
    gui.Adornee, gui.Size, gui.MaxDistance, gui.AlwaysOnTop = anchor, size, maxDistance or 150, false
    gui.Parent = anchor
    local lbl = Instance.new("TextLabel")
    lbl.Size, lbl.BackgroundTransparency, lbl.Text = UDim2.new(1, 0, 1, 0), 1, text
    lbl.TextColor3, lbl.TextStrokeTransparency, lbl.Font = color, 0.2, Enum.Font.GothamBold
    lbl.TextScaled, lbl.TextWrapped = true, true
    lbl.Parent = gui
    return lbl
end

-- One statue: a marble plinth with a glowing ring, the Golem standing on it, a beam of light overhead and a plaque. Returns the model (the Golem may be nil if it could not be built).
local function BuildStatue(parent, def)
    local c = HallOfLegends.CENTRE
    local x, z = c.x + def.dx, c.z + def.dz
    local group = Instance.new("Model")
    group.Name = "Statue_" .. def.id
    group.Parent = parent
    local plinthH = 3
    Part({ Name = "Plinth", Material = Enum.Material.Marble, Color = Color3.fromRGB(86, 80, 90), Size = Vector3.new(15, plinthH, 15), CFrame = CFrame.new(x, plinthH / 2, z) }, group)
    Part({ Name = "PlinthTop", Material = Enum.Material.Neon, Color = def.color, Size = Vector3.new(15.4, 0.4, 15.4), CFrame = CFrame.new(x, plinthH + 0.2, z), Transparency = 0.5, CanCollide = false }, group)
    local ring = Part({ Name = "StatueRing", Material = Enum.Material.Neon, Color = def.color, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 21, 21),
        CFrame = CFrame.new(x, 0.45, z) * CFrame.Angles(0, 0, math.pi / 2), CanCollide = false, Transparency = 0.3 }, group)
    ring:SetAttribute("PulseLo", 0.25)
    ring:SetAttribute("PulseHi", 0.8)
    ring:SetAttribute("PulseSpeed", 1.2)
    CollectionService:AddTag(ring, "EFPulse")
    local beam = Part({ Name = "StatueBeam", Material = Enum.Material.Neon, Color = def.color, Transparency = 0.82, Size = Vector3.new(6, 70, 6), CFrame = CFrame.new(x, 40, z), CanCollide = false }, group)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = def.color, 46, 2.2
    light.Parent = beam
    local sparks = Instance.new("ParticleEmitter")
    sparks.Color = ColorSequence.new(def.color)
    sparks.Rate, sparks.Lifetime, sparks.Speed = 10, NumberRange.new(2, 3.5), NumberRange.new(3, 8)
    sparks.SpreadAngle = Vector2.new(30, 30)
    sparks.Size = NumberSequence.new(0.7, 0)
    sparks.LightEmission = 1
    sparks.Parent = beam

    -- the Golem itself, facing the spawn
    local ok, gm = pcall(function() return GolemModel.Build(def.element, def.tier, def.options) end)
    if ok and gm then
        gm.Name = "StatueGolem"
        for _, d in ipairs(gm:GetDescendants()) do
            if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
        end
        pcall(function() gm:ScaleTo(def.scale) end)
        local f = HallOfLegends.FACING
        local look = Vector3.new(f.x - x, 0, f.z - z)
        pcall(function() gm:PivotTo(CFrame.lookAt(Vector3.new(x, plinthH + 4.2 * def.scale / 1.4, z), Vector3.new(x + look.X, plinthH + 4.2 * def.scale / 1.4, z + look.Z)) * CFrame.Angles(0, math.pi, 0)) end)
        gm.Parent = group
    end

    -- the plaque
    local anchor = Part({ Name = "PlaqueAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(x, plinthH + 11 + def.scale * 2.2, z) }, group)
    Label(group, anchor, def.title, UDim2.new(0, 360, 0, 58), def.color, 170)
    local anchor2 = Part({ Name = "HowAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(x, plinthH + 6, z) }, group)
    Label(group, anchor2, def.how, UDim2.new(0, 330, 0, 64), Color3.fromRGB(240, 232, 215), 60)
    return group, gm
end

local state = { folder = nil, version = -1 }

local function BuildAll(parent)
    if state.folder then state.folder:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "HallOfLegends"
    folder.Parent = parent
    state.folder = folder
    for _, def in ipairs(HallOfLegends.Statues) do BuildStatue(folder, def) end
    -- a banner over the whole hall
    local c = HallOfLegends.CENTRE
    local anchor = Part({ Name = "HallBanner", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(c.x, 38, c.z + 4) }, folder)
    Label(folder, anchor, "HALL OF LEGENDS\nWhat will you forge?", UDim2.new(0, 520, 0, 110), Color3.fromRGB(255, 226, 150), 220)
    return folder
end

function HallOfLegends.Build(parent)
    return BuildAll(parent)
end

function HallOfLegends.Folder() return state.folder end

-- Builds the hall under `world`, and rebuilds it whenever more Golem art has finished loading (so the statues are meshes, not blocks).
function HallOfLegends.Init(world)
    BuildAll(world)
    state.version = GolemModel.AssetVersion()
    task.spawn(function()
        while true do
            task.wait(4)
            local v = GolemModel.AssetVersion()
            if v ~= state.version and world.Parent then
                state.version = v
                local ok, err = pcall(BuildAll, world)
                if not ok then warn("[HallOfLegends] " .. tostring(err)) end
            end
        end
    end)
end

return HallOfLegends
