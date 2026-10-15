-- Builds the Courier Run courses out of parts, from the geometry in CourierLayout. Everything here is static; the moving pieces carry tags and attributes that
-- CourierController (client) animates on the shared server clock, the same way as the Cart Run gates:
--   "EFCourierMover"    X0, X1, Period, Phase        slides between X0 and X1 (centre positions), sine-eased
--   "EFCourierSpinner"  Omega, Phase, CX, CZ, Y      a bar turning about (CX, CZ) at height Y
--   "EFCourierCrusher"  CourseId, Index, Lift        a block that rises Lift studs while the crusher is open (CartCourseData.HazardOpen, shared clock)
--   "EFCourierCrumble"  Delay, Respawn               drops away shortly after the local player stands on it, then comes back
-- Every piece is a separate named part, so a mesh can replace it later without touching the rules.
local CollectionService = game:GetService("CollectionService")

local SignArt = require(script.Parent.SignArt)

local CourierArt = {}

local TIER_LOOK = {
    [1] = { material = Enum.Material.Sandstone, color = Color3.fromRGB(176, 128, 88), rest = Color3.fromRGB(205, 160, 110) },
    [2] = { material = Enum.Material.Basalt,    color = Color3.fromRGB(96, 70, 62),   rest = Color3.fromRGB(140, 96, 70) },
    [3] = { material = Enum.Material.Slate,     color = Color3.fromRGB(70, 52, 56),   rest = Color3.fromRGB(110, 60, 56) },
}
local TIMBER = Color3.fromRGB(100, 70, 44)
local CRATE  = Color3.fromRGB(150, 108, 64)

local function P(props, parent)
    local p = Instance.new("Part")
    p.Anchored = true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = parent
    return p
end

local function Sign(parent, adornee, text, size, offset, color, maxDistance)
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Adornee, gui.Size, gui.StudsOffset, gui.MaxDistance = "Sign", adornee, size, offset, maxDistance or 120
    gui.Parent = adornee
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Text"
    lbl.Size, lbl.BackgroundTransparency, lbl.Text = UDim2.new(1, 0, 1, 0), 1, text
    lbl.TextColor3, lbl.TextStrokeTransparency, lbl.Font = color or Color3.fromRGB(255, 232, 170), 0.2, Enum.Font.GothamBold
    lbl.TextScaled, lbl.TextWrapped = true, true
    lbl.Parent = gui
    return lbl
end

local function Clock(seconds)
    seconds = math.floor(seconds)
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ── Platforms ─────────────────────────────────────────────────────────────────
local function BuildPlatforms(folder, r)
    local def, L = r.def, r.layout
    local look = def.look or TIER_LOOK[def.tier]
    local accent = def.color or Color3.fromRGB(255, 190, 80)
    local group = Instance.new("Folder")
    group.Name = "Platforms"
    group.Parent = folder
    local function trim(p, top)
        for _, side in ipairs({ -1, 1 }) do                         -- glowing edges so the platforms read at a glance, even from a distance
            P({ Name = "Trim", Material = Enum.Material.Neon, Color = accent, Size = Vector3.new(p.sx, 0.3, 0.4), CanCollide = false,
                CFrame = CFrame.new(p.x, top + 0.15, p.z + side * (p.sz / 2 - 0.2)) }, group)
        end
    end
    for _, p in ipairs(L.platforms) do
        local top = p.y + p.sy / 2
        local isRest = p.sx >= 18
        local part = P({ Name = isRest and "RestPlatform" or "Platform", Material = look.material, Color = isRest and look.rest or look.color,
            Size = Vector3.new(p.sx, p.sy, p.sz), CFrame = CFrame.new(p.x, p.y, p.z) }, group)
        if p.ice then                                                -- slippery: almost no friction
            part.Material, part.Color = Enum.Material.Ice, Color3.fromRGB(170, 225, 255)
            part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.02, 0, 100, 1)
        elseif p.conveyor then                                       -- a belt: an anchored part with a velocity carries whatever stands on it
            part.Name, part.Material, part.Color = "ConveyorBelt", Enum.Material.DiamondPlate, Color3.fromRGB(60, 60, 68)
            part.AssemblyLinearVelocity = Vector3.new(p.conveyor, 0, 0)
            for k = -1, 1 do                                         -- arrows showing which way it runs
                P({ Name = "BeltArrow", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 60), Size = Vector3.new(2.6, 0.2, 1.4), CanCollide = false,
                    CFrame = CFrame.new(p.x + k * (p.sx / 3), p.y + p.sy / 2 + 0.12, p.z) }, group)
            end
            part:SetAttribute("BeltSpeed", p.conveyor)
        end
        if p.pipe then                                               -- a round steel pipe: a cylinder along the course, with bolted flanges at the ends
            part.Shape = Enum.PartType.Block
            part.Transparency = 1
            part.CanCollide = false
            local dia = math.max(p.sz, 2.4)
            local pipe = P({ Name = "PipeWalk", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(140, 146, 158), Reflectance = 0.1,
                Size = Vector3.new(p.sx, dia, dia), CFrame = CFrame.new(p.x, top - dia / 2, p.z) }, group)
            for _, end_ in ipairs({ -1, 1 }) do
                P({ Name = "PipeFlange", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 190, 60), Size = Vector3.new(0.8, dia + 1.2, dia + 1.2),
                    CanCollide = false, CFrame = CFrame.new(p.x + end_ * (p.sx / 2 - 0.4), top - dia / 2, p.z) }, group)
            end
            for k = 1, math.max(1, math.floor(p.sx / 8)) do          -- a yellow hazard band every few studs
                P({ Name = "PipeBand", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = accent, Size = Vector3.new(0.7, dia + 0.3, dia + 0.3),
                    CanCollide = false, CFrame = CFrame.new(p.x - p.sx / 2 + (p.sx / (math.floor(p.sx / 8) + 1)) * k, top - dia / 2, p.z) }, group)
            end
            pipe.CanCollide = true
            part:Destroy()
            part = pipe
        else
            trim(p, top)
        end
        if look.scaffold and not p.pipe and not p.conveyor then       -- scaffold-style: cross-beams under the planks, and on the big platforms pipe railings
            for k = 1, math.max(2, math.floor(p.sx / 6)) do
                P({ Name = "CrossBeam", Material = Enum.Material.SmoothPlastic, Color = look.beam or Color3.fromRGB(96, 102, 114), Size = Vector3.new(0.9, 0.9, p.sz + 0.4), CanCollide = false,
                    CFrame = CFrame.new(p.x - p.sx / 2 + (p.sx / (math.max(2, math.floor(p.sx / 6)) + 1)) * k, p.y - p.sy / 2 - 0.5, p.z) }, group)
            end
            if isRest then
                for _, side in ipairs({ -1, 1 }) do
                    local zr = p.z + side * (p.sz / 2 - 0.5)
                    P({ Name = "RailPipe", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(255, 200, 60), Size = Vector3.new(p.sx - 4, 0.7, 0.7),
                        CanCollide = false, CFrame = CFrame.new(p.x, top + 3.4, zr) }, group)
                    for k = 0, math.floor((p.sx - 4) / 7) do
                        P({ Name = "RailPost", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = Color3.fromRGB(110, 116, 128), Size = Vector3.new(3.4, 0.7, 0.7),
                            CanCollide = false, CFrame = CFrame.new(p.x - (p.sx - 4) / 2 + k * 7, top + 1.7, zr) * CFrame.Angles(0, 0, math.pi / 2) }, group)
                    end
                end
            end
        end
        if isRest and p.y < 150 then                                -- rest platforms stand on pillars (the Sky Tower, high up, floats); the small ones float
            for _, dz in ipairs({ -p.sz / 2 + 3, p.sz / 2 - 3 }) do
                local h = p.y - p.sy / 2
                P({ Name = "Pillar", Material = Enum.Material.Basalt, Color = Color3.fromRGB(58, 42, 38), Size = Vector3.new(4, h, 4), CFrame = CFrame.new(p.x, h / 2, p.z + dz) }, group)
            end
        end
    end
    for i, m in ipairs(L.movers) do
        local part = P({ Name = "MovingPlatform", Material = Enum.Material.Metal, Color = accent, Size = Vector3.new(m.sx, m.sy, m.sz), CFrame = CFrame.new(m.x0, m.y, m.z) }, group)
        part:SetAttribute("X0", m.x0)
        part:SetAttribute("X1", m.x1)
        part:SetAttribute("Period", m.period)
        part:SetAttribute("Phase", m.phase)
        part:SetAttribute("CourseId", r.id)
        CollectionService:AddTag(part, "EFCourierMover")
    end
    for i, c in ipairs(L.crumbles) do
        local part = P({ Name = "CrumblingPlatform", Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 120, 100), Size = Vector3.new(c.sx, c.sy, c.sz), CFrame = CFrame.new(c.x, c.y, c.z) }, group)
        part:SetAttribute("Delay", c.delay)
        part:SetAttribute("Respawn", c.respawn)
        part:SetAttribute("CourseId", r.id)
        CollectionService:AddTag(part, "EFCourierCrumble")
        local crack = P({ Name = "Cracks", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 60), Size = Vector3.new(c.sx * 0.6, 0.12, 0.3), CanCollide = false,
            CFrame = CFrame.new(c.x, c.y + c.sy / 2 + 0.06, c.z) }, group)
        crack.Parent = part                                       -- (moves and vanishes with the platform: the client carries children along)
    end
end

-- ── Spinners and crushers ─────────────────────────────────────────────────────
local function BuildObstacles(folder, r)
    local L = r.layout
    local group = Instance.new("Folder")
    group.Name = "Obstacles"
    group.Parent = folder
    for i, sp in ipairs(L.spinners) do
        P({ Name = "SpinnerHub", Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 56, 64), Size = Vector3.new(3, sp.barY + 2, 3),
            CFrame = CFrame.new(sp.x, sp.y + (sp.barY + 2) / 2, sp.z) }, group)
        local bar = P({ Name = "SpinnerBar", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 80, 60), Size = Vector3.new(sp.radius * 2, sp.thick, sp.thick), CanCollide = true,
            CFrame = CFrame.new(sp.x, sp.y + sp.barY, sp.z) * CFrame.Angles(0, -sp.phase, 0) }, group)
        bar:SetAttribute("Omega", sp.omega)
        bar:SetAttribute("Phase", sp.phase)
        bar:SetAttribute("CX", sp.x)
        bar:SetAttribute("CZ", sp.z)
        bar:SetAttribute("Y", sp.y + sp.barY)
        CollectionService:AddTag(bar, "EFCourierSpinner")
    end
    for _, k in ipairs(L.kills or {}) do                              -- a deadly tile: glowing red with a dark cross, flush with the floor
        P({ Name = "DeathTile", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 36, 36), Size = Vector3.new(k.sx, 0.4, k.sz), CanCollide = false,
            CFrame = CFrame.new(k.x, k.y + 0.2, k.z) }, group)
        for _, rot in ipairs({ math.pi / 4, -math.pi / 4 }) do
            P({ Name = "DeathCross", Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(50, 0, 0), Size = Vector3.new(k.sx * 0.9, 0.45, 0.7), CanCollide = false,
                CFrame = CFrame.new(k.x, k.y + 0.24, k.z) * CFrame.Angles(0, rot, 0) }, group)
        end
    end
    for _, tr in ipairs(L.trusses or {}) do                          -- a ladder: a real truss, which characters climb
        local truss = Instance.new("TrussPart")
        truss.Name = "Ladder"
        truss.Anchored = true
        truss.Size = Vector3.new(2, tr.height, 2)
        truss.CFrame = CFrame.new(tr.x, tr.y + tr.height / 2, tr.z)
        truss.Color = Color3.fromRGB(255, 200, 80)
        truss.Parent = group
        Sign(group, truss, "CLIMB!", UDim2.new(0, 110, 0, 28), Vector3.new(0, tr.height / 2 + 3, 0), Color3.fromRGB(255, 232, 150), 90)
    end
    for _, b in ipairs(L.bounces or {}) do
        local pad = P({ Name = "BouncePad", Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 255, 140), Size = Vector3.new(b.sx, 0.6, b.sz),
            CFrame = CFrame.new(b.x, b.y + 0.3, b.z) }, group)
        pad:SetAttribute("Power", b.power)
        pad:SetAttribute("HSpeed", b.hspeed or 28)
        pad:SetAttribute("Dir", b.dir or 1)
        CollectionService:AddTag(pad, "EFCourierBounce")
        Sign(group, pad, "BOUNCE", UDim2.new(0, 110, 0, 28), Vector3.new(0, 4, 0), Color3.fromRGB(150, 255, 190), 80)
    end
    for _, s in ipairs(L.sweepers or {}) do
        local bar = P({ Name = "SweeperBar", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 70, 60), Size = Vector3.new(s.thick or 1.6, 3.2, 3.4),
            CFrame = CFrame.new(s.x, s.y + 1.6, s.z) }, group)
        bar:SetAttribute("Amp", s.amp)
        bar:SetAttribute("Period", s.period)
        bar:SetAttribute("Phase", s.phase)
        bar:SetAttribute("Z0", s.z)
        bar:SetAttribute("Y", s.y + 1.6)
        bar:SetAttribute("X", s.x)
        CollectionService:AddTag(bar, "EFCourierSweeper")
    end
    for i, c in ipairs(L.crushers) do
        -- the danger zone on the floor, and the block above it (closed = down on the floor, open = raised clear)
        P({ Name = "CrusherZone", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 40), Transparency = 0.45, Size = Vector3.new(c.sx, 0.15, c.sz), CanCollide = false,
            CFrame = CFrame.new(c.x, c.y + 0.08, c.z) }, group)
        local unit = Instance.new("Model")
        unit.Name = "Crusher" .. i
        local block = P({ Name = "CrusherBlock", Material = Enum.Material.Metal, Color = Color3.fromRGB(78, 72, 80), Size = Vector3.new(c.sx, c.height, c.sz),
            CFrame = CFrame.new(c.x, c.y + c.height / 2, c.z) }, unit)
        P({ Name = "CrusherStripe", Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 40), Size = Vector3.new(c.sx + 0.2, 1, c.sz + 0.2), CanCollide = false,
            CFrame = CFrame.new(c.x, c.y + 1.5, c.z) }, unit)
        unit.PrimaryPart = block
        unit:SetAttribute("Open", c.open)
        unit:SetAttribute("Closed", c.closed)
        unit:SetAttribute("Phase", c.phase)
        unit:SetAttribute("Lift", c.height + 3)
        unit:SetAttribute("CourseId", r.id)
        unit.Parent = group
        CollectionService:AddTag(unit, "EFCourierCrusher")
    end
end

-- ── Checkpoint flags, start station, drop-off, access ramp ────────────────────
local function BuildFlags(folder, r)
    local accent = r.def.color or Color3.fromRGB(255, 190, 80)
    for i, cp in ipairs(r.layout.checkpoints) do
        if i > 1 then
            local side = cp.z + 9
            P({ Name = "FlagPole", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(0.7, 12, 0.7), CFrame = CFrame.new(cp.x, cp.y - 3 + 6, side), CanCollide = false }, folder)
            local flag = P({ Name = "CheckpointFlag", Material = Enum.Material.Neon, Color = accent, Size = Vector3.new(0.3, 3, 5), CanCollide = false,
                CFrame = CFrame.new(cp.x, cp.y - 3 + 10, side - 2.6) }, folder)
            Sign(folder, flag, "Checkpoint " .. (i - 1), UDim2.new(0, 140, 0, 30), Vector3.new(0, 3, 0), Color3.fromRGB(255, 255, 255), 70)
        end
    end
end

local function BuildStart(folder, r)
    local def, L = r.def, r.layout
    local accent = def.color or Color3.fromRGB(255, 190, 80)
    local cp = L.checkpoints[1]
    local floorY = cp.y - 3
    -- a pile of crates: step up to it and "Pick up freight"
    local pile = Instance.new("Model")
    pile.Name = "CratePile"
    local spots = { { 0, 0 }, { 3.2, 0 }, { 1.6, 0.0 }, { 0, 3.2 }, { 3.2, 3.2 } }
    local main
    for i, s in ipairs(spots) do
        local part = P({ Name = "Crate", Material = Enum.Material.Wood, Color = CRATE, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(cp.x - 6 + s[1], floorY + 1.5 + (i == 3 and 3 or 0), cp.z + 6 + s[2]) }, pile)
        main = main or part
    end
    P({ Name = "CrateStripe", Material = Enum.Material.Neon, Color = accent, Size = Vector3.new(3.2, 0.5, 3.2), CanCollide = false, CFrame = CFrame.new(cp.x - 6, floorY + 1.7, cp.z + 6) }, pile)
    pile.PrimaryPart = main
    pile:SetAttribute("CourseId", r.id)
    pile.Parent = folder
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "CourierPickup"
    prompt.ActionText = "Pick up freight"
    prompt.ObjectText = def.name
    prompt.HoldDuration = 0.4
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Parent = main
    -- the sign
    local post = Vector3.new(cp.x - 6, floorY, cp.z - 8)
    SignArt.Post(P({ Name = "SignPost", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(2, 14, 2), CFrame = CFrame.new(post + Vector3.new(0, 7, 0)) }, folder))
    local anchor = P({ Name = "SignAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(post + Vector3.new(0, 16, 0)) }, folder)
    local text = string.format("COURIER RUN: %s\n%s  Player level %d+   Courier Level %d+\nPar %s%s", def.name, string.rep("*", def.tier) .. string.rep("-", 3 - def.tier),
        def.minLevel, def.minCourier, Clock(r.par), def.lava and "   Lava chase!" or "")
    Sign(folder, anchor, text, UDim2.new(0, 340, 0, 100), Vector3.new(0, 0, 0), accent, 110)
    P({ Name = "StartBeam", Material = Enum.Material.Neon, Color = accent, Transparency = 0.65, Size = Vector3.new(3, 70, 3), CanCollide = false,
        CFrame = CFrame.new(post + Vector3.new(0, 35, 0)) }, folder)
end

local function BuildFinish(folder, r)
    local def, L = r.def, r.layout
    local accent = def.color or Color3.fromRGB(255, 190, 80)
    local f = L.finish
    local floorY = f.y - 3
    local disc = P({ Name = "DropOffRing", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = accent, Transparency = 0.3, Size = Vector3.new(0.4, 16, 16),
        CanCollide = false, CFrame = CFrame.new(f.x, floorY + 0.25, f.z) * CFrame.Angles(0, 0, math.pi / 2) }, folder)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = accent, 45, 2
    light.Parent = disc
    P({ Name = "DropOffBeam", Material = Enum.Material.Neon, Color = accent, Transparency = 0.7, Size = Vector3.new(4, 60, 4), CanCollide = false, CFrame = CFrame.new(f.x, floorY + 30, f.z) }, folder)
    for _, dz in ipairs({ -9, 9 }) do
        P({ Name = "ArchPost", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(f.x + 8, floorY + 9, f.z + dz) }, folder)
    end
    local beam = P({ Name = "ArchBeam", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(2, 2.4, 22), CFrame = CFrame.new(f.x + 8, floorY + 19, f.z) }, folder)
    Sign(folder, beam, "DROP-OFF", UDim2.new(0, 200, 0, 46), Vector3.new(0, 3.5, 0), accent, 140)
end

-- A ramp from the cavern floor up to the start platform (the courses are raised so a fall is obvious)
local function BuildRamp(folder, r)
    local L = r.layout
    local base, cp = L.base, L.checkpoints[1]
    local run = 40
    local rise = base.y
    local len = math.sqrt(run * run + rise * rise)
    local theta = math.atan2(rise, run)
    local midX, midY = base.x - run / 2, rise / 2
    local cf = CFrame.new(midX + math.sin(theta) * 1, midY - math.cos(theta) * 1, cp.z) * CFrame.Angles(0, 0, theta)
    local look = TIER_LOOK[r.def.tier]
    P({ Name = "AccessRamp", Material = look.material, Color = look.rest, Size = Vector3.new(len + 0.6, 2, 16), CFrame = cf }, folder)
    for _, side in ipairs({ -1, 1 }) do
        P({ Name = "RampRail", Material = Enum.Material.Wood, Color = TIMBER, Size = Vector3.new(len, 0.6, 0.6), CanCollide = false,
            CFrame = CFrame.new(midX, midY + 2.6, cp.z + side * 8) * CFrame.Angles(0, 0, theta) }, folder)
    end
end

-- The pieces, for other builders (the Sky Tower builds each of its levels from these)
CourierArt.Platforms = BuildPlatforms
CourierArt.Obstacles = BuildObstacles
CourierArt.Finish = BuildFinish
CourierArt.P = P
CourierArt.Sign = Sign

-- Builds one course's scenery under `parent`. Returns the folder.
function CourierArt.Build(parent, r)
    local folder = Instance.new("Folder")
    folder.Name = "Courier_" .. r.id
    BuildPlatforms(folder, r)
    BuildObstacles(folder, r)
    BuildFlags(folder, r)
    BuildStart(folder, r)
    BuildFinish(folder, r)
    BuildRamp(folder, r)
    folder.Parent = parent
    return folder
end

return CourierArt
