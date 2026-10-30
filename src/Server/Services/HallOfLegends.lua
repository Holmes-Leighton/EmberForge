-- The Hall of Legends: three giant statues of the Golems everyone is chasing, beside the spawn so a new player sees them in their first ten seconds. Each has a plaque that
-- says what it is and how to get it. (Top games put the dream item in the hub: you always know what you are playing towards.)
-- The statues are built from the real Golem models; if a mesh has not loaded yet they start as blocks and are rebuilt when it does.
local CollectionService = game:GetService("CollectionService")

local GolemModel = require(game.ReplicatedStorage.Shared.Modules.GolemModel)

local HallOfLegends = {}

-- The hall has its own plaza east of the spawn: a paved floor with a lit edge, the three statues in a row 36 studs apart (each statue's glowing ring is 21 wide, so they never touch),
-- and the scenery scatter kept out of it (WorldBuilder reads HallOfLegends.AREA). The box sits clear of the forge plots (|z| < 62), the pad plaza (z < -105) and the spawn
-- (x < 7), and short of the Cart Run road that starts near x = 160; tests check it against the cart routes too. It faces the spawn, a long way off but visible: the beams are 70 studs tall.
HallOfLegends.AREA = { x1 = 40, x2 = 146, z1 = -104, z2 = -66 }
HallOfLegends.CENTRE = { x = 93, z = -85 }
HallOfLegends.SPACING = 36
HallOfLegends.FACING = { x = 0, z = -60 }

HallOfLegends.Statues = {
    { id = "Supreme", dx = 0, dz = 0, scale = 2.4, element = "Void", tier = 4, options = { variant = "MegaNeon", stage = "Ancient" },
      title = "SUPREME GOLEM", how = "Fuse four Elite Golems, which come from fusing four Golems of the same kind.", color = Color3.fromRGB(190, 120, 255) },
    { id = "Maze", dx = -36, dz = 0, scale = 1.9, element = "Maze", tier = 5, options = { stage = "Ancient" },
      title = "MAZE GOLEM", how = "Earn its pieces by escaping the Hollow Maze. Rare, but worth every run.", color = Color3.fromRGB(110, 230, 140) },
    { id = "Primordial", dx = 36, dz = 0, scale = 1.9, element = "All", tier = 5, options = { stage = "Ancient" },
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

-- A floating label sized in STUDS (a scale size on a billboard), not pixels: a pixel-sized label stays the same width on screen however far away you are, so from a distance
-- three of them side by side overlapped each other (and the statues behind). In studs they shrink with distance like everything else, and stay inside their own statue's width.
-- `lines` = { { text, colour, fraction of the height, font? } ... } stacked top to bottom.
local function Label(parent, anchor, lines, widthStuds, heightStuds, maxDistance)
    local gui = Instance.new("BillboardGui")
    gui.Adornee, gui.Size, gui.MaxDistance, gui.AlwaysOnTop = anchor, UDim2.fromScale(widthStuds, heightStuds), maxDistance or 150, false
    gui.Parent = anchor
    local y = 0
    for _, ln in ipairs(lines) do
        local lbl = Instance.new("TextLabel")
        lbl.Size, lbl.Position, lbl.BackgroundTransparency, lbl.Text = UDim2.new(1, 0, ln[3], 0), UDim2.new(0, 0, y, 0), 1, ln[1]
        lbl.TextColor3, lbl.TextStrokeTransparency, lbl.Font = ln[2], 0.2, ln[4] or Enum.Font.GothamBold
        lbl.TextScaled, lbl.TextWrapped = true, true
        lbl.Parent = gui
        y += ln[3]
    end
    return gui
end

HallOfLegends.PLAQUE_WIDTH = 32        -- studs: inside the 36 between statues, so neighbouring plaques never touch
HallOfLegends.PLAQUE_RANGE = 70        -- studs: seen from the spawn the three statues are in a line pointing at you, so their plaques would pile up; the banner shows from far off,
                                       -- the plaques only once you are close enough to be standing in front of them, where they are side by side

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

    -- the plaque: one label, floating just above the Golem's head (measured from the model, since the three are different sizes), its name over how to get it
    local top = plinthH + 11 + def.scale * 2.2
    if gm then
        local ok2, cf, size = pcall(function() return gm:GetBoundingBox() end)
        if ok2 and cf and size then top = math.max(top, cf.Position.Y + size.Y / 2) end
    end
    local plaqueH = 12
    local anchor = Part({ Name = "PlaqueAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(x, top + 2 + plaqueH / 2, z) }, group)
    Label(group, anchor, { { def.title, def.color, 0.34 }, { def.how, Color3.fromRGB(240, 232, 215), 0.66, Enum.Font.GothamMedium } }, HallOfLegends.PLAQUE_WIDTH, plaqueH, HallOfLegends.PLAQUE_RANGE)
    return group, gm, top + 2 + plaqueH
end

local state = { folder = nil, version = -1 }

local function BuildAll(parent)
    if state.folder then state.folder:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "HallOfLegends"
    folder.Parent = parent
    state.folder = folder
    local a = HallOfLegends.AREA
    local cx, cz = (a.x1 + a.x2) / 2, (a.z1 + a.z2) / 2
    local w, d = a.x2 - a.x1, a.z2 - a.z1
    Part({ Name = "HallFloor", Material = Enum.Material.Marble, Color = Color3.fromRGB(70, 64, 74), Size = Vector3.new(w, 0.5, d), CFrame = CFrame.new(cx, 0.25, cz) }, folder)
    for _, edge in ipairs({ a.z1 + 0.8, a.z2 - 0.8 }) do                                 -- a dashed run of gold light along the long edges, like the pad plaza's
        for x = a.x1 + 8, a.x2 - 8, 14 do
            Part({ Name = "HallEdge", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 100), Transparency = 0.25, Size = Vector3.new(7, 0.3, 0.9),
                CFrame = CFrame.new(x, 0.62, edge), CanCollide = false }, folder)
        end
    end
    for _, corner in ipairs({ { a.x1 + 3, a.z1 + 3 }, { a.x1 + 3, a.z2 - 3 }, { a.x2 - 3, a.z1 + 3 }, { a.x2 - 3, a.z2 - 3 } }) do      -- a lit pillar at each corner marks the area
        local post = Part({ Name = "HallPost", Material = Enum.Material.Slate, Color = Color3.fromRGB(86, 80, 90), Size = Vector3.new(3, 14, 3), CFrame = CFrame.new(corner[1], 7, corner[2]) }, folder)
        local lamp = Part({ Name = "HallLamp", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 205, 100), Size = Vector3.new(3.6, 1.6, 3.6), CFrame = CFrame.new(corner[1], 14.8, corner[2]), CanCollide = false }, folder)
        local light = Instance.new("PointLight")
        light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 205, 100), 34, 1.6
        light.Parent = lamp
    end
    local highest = 0
    for _, def in ipairs(HallOfLegends.Statues) do
        local _, _, plaqueTop = BuildStatue(folder, def)
        highest = math.max(highest, plaqueTop)
    end
    -- a banner over the whole hall, above the highest plaque so nothing sits in front of anything
    local c = HallOfLegends.CENTRE
    local bannerH = 13
    local anchor = Part({ Name = "HallBanner", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(c.x, highest + 12 + bannerH / 2, c.z) }, folder)
    Label(folder, anchor, { { "HALL OF LEGENDS", Color3.fromRGB(255, 226, 150), 0.6 }, { "What will you forge?", Color3.fromRGB(255, 240, 200), 0.4, Enum.Font.GothamMedium } }, 70, bannerH, 260)
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
