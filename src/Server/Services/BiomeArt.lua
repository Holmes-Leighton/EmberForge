-- Hand-built scenery for the mining zones: each piece is a Model of many shaped parts (crystals with glowing cores, waterfalls of ice,
-- snowy pines ...), far richer than the single blocks it replaces. Pieces that should move carry the tag "EFAnim" and attributes read by
-- the client (GolemAnimator): AnimKind = bob | spin | bobspin | sway | pulse, AnimSpeed (radians per second), AnimAmp (studs or radians) and
-- AnimPhase, so a field of them never moves in lockstep. Built from parts (not uploaded meshes) so it always loads, can be recoloured per
-- zone, and animates for free. BiomeArt.GlacialPeaks is the first zone done this way.

local CollectionService = game:GetService("CollectionService")
local CartCourseData = require(game.ReplicatedStorage.Shared.Data.CartCourseData)

local BiomeArt = {}

local ICE      = Color3.fromRGB(150, 205, 250)
local ICE_DEEP = Color3.fromRGB(90, 160, 230)
local GLOW     = Color3.fromRGB(170, 245, 255)
local SNOW     = Color3.fromRGB(245, 250, 255)
local ROCK     = Color3.fromRGB(72, 86, 108)
local PINE     = Color3.fromRGB(32, 78, 58)
local TRUNK    = Color3.fromRGB(92, 62, 42)

local function P(parent, props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CastShadow = false
    for k, v in pairs(props) do p[k] = v end
    p.Parent = parent
    return p
end

local function Wedge(parent, props)
    local w = Instance.new("WedgePart")
    w.Anchored = true
    w.CanCollide = false
    w.TopSurface = Enum.SurfaceType.Smooth
    w.BottomSurface = Enum.SurfaceType.Smooth
    w.CastShadow = false
    for k, v in pairs(props) do w[k] = v end
    w.Parent = parent
    return w
end

-- Marks an instance (a Model or a part) to be animated by the client
local function Animate(inst, kind, speed, amp, phase)
    inst:SetAttribute("AnimKind", kind)
    inst:SetAttribute("AnimSpeed", speed)
    inst:SetAttribute("AnimAmp", amp)
    inst:SetAttribute("AnimPhase", phase or 0)
    CollectionService:AddTag(inst, "EFAnim")
end

-- A square pyramid from four wedges: base width w, height h, base centre at `cf`, apex straight up (flip with a rotation for a downward point)
local function Pyramid(parent, cf, w, h, props)
    for k = 0, 3 do
        local side = cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h / 2, w / 4) * CFrame.Angles(0, math.pi, 0)
        local p = { Size = Vector3.new(w, h, w / 2), CFrame = side }
        for key, v in pairs(props) do p[key] = v end
        Wedge(parent, p)
    end
end

-- One ice crystal standing on `cf`: a glassy shaft, a pointed tip and a glowing core. Returns the top of the crystal (a world position).
local function Crystal(parent, cf, w, h, tint, glow)
    local shaftH = h * 0.7
    local tipH = h * 0.3
    P(parent, { Name = "Shaft", Material = Enum.Material.Glass, Color = tint, Transparency = 0.3,
        Size = Vector3.new(w, shaftH, w), CFrame = cf * CFrame.new(0, shaftH / 2, 0) })
    Pyramid(parent, cf * CFrame.new(0, shaftH, 0), w, tipH, { Material = Enum.Material.Glass, Color = tint, Transparency = 0.3 })
    local core = P(parent, { Name = "Core", Material = Enum.Material.Neon, Color = glow or GLOW, Transparency = 0.45,
        Size = Vector3.new(w * 0.35, h * 0.8, w * 0.35), CFrame = cf * CFrame.new(0, h * 0.4, 0) })
    return core
end

local function Rock(parent, cf, size, snowCap)
    P(parent, { Name = "Rock", Material = Enum.Material.Slate, Color = ROCK, Size = size, CFrame = cf })
    if snowCap then
        P(parent, { Name = "Snow", Material = Enum.Material.Snow, Color = SNOW, Size = Vector3.new(size.X * 1.02, size.Y * 0.3, size.Z * 1.02),
            CFrame = cf * CFrame.new(0, size.Y * 0.42, 0) })
    end
end

-- ── Real meshes (when the zone's art pack is loaded) ──────────────────────────
-- Each piece first tries a generated mesh from ServerStorage.BiomeAssets.<Zone> (loaded by GolemAssetLoader from the asset ids in AssetData.BiomeMeshes)
-- and only builds itself from parts when there is none.
-- A mesh arrives about 2 studs across, so it is scaled to a target height (or width) and stood on the ground (or centred, for floating pieces).
local ServerStorage = game:GetService("ServerStorage")

local function Template(zoneKey, name)
    if not ServerStorage.FindFirstChild then return nil end          -- (the test environment's ServerStorage is a bare stub)
    local root = ServerStorage:FindFirstChild("BiomeAssets")
    local zone = root and root:FindFirstChild(zoneKey)
    return zone and zone:FindFirstChild(name)
end

-- The chunky landscape pieces a player must not be able to walk through. Everything else (things that hang or float, plants, the pads, the road frames, the anvil
-- and carts that have their own colliders) stays walk-through. A solid piece collides through its mesh's own default collision (scripts can't change a mesh's collision fidelity).
local SOLID_PIECES = {
    RockCluster = true, CrystalCluster = true, OreCrates = true, Stalagmite = true, Boulder = true, GlowCluster = true,
    Spires = true, WallPiece = true, IceSpires = true, SnowBoulder = true, SnowPine = true, IceCrystals = true, FrozenFalls = true, PadCrystals = true,
    -- the hub's floor clutter is solid too: you cannot walk through a heap of rubble or a stack of barrels (they keep to the road edges and quiet corners)
    Rubble = true, BrokenPlanks = true, OreSacks = true, Wheelbarrow = true, BarrelStack = true, ToolRack = true, CaveMushrooms = true, FloorLantern = true,
}

-- opts: height | width (target size), yaw (radians), float (pos is the centre, not the ground), top (the piece's top surface goes at this height), hang (pos.Y is a ceiling: the piece hangs from it),
-- solid (true / false overrides whether it collides; by default the chunky pieces above do)
local function MeshPiece(parent, zoneKey, name, pos, opts)
    local template = Template(zoneKey, name)
    if not template then return nil end
    local m = template:Clone()
    m.Name = name
    local solid = opts.solid
    if solid == nil then solid = SOLID_PIECES[name] == true and not opts.float and not opts.hang end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide = true, solid and d:IsA("MeshPart") or false
        end
    end
    local ext = m:GetExtentsSize()
    local factor = opts.height and (opts.height / math.max(ext.Y, 0.01)) or ((opts.width or 10) / math.max(math.max(ext.X, ext.Z), 0.01))
    m:ScaleTo(m:GetScale() * factor)
    m:PivotTo(m:GetPivot() * CFrame.Angles(0, opts.yaw or 0, 0))
    local box, size = m:GetBoundingBox()
    local cy = pos.Y + size.Y / 2
    if opts.float then cy = pos.Y elseif opts.top then cy = opts.top - size.Y / 2 elseif opts.hang then cy = pos.Y - size.Y / 2 end
    local centre = Vector3.new(pos.X, cy, pos.Z)
    m:PivotTo(m:GetPivot() + (centre - box.Position))
    if not m.PrimaryPart then m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart", true) end
    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    m.Parent = parent
    return m
end

-- A light that breathes (the client's "light" kind), held by a tiny invisible part at the top of a mesh piece
local function GlowLight(m, colour, range, brightness, phase)
    local box, size = m:GetBoundingBox()
    local holder = P(m, { Name = "GlowAnchor", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(box.Position + Vector3.new(0, size.Y * 0.25, 0)) })
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = colour or GLOW, range or 20, brightness or 1.2
    light.Parent = holder
    Animate(holder, "light", 2, 0.4, phase or 0)
    return holder
end

-- ── Pieces ────────────────────────────────────────────────────────────────────

-- A cluster of tall crystals on a snowy rock base. `scale` multiplies every size.
function BiomeArt.IceSpires(parent, pos, rng, scale)
    scale = scale or 1
    local mesh = MeshPiece(parent, "GlacialPeaks", "IceSpires", pos, { height = rng:NextNumber(16, 24) * scale, yaw = rng:NextNumber(0, math.pi * 2) })
    if mesh then return mesh end
    local m = Instance.new("Model")
    m.Name = "IceSpires"
    local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
    for i = 1, 3 do
        local a = (i / 3) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
        local s = rng:NextNumber(3.5, 5.5) * scale
        Rock(m, base * CFrame.new(math.cos(a) * 2.8 * scale, s * 0.25, math.sin(a) * 2.8 * scale) * CFrame.Angles(0, a, 0), Vector3.new(s * 1.3, s * 0.6, s), true)
    end
    local count = rng:NextInteger(4, 6)
    for i = 1, count do
        local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
        local r = (i == 1 and 0 or rng:NextNumber(1.4, 3.2)) * scale
        local h = (i == 1 and rng:NextNumber(20, 26) or rng:NextNumber(9, 18)) * scale
        local w = (i == 1 and 3.4 or rng:NextNumber(1.8, 2.8)) * scale
        local lean = i == 1 and 0.05 or rng:NextNumber(0.12, 0.3)
        local cf = base * CFrame.new(math.cos(a) * r, 0.6, math.sin(a) * r) * CFrame.Angles(0, a, 0) * CFrame.Angles(lean, 0, 0)
        Crystal(m, cf, w, h, i % 2 == 0 and ICE or ICE_DEEP)
    end
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = GLOW, 18, 0.8
    light.Parent = m:FindFirstChild("Core")
    m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic       -- streams in whole: the client animates a piece only once all of it has arrived
    m.Parent = parent
    return m
end

-- A frozen waterfall: a wall of layered blue ice streaming down into a frosty pool, icicles along the top. Faces +Z... `facing` is a yaw.
function BiomeArt.FrozenFalls(parent, pos, rng, scale)
    scale = scale or 1
    local mesh = MeshPiece(parent, "GlacialPeaks", "FrozenFalls", pos, { width = 22 * scale })        -- its front faces -Z, toward the pad
    if mesh then
        GlowLight(mesh, GLOW, 22, 0.45, rng:NextNumber(0, 6))
        return mesh
    end
    local m = Instance.new("Model")
    m.Name = "FrozenFalls"
    local base = CFrame.new(pos)                                       -- the fall faces -Z, toward the pad (the cave's back wall is at +Z)
    local W, H = 11 * scale, 26 * scale
    P(m, { Name = "Cliff", Material = Enum.Material.Slate, Color = ROCK, Size = Vector3.new(W + 4, H + 2, 3 * scale), CFrame = base * CFrame.new(0, H / 2, 1.2 * scale) })
    local strips = 7
    for i = 1, strips do
        local sw = W / strips
        local x = -W / 2 + (i - 0.5) * sw
        local len = H * rng:NextNumber(0.8, 1)
        P(m, { Name = "Flow", Material = Enum.Material.Ice, Color = i % 2 == 0 and ICE or ICE_DEEP, Transparency = 0.05 + (i % 3) * 0.05,
            Size = Vector3.new(sw * 0.95, len, rng:NextNumber(1.2, 2.2) * scale), CFrame = base * CFrame.new(x, H - len / 2, -0.4 * scale) })
        -- icicles at the lower end of each strip
        local ic = rng:NextNumber(2.5, 6) * scale
        Pyramid(m, base * CFrame.new(x, H - len, -0.4 * scale) * CFrame.Angles(math.pi, 0, 0), sw * 0.8, ic, { Material = Enum.Material.Glass, Color = ICE, Transparency = 0.2 })
    end
    local core = P(m, { Name = "Core", Material = Enum.Material.Neon, Color = GLOW, Transparency = 0.6, Size = Vector3.new(W * 0.5, H * 0.8, 0.6), CFrame = base * CFrame.new(0, H * 0.5, 0.6 * scale) })
    Animate(core, "pulse", 1.6, 0.25, rng:NextNumber(0, 6))
    local pool = P(m, { Name = "Pool", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Ice, Color = ICE, Transparency = 0.15,
        Size = Vector3.new(0.5, W * 1.5, W * 1.5), CFrame = base * CFrame.new(0, 0.3, -W * 0.45) * CFrame.Angles(0, 0, math.pi / 2) })
    P(m, { Name = "Frost", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Snow, Color = SNOW, Size = Vector3.new(0.3, W * 2, W * 2),
        CFrame = base * CFrame.new(0, 0.2, -W * 0.45) * CFrame.Angles(0, 0, math.pi / 2) })
    local mist = Instance.new("ParticleEmitter")
    mist.Color, mist.Rate, mist.Lifetime, mist.Speed = ColorSequence.new(Color3.fromRGB(215, 240, 255)), 6, NumberRange.new(3, 5), NumberRange.new(0.5, 1.5)
    mist.Size, mist.Transparency, mist.EmissionDirection = NumberSequence.new(4, 8), NumberSequence.new(0.7, 1), Enum.NormalId.Top
    mist.Parent = pool
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = GLOW, 24, 0.9
    light.Parent = core
    m.PrimaryPart = core
    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic       -- streams in whole: the client animates a piece only once all of it has arrived
    m.Parent = parent
    return m
end

-- A snow-laden pine that sways a little
function BiomeArt.SnowPine(parent, pos, rng, scale)
    scale = scale or rng:NextNumber(0.8, 1.4)
    local mesh = MeshPiece(parent, "GlacialPeaks", "SnowPine", pos, { height = 13 * scale, yaw = rng:NextNumber(0, math.pi * 2) })
    if mesh then
        Animate(mesh, "sway", rng:NextNumber(0.6, 1.1), 0.025, rng:NextNumber(0, 6))
        return mesh
    end
    local m = Instance.new("Model")
    m.Name = "SnowPine"
    local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
    local trunkH = 4 * scale
    P(m, { Name = "Trunk", Material = Enum.Material.Wood, Color = TRUNK, Size = Vector3.new(1.4 * scale, trunkH, 1.4 * scale), CFrame = base * CFrame.new(0, trunkH / 2, 0) })
    local y = trunkH * 0.7
    local widths = { 8.5, 6.8, 5.2, 3.6 }
    for i, w in ipairs(widths) do
        local ww, th = w * scale, 3.6 * scale
        local cf = base * CFrame.new(0, y, 0) * CFrame.Angles(0, i * 0.5, 0)
        P(m, { Name = "Tier", Material = Enum.Material.Fabric, Color = PINE, Size = Vector3.new(ww, th * 0.6, ww), CFrame = cf * CFrame.new(0, th * 0.3, 0) })
        Pyramid(m, cf * CFrame.new(0, th * 0.6, 0), ww * 0.92, th * 1.3, { Material = Enum.Material.Fabric, Color = PINE })
        -- a band of snow on the ledge where this tier meets the next
        P(m, { Name = "Snow", Material = Enum.Material.Snow, Color = SNOW, Size = Vector3.new(ww * 1.04, th * 0.16, ww * 1.04), CFrame = cf * CFrame.new(0, th * 0.58, 0) })
        y += th * 0.85
    end
    P(m, { Name = "Star", Material = Enum.Material.Neon, Color = GLOW, Transparency = 0.2, Size = Vector3.new(0.9 * scale, 0.9 * scale, 0.9 * scale),
        CFrame = base * CFrame.new(0, y + 1.4 * scale, 0) * CFrame.Angles(0.8, 0.8, 0) })
    m.PrimaryPart = m:FindFirstChild("Trunk")
    Animate(m, "sway", rng:NextNumber(0.6, 1.1), 0.025, rng:NextNumber(0, 6))
    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic       -- streams in whole: the client animates a piece only once all of it has arrived
    m.Parent = parent
    return m
end

-- A low cluster of bright crystals that breathe with light
function BiomeArt.IceCrystals(parent, pos, rng, scale)
    scale = scale or 1
    local mesh = MeshPiece(parent, "GlacialPeaks", "IceCrystals", pos, { height = 7 * scale, yaw = rng:NextNumber(0, math.pi * 2) })
    if mesh then
        GlowLight(mesh, Color3.fromRGB(120, 235, 255), 16, 0.7, rng:NextNumber(0, 6))
        return mesh
    end
    local m = Instance.new("Model")
    m.Name = "IceCrystals"
    local base = CFrame.new(pos)
    Rock(m, base * CFrame.new(0, 0.9 * scale, 0), Vector3.new(6 * scale, 1.8 * scale, 5 * scale), true)
    local first
    for i = 1, 5 do
        local a = (i / 5) * math.pi * 2
        local r = (i == 1 and 0 or 1.6) * scale
        local h = (i == 1 and 7.5 or rng:NextNumber(3.5, 5.5)) * scale
        local cf = base * CFrame.new(math.cos(a) * r, 1.6 * scale, math.sin(a) * r) * CFrame.Angles(i == 1 and 0 or 0.35, a, 0)
        local core = Crystal(m, cf, 1.5 * scale, h, ICE, Color3.fromRGB(120, 235, 255))
        core.Transparency = 0.25
        Animate(core, "pulse", 2.2, 0.2, rng:NextNumber(0, 6))
        first = first or core
    end
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = Color3.fromRGB(120, 235, 255), 20, 1.4
    light.Parent = first
    m.PrimaryPart = first
    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic       -- streams in whole: the client animates a piece only once all of it has arrived
    m.Parent = parent
    return m
end

-- A big floating shard that bobs and turns slowly, trailing sparkles
function BiomeArt.FloatingShard(parent, pos, rng, scale)
    scale = scale or rng:NextNumber(0.8, 1.5)
    local mesh = MeshPiece(parent, "GlacialPeaks", "FloatingShard", pos, { height = 9 * scale, yaw = rng:NextNumber(0, math.pi * 2), float = true })
    if mesh then
        local core = mesh.PrimaryPart
        local sp = Instance.new("ParticleEmitter")
        sp.Color, sp.Rate, sp.Lifetime, sp.Speed = ColorSequence.new(GLOW), 8, NumberRange.new(1.5, 2.5), NumberRange.new(0.3, 1)
        sp.Size, sp.LightEmission, sp.EmissionDirection = NumberSequence.new(0.35, 0), 1, Enum.NormalId.Bottom
        sp.Parent = core
        GlowLight(mesh, GLOW, 16, 1, rng:NextNumber(0, 6))
        Animate(mesh, "bobspin", rng:NextNumber(0.5, 0.9), 1.2 * scale, rng:NextNumber(0, 6))
        return mesh
    end
    local m = Instance.new("Model")
    m.Name = "FloatingShard"
    local w, h = 3.4 * scale, 8 * scale
    local cf = CFrame.new(pos)
    P(m, { Name = "Body", Material = Enum.Material.Glass, Color = ICE, Transparency = 0.25, Size = Vector3.new(w, h * 0.4, w), CFrame = cf })
    Pyramid(m, cf * CFrame.new(0, h * 0.2, 0), w, h * 0.3, { Material = Enum.Material.Glass, Color = ICE, Transparency = 0.25 })
    Pyramid(m, cf * CFrame.new(0, -h * 0.2, 0) * CFrame.Angles(math.pi, 0, 0), w, h * 0.3, { Material = Enum.Material.Glass, Color = ICE, Transparency = 0.25 })
    local core = P(m, { Name = "Core", Material = Enum.Material.Neon, Color = GLOW, Transparency = 0.2, Size = Vector3.new(w * 0.4, h * 0.55, w * 0.4), CFrame = cf })
    local sp = Instance.new("ParticleEmitter")
    sp.Color, sp.Rate, sp.Lifetime, sp.Speed = ColorSequence.new(GLOW), 8, NumberRange.new(1.5, 2.5), NumberRange.new(0.3, 1)
    sp.Size, sp.LightEmission, sp.EmissionDirection = NumberSequence.new(0.35, 0), 1, Enum.NormalId.Bottom
    sp.Parent = core
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = GLOW, 16, 1
    light.Parent = core
    m.PrimaryPart = core
    Animate(m, "bobspin", rng:NextNumber(0.5, 0.9), 1.2 * scale, rng:NextNumber(0, 6))
    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic       -- streams in whole: the client animates a piece only once all of it has arrived
    m.Parent = parent
    return m
end

-- A fat snow-covered boulder with a few small ice spikes
function BiomeArt.SnowBoulder(parent, pos, rng, scale)
    scale = scale or rng:NextNumber(0.8, 1.6)
    local mesh = MeshPiece(parent, "GlacialPeaks", "SnowBoulder", pos, { height = 6 * scale, yaw = rng:NextNumber(0, math.pi * 2) })
    if mesh then return mesh end
    local m = Instance.new("Model")
    m.Name = "SnowBoulder"
    local d = 8 * scale
    local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
    P(m, { Name = "Rock", Shape = Enum.PartType.Ball, Material = Enum.Material.Slate, Color = ROCK, Size = Vector3.new(d, d * 0.8, d), CFrame = base * CFrame.new(0, d * 0.25, 0) })
    P(m, { Name = "Snow", Shape = Enum.PartType.Ball, Material = Enum.Material.Snow, Color = SNOW, Size = Vector3.new(d * 0.95, d * 0.5, d * 0.95), CFrame = base * CFrame.new(0, d * 0.5, 0) })
    for i = 1, 3 do
        local a = rng:NextNumber(0, math.pi * 2)
        Crystal(m, base * CFrame.new(math.cos(a) * d * 0.35, d * 0.55, math.sin(a) * d * 0.35) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)),
            1.1 * scale, rng:NextNumber(3, 5.5) * scale, ICE)
    end
    m.PrimaryPart = m:FindFirstChild("Rock")
    m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic       -- streams in whole: the client animates a piece only once all of it has arrived
    m.Parent = parent
    return m
end

-- ── The zone ──────────────────────────────────────────────────────────────────
-- Scatters the pieces round the pad. Nothing goes in the corridor between the tunnel mouth and the pad (south of the pad, centred on it).
local function InCorridor(dx, dz) return dz < -28 and math.abs(dx) < 32 end

local function Scatter(count, rMin, rMax, rng, place)
    local placed, tries = 0, 0
    while placed < count and tries < count * 12 do
        tries += 1
        local a = rng:NextNumber(0, math.pi * 2)
        local r = rng:NextNumber(rMin, rMax)
        local dx, dz = math.cos(a) * r, math.sin(a) * r
        if not InCorridor(dx, dz) then
            place(dx, dz)
            placed += 1
        end
    end
end

-- The big centrepiece crystal on the pad (replaces the old neon blocks every zone starts with)
function BiomeArt.PadCrystals(parent, pos, rng)
    local mesh = MeshPiece(parent, "GlacialPeaks", "PadCrystals", pos, { height = 30, yaw = rng:NextNumber(0, math.pi * 2) })
    if mesh then
        GlowLight(mesh, Color3.fromRGB(140, 220, 255), 44, 0.9, 0)
        return mesh
    end
    local m = BiomeArt.IceSpires(parent, pos, rng, 1.5)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = GLOW, 60, 1.8
    light.Parent = m:FindFirstChild("Core")
    return m
end

local zoneRecords = {}      -- every zone built with this art, so it can be rebuilt when its mesh pack finishes loading

local function BuildGlacial(rec)
    local model, cx, cz = rec.model, rec.cx, rec.cz
    if rec.group then rec.group:Destroy() end
    for _, c in ipairs(model:GetChildren()) do          -- the generic neon crystals every zone starts with
        if c.Name == "Crystal" then c:Destroy() end
    end
    local rng = Random.new(rec.seed)
    local group = Instance.new("Folder")
    group.Name = "GlacialArt"
    group.Parent = model
    BiomeArt.PadCrystals(group, Vector3.new(cx, 0.4, cz), rng)
    Scatter(7, 50, 66, rng, function(dx, dz) BiomeArt.IceSpires(group, Vector3.new(cx + dx, 0.2, cz + dz), rng, rng:NextNumber(0.85, 1.25)) end)
    for _, fx in ipairs({ -44, 0, 44 }) do                                   -- three frozen waterfalls along the back wall
        BiomeArt.FrozenFalls(group, Vector3.new(cx + fx, 0.2, cz + 66), rng, 1)
    end
    Scatter(16, 36, 68, rng, function(dx, dz) BiomeArt.SnowPine(group, Vector3.new(cx + dx, 0.2, cz + dz), rng) end)
    Scatter(6, 34, 62, rng, function(dx, dz) BiomeArt.IceCrystals(group, Vector3.new(cx + dx, 0.2, cz + dz), rng, rng:NextNumber(0.9, 1.4)) end)
    Scatter(9, 30, 66, rng, function(dx, dz) BiomeArt.SnowBoulder(group, Vector3.new(cx + dx, 0.2, cz + dz), rng) end)
    Scatter(9, 14, 60, rng, function(dx, dz) BiomeArt.FloatingShard(group, Vector3.new(cx + dx, rng:NextNumber(14, 34), cz + dz), rng) end)
    Scatter(12, 10, 66, rng, function(dx, dz)                                             -- icicles hanging from the roof (it is 60 studs up)
        MeshPiece(group, "GlacialPeaks", "IceStalactite", Vector3.new(cx + dx, 60, cz + dz), { height = rng:NextNumber(12, 24), yaw = rng:NextNumber(0, math.pi * 2), hang = true })
    end)
    rec.group = group
end

function BiomeArt.GlacialPeaks(model, cx, cz, rng)
    local rec = { zone = "GlacialPeaks", model = model, cx = cx, cz = cz, seed = rng:NextInteger(1, 2 ^ 30) }
    table.insert(zoneRecords, rec)
    BuildGlacial(rec)
    return rec.group
end

-- ── The other zones: the same layout from each zone's own mesh pack ───────────
-- Every zone pack holds the same seven pieces (PadPiece, Spires, WallPiece, Flora, GlowCluster, Boulder, FloatingPiece), so one builder serves them all.
-- Until a pack is loaded the zone keeps the simple props WorldBuilder gave it (`legacy`); once it is, those are swapped for the meshes.
local MESH_ZONES = {
    EmberDepths     = { glow = Color3.fromRGB(255, 140, 50),  padLight = Color3.fromRGB(255, 120, 40) },
    GraniteCaverns  = { glow = Color3.fromRGB(255, 190, 90),  padLight = Color3.fromRGB(255, 190, 90) },
    StormriftCliffs = { glow = Color3.fromRGB(190, 160, 255), padLight = Color3.fromRGB(190, 150, 255) },
    TheHollow       = { glow = Color3.fromRGB(190, 110, 255), padLight = Color3.fromRGB(170, 90, 255) },
    TheDeepForge    = { glow = Color3.fromRGB(255, 200, 80),  padLight = Color3.fromRGB(255, 190, 70) },
}

local function BuildMeshZone(rec)
    local cfg = MESH_ZONES[rec.zone]
    if not cfg or not Template(rec.zone, "PadPiece") then return end         -- no pack yet: keep the simple props
    if rec.group then rec.group:Destroy() end
    for _, c in ipairs(rec.legacy or {}) do
        if c.Parent then c:Destroy() end
    end
    rec.legacy = nil
    for _, c in ipairs(rec.model:GetChildren()) do                          -- the generic neon crystals every zone starts with
        if c.Name == "Crystal" then c:Destroy() end
    end
    local rng = Random.new(rec.seed)
    local cx, cz, zone = rec.cx, rec.cz, rec.zone
    local group = Instance.new("Folder")
    group.Name = "ZoneArt"
    group.Parent = rec.model
    local function at(dx, dz, y) return Vector3.new(cx + dx, y or 0.2, cz + dz) end
    local pad = MeshPiece(group, zone, "PadPiece", at(0, 0, 0.4), { height = 30, yaw = rng:NextNumber(0, math.pi * 2) })
    if pad then GlowLight(pad, cfg.padLight, 60, 1.8, 0) end
    Scatter(7, 50, 66, rng, function(dx, dz) MeshPiece(group, zone, "Spires", at(dx, dz), { height = rng:NextNumber(16, 24), yaw = rng:NextNumber(0, math.pi * 2) }) end)
    for _, fx in ipairs({ -44, 0, 44 }) do                                  -- three wall features along the back (their front faces -Z, toward the pad)
        local w = MeshPiece(group, zone, "WallPiece", at(fx, 66), { width = 22 })
        if w then GlowLight(w, cfg.glow, 26, 0.9, rng:NextNumber(0, 6)) end
    end
    Scatter(14, 36, 68, rng, function(dx, dz)
        local f = MeshPiece(group, zone, "Flora", at(dx, dz), { height = rng:NextNumber(9, 15), yaw = rng:NextNumber(0, math.pi * 2) })
        if f then Animate(f, "sway", rng:NextNumber(0.6, 1.1), 0.025, rng:NextNumber(0, 6)) end
    end)
    Scatter(6, 34, 62, rng, function(dx, dz)
        local g = MeshPiece(group, zone, "GlowCluster", at(dx, dz), { height = rng:NextNumber(6, 9), yaw = rng:NextNumber(0, math.pi * 2) })
        if g then GlowLight(g, cfg.glow, 20, 1.4, rng:NextNumber(0, 6)) end
    end)
    Scatter(9, 30, 66, rng, function(dx, dz) MeshPiece(group, zone, "Boulder", at(dx, dz), { height = rng:NextNumber(5, 9), yaw = rng:NextNumber(0, math.pi * 2) }) end)
    -- mine floor clutter (the hub's World pieces, solid): rubble heaps, planks, ore sacks, barrels and glowing mushrooms, so the zone floor is not bare
    for _, k in ipairs({ { "Rubble", 5, 3, 6 }, { "OreSacks", 3, 3, 4.2 }, { "BrokenPlanks", 3, 2, 3.2 }, { "BarrelStack", 2, 4.5, 6.5 }, { "CaveMushrooms", 4, 3.5, 7 } }) do
        Scatter(k[2], 22, 64, rng, function(dx, dz)
            MeshPiece(group, "World", k[1], at(dx, dz), { height = rng:NextNumber(k[3], k[4]), yaw = rng:NextNumber(0, math.pi * 2) })
        end)
    end
    Scatter(9, 14, 60, rng, function(dx, dz)
        local s = MeshPiece(group, zone, "FloatingPiece", at(dx, dz, rng:NextNumber(14, 34)), { height = rng:NextNumber(8, 12), yaw = rng:NextNumber(0, math.pi * 2), float = true })
        if s then
            GlowLight(s, cfg.glow, 16, 1, rng:NextNumber(0, 6))
            Animate(s, "bobspin", rng:NextNumber(0.5, 0.9), 1.4, rng:NextNumber(0, 6))
        end
    end)
    if zone == "GraniteCaverns" then                                                            -- a real cave: stalagmites below, stalactites above
        Scatter(10, 38, 68, rng, function(dx, dz) MeshPiece(group, "World", "Stalagmite", at(dx, dz), { height = rng:NextNumber(10, 20), yaw = rng:NextNumber(0, math.pi * 2) }) end)
        Scatter(14, 10, 66, rng, function(dx, dz) MeshPiece(group, "World", "Stalactite", Vector3.new(cx + dx, 60, cz + dz), { height = rng:NextNumber(12, 24), yaw = rng:NextNumber(0, math.pi * 2), hang = true }) end)
    end
    rec.group = group
end

-- WorldBuilder calls this for every zone but Glacial Peaks (which builds itself above), passing the simple props it just made
function BiomeArt.Register(zoneKey, model, cx, cz, seed, legacy)
    if not MESH_ZONES[zoneKey] then return end
    local rec = { zone = zoneKey, kind = "mesh", model = model, cx = cx, cz = cz, seed = seed, legacy = legacy }
    table.insert(zoneRecords, rec)
    BuildMeshZone(rec)
end

-- ── The hub: mining pads, pushable mine carts, timber support frames and scatter scenery ──────────
-- All of these come from the "World" mesh set (AssetData.BiomeMeshes.World). Until it has loaded they stay as the part-built versions WorldBuilder and
-- PadService make; Refresh("World") swaps the meshes in.
local padRecords = {}

local function BuildPadArt(rec)
    local model = rec.model
    if not model.Parent then return end
    if rec.art then rec.art:Destroy() rec.art = nil end
    local art = MeshPiece(model, "World", "Pad" .. rec.id, Vector3.new(rec.x, 0, rec.z), { width = 28, top = rec.topY })
    if art then
        -- Spiked or crystal-rimmed pads are taller than their deck, so aligning the tallest point would bury the deck. Find the real deck (the mesh's
        -- surface at the pad's centre) and put THAT at the walking height.
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { art }
        local hit = workspace:Raycast(Vector3.new(rec.x, rec.topY + 40, rec.z), Vector3.new(0, -80, 0), params)
        if hit then art:PivotTo(art:GetPivot() + Vector3.new(0, rec.topY - hit.Position.Y, 0)) end
    end
    local plain = art == nil
    local base, rim, glow = model:FindFirstChild("PadBase"), model:FindFirstChild("PadRim"), model:FindFirstChild("PadGlow")
    if base then base.Transparency = plain and 0 or 1 end              -- the base stays as the (invisible) step you walk up
    if rim then rim.Transparency = plain and 0.1 or 1 end
    if glow then glow.Transparency = plain and 0.35 or 1 end
    if rec.part then rec.part.Transparency = plain and 0 or 1 end       -- the stepping surface keeps working (and its painted multiplier) but the mesh is what you see
    for _, c in ipairs(model:GetChildren()) do                         -- the old corner posts, arch and lantern orbs are hidden (the orbs' lights stay)
        if c.Name == "PadPost" or c.Name == "PadArch" then c.Transparency = plain and 0 or 1 end
        if c.Name == "PadLantern" then c.Transparency = plain and 0 or 1 end
    end
    if art then
        art.Name = "PadArt"
        rec.art = art
    end
end

-- PadService calls this for each pad it builds: `part` is the walkable Pad_<id> surface, `topY` the height of its top
function BiomeArt.Pad(model, id, part, x, z, topY)
    local rec = { model = model, id = id, part = part, x = x, z = z, topY = topY }
    table.insert(padRecords, rec)
    BuildPadArt(rec)
end

-- Mine carts: each is a real physical object that slides along the track when pushed (a prismatic constraint holds it on the rail within CART_TRAVEL
-- studs of where it started). The collision is one invisible block; the cart you see (a mesh, or the old parts) is welded to it.
local CART_TRAVEL = 55
local cartRec

local function WeldAll(model, body)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d ~= body then
            d.Anchored, d.CanCollide, d.Massless = false, false, true
            local w = Instance.new("WeldConstraint")
            w.Part0, w.Part1, w.Parent = body, d, d
        end
    end
end

-- The cart you can see: a mesh when the World pack has loaded, otherwise built from parts. Placed at spot.x / spot.z with its base at height 0.5, as `CartArt`
-- (a model) or as loose parts. Shared by the road carts below and the Cart Run carts (CartCourseService).
local function MakeCartArt(model, spot, index)
    local template = Template("World", index % 2 == 0 and "CartCrystal" or "CartGold")
    if template then
        local m = template:Clone()
        local ext = m:GetExtentsSize()
        m:ScaleTo(m:GetScale() * 9 / math.max(math.max(ext.X, ext.Z), 0.01))
        local box, size = m:GetBoundingBox()
        m:PivotTo(m:GetPivot() + (Vector3.new(spot.x, 0.5 + size.Y / 2, spot.z) - box.Position))
        m.Parent = model
        m.Name = "CartArt"
    else
        local function P2(name, size, cf, color, material, shape)
            local p = Instance.new("Part")
            p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, material
            if shape then p.Shape = shape end
            p.Parent = model
            return p
        end
        local iron = Color3.fromRGB(70, 68, 74)
        P2("CartBody", Vector3.new(8, 3.4, 6), CFrame.new(spot.x, 3, spot.z), Color3.fromRGB(80, 62, 52), Enum.Material.Metal)
        P2("CartRim", Vector3.new(8.6, 0.6, 6.6), CFrame.new(spot.x, 4.9, spot.z), iron, Enum.Material.Metal)
        for _, wx in ipairs({ -2.6, 2.6 }) do
            for _, wz in ipairs({ -3.2, 3.2 }) do
                P2("CartWheel", Vector3.new(0.6, 2, 2), CFrame.new(spot.x + wx, 1.3, spot.z + wz) * CFrame.Angles(0, math.pi / 2, 0), iron, Enum.Material.Metal, Enum.PartType.Cylinder)
            end
        end
        for j = 1, 4 do
            P2("CartOre", Vector3.new(2.4, 2.4, 2.4), CFrame.new(spot.x + ((j * 37) % 5 - 2) * 0.9, 5.4 + (j % 2) * 0.5, spot.z + ((j * 53) % 3 - 1) * 1.2),
                spot.ore or Color3.fromRGB(255, 200, 70), Enum.Material.Neon, Enum.PartType.Ball)
        end
    end
end

local function BuildCart(parent, spot, index)
    local model = Instance.new("Model")
    model.Name = "MineCart"
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(7.6, 3.2, 5.4)
    body.Transparency = 1
    body.Anchored = false
    body.CanCollide = true
    body.TopSurface, body.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    body.CFrame = CFrame.new(spot.x, 3, spot.z)
    if PhysicalProperties then body.CustomPhysicalProperties = PhysicalProperties.new(0.25, 0.25, 0.1, 1, 1) end     -- light and slippery: a player can shove it along
    body.Parent = model
    model.PrimaryPart = body
    MakeCartArt(model, spot, index)
    -- The collision block matches the cart you can see: as tall as it is (above a jump, about 7 studs) and as wide as it is, so a player pushing it
    -- can't hop onto an invisible ledge that looks like standing inside an open cart. Its bottom stays where the art's is, and the cart is held at that
    -- height by the rail constraint, so a taller block costs nothing. Mass stays what it was (the art is massless), so it pushes the same.
    local artSize = model:FindFirstChild("CartArt") and select(2, model.CartArt:GetBoundingBox()) or Vector3.new(8.6, 5.6, 6.6)
    local bodySize = Vector3.new(math.max(artSize.X * 0.92, 6), math.max(artSize.Y, 5.6), math.max(artSize.Z * 0.92, 5))
    local centerY = 0.5 + bodySize.Y / 2
    body.Size = bodySize
    body.CFrame = CFrame.new(spot.x, centerY, spot.z)
    if PhysicalProperties then
        body.CustomPhysicalProperties = PhysicalProperties.new(math.max(0.01, 0.25 * (7.6 * 3.2 * 5.4) / (bodySize.X * bodySize.Y * bodySize.Z)), 0.25, 0.1, 1, 1)
    end
    WeldAll(model, body)
    -- Mine Cart Delivery bounty (CartBountyService): the cart is tagged, remembers its start, says what to do, and the end of its rail has a glowing depot
    model:SetAttribute("HomeX", spot.x)
    model:SetAttribute("HomeZ", spot.z)
    model:SetAttribute("HomeY", centerY)
    model:SetAttribute("Loaded", true)
    CollectionService:AddTag(model, "EFCart")
    local sign = Instance.new("BillboardGui")
    sign.Name, sign.Adornee, sign.Size, sign.StudsOffset, sign.MaxDistance = "CartSign", body, UDim2.new(0, 190, 0, 34), Vector3.new(0, bodySize.Y / 2 + 1.5, 0), 55
    sign.Parent = body
    local text = Instance.new("TextLabel")
    text.Name, text.Size, text.BackgroundTransparency, text.Text = "Text", UDim2.new(1, 0, 1, 0), 1, "Push me to the depot for coins"
    text.TextColor3, text.TextStrokeTransparency, text.Font, text.TextSize, text.TextWrapped = Color3.fromRGB(255, 220, 120), 0.3, Enum.Font.GothamBold, 14, true
    text.Parent = sign
    local depot = Instance.new("Part")
    depot.Name, depot.Shape, depot.Material, depot.Color = "CartDepot", Enum.PartType.Cylinder, Enum.Material.Neon, Color3.fromRGB(255, 200, 70)
    depot.Size = Vector3.new(0.4, 11, 11)
    depot.CFrame = CFrame.new(spot.x + 53, 0.4, spot.z) * CFrame.Angles(0, 0, math.pi / 2)           -- a flat glowing disc at the end of the rail
    depot.Anchored, depot.CanCollide, depot.CanQuery, depot.Transparency = true, false, false, 0.35
    depot.Parent = model
    local depotLight = Instance.new("PointLight")
    depotLight.Color, depotLight.Range, depotLight.Brightness = Color3.fromRGB(255, 200, 70), 22, 1.4
    depotLight.Parent = depot
    -- the rail: an invisible anchored post that the cart slides along (the track runs along X)
    local anchor = Instance.new("Part")
    anchor.Name, anchor.Size, anchor.Transparency, anchor.Anchored, anchor.CanCollide, anchor.CanQuery = "CartRailAnchor", Vector3.new(1, 1, 1), 1, true, false, false
    anchor.CFrame = CFrame.new(spot.x, centerY, spot.z)
    anchor.Parent = model
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = anchor, body
    local slide = Instance.new("PrismaticConstraint")
    slide.Attachment0, slide.Attachment1 = a0, a1
    slide.LimitsEnabled, slide.LowerLimit, slide.UpperLimit = true, -CART_TRAVEL, CART_TRAVEL
    slide.Parent = anchor
    model.Parent = parent
    return model
end

local function BuildCarts(rec)
    for _, m in ipairs(rec.built or {}) do if m.Parent then m:Destroy() end end
    rec.built = {}
    for i, spot in ipairs(rec.spots) do table.insert(rec.built, BuildCart(rec.parent, spot, i)) end
end

-- WorldBuilder gives the carts' track positions: { x, z, ore = colour } each
function BiomeArt.Carts(parent, spots)
    cartRec = { parent = parent, spots = spots }
    BuildCarts(cartRec)
end

-- Timber support frames across the road: a mesh frame replaces the part-built one (and its lantern) once the mesh is loaded
local frameRec

local function BuildFrames(rec)
    if not Template("World", "TimberFrame") then return end
    for _, c in ipairs(rec.legacy or {}) do if c.Parent then c:Destroy() end end
    rec.legacy = nil
    for _, f in ipairs(rec.built or {}) do if f.Parent then f:Destroy() end end
    rec.built = {}
    for _, spot in ipairs(rec.spots) do
        local m = MeshPiece(rec.parent, "World", "TimberFrame", Vector3.new(spot.x, 0, spot.z), { width = 24, yaw = math.pi / 2 })   -- spans the road (along Z)
        if m then
            GlowLight(m, Color3.fromRGB(255, 190, 100), 60, 1.4, 0)
            table.insert(rec.built, m)
        end
    end
end

function BiomeArt.Frames(parent, spots, legacy)
    frameRec = { parent = parent, spots = spots, legacy = legacy }
    BuildFrames(frameRec)
end

-- General scenery scattered through the hub's quiet corners (crates, rock clusters, crystal clusters). Nothing goes near the roads, the forge plots,
-- the pad plaza or the spawn.
local scatterRec

local function BuildScatter(rec)
    if rec.group then rec.group:Destroy() end
    local have = Template("World", "OreCrates") or Template("World", "RockCluster") or Template("World", "CrystalCluster") or Template("World", "Stalagmite") or Template("World", "Stalactite")
    if not have then return end
    local group = Instance.new("Folder")
    group.Name = "HubScenery"
    group.Parent = rec.parent
    local rng = Random.new(2468)
    local kinds = { { "RockCluster", 7, 12, 150 }, { "CrystalCluster", 8, 14, 90 }, { "OreCrates", 5, 8, 90 }, { "Stalagmite", 10, 24, 130 } }     -- name, height range, how many
    -- Every part of the cavern floor that is not a road, a forge or quarry plot, the pad plaza or the spawn. Weighted by area so the scenery is even.
    local regions = {
        { x1 = -420, x2 = 2050, z1 = 112, z2 = 172 },       -- the north strip, behind the quarry plots
        { x1 = -420, x2 = 2050, z1 = -245, z2 = -226 },     -- the south edge
        { x1 = -420, x2 = -150, z1 = -225, z2 = 110 },      -- the whole west end
        { x1 = 175, x2 = 2050, z1 = -224, z2 = -110 },      -- south-east, behind the forge plots (clear of the pad plaza)
        { x1 = -150, x2 = 150, z1 = -245, z2 = -222 },      -- the strip behind the pad plaza
    }
    local areas, total = {}, 0
    for i, r in ipairs(regions) do areas[i] = (r.x2 - r.x1) * (r.z2 - r.z1) total += areas[i] end
    local function pickRegion()
        local roll = rng:NextNumber(0, total)
        for i, a in ipairs(areas) do
            roll -= a
            if roll <= 0 then return regions[i] end
        end
        return regions[1]
    end
    for _, k in ipairs(kinds) do
        if Template("World", k[1]) then
            for _ = 1, k[4] do
                local r = pickRegion()
                local pos = Vector3.new(rng:NextNumber(r.x1, r.x2), 0.2, rng:NextNumber(r.z1, r.z2))
                local height, yaw, glow = rng:NextNumber(k[2], k[3]), rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 1) < 0.4
                if not CartCourseData.NearRoute(pos.X, pos.Z, 24) and math.abs(pos.Z - 60) > 10 then            -- never on a Cart Run road or the minecart track (z = 60)
                    local m = MeshPiece(group, "World", k[1], pos, { height = height, yaw = yaw })
                    if m and k[1] == "CrystalCluster" and glow then GlowLight(m, Color3.fromRGB(255, 200, 110), 22, 0.9, rng:NextNumber(0, 6)) end
                end
            end
        end
    end
    if Template("World", "Stalactite") then                                  -- stalactites hanging from the cavern roof (about 110 studs up) all along it
        for _ = 1, 140 do
            local pos = Vector3.new(rng:NextNumber(-420, 2050), 108, rng:NextNumber(-245, 165))
            MeshPiece(group, "World", "Stalactite", pos, { height = rng:NextNumber(14, 30), yaw = rng:NextNumber(0, math.pi * 2), hang = true })
        end
    end
    -- Floor clutter: rubble, broken planks, ore sacks, barrels, tool racks, wheelbarrows, glowing mushrooms and floor lanterns. All solid (they are in SOLID_PIECES), like
    -- the rest of the scenery. They line the edges of the main road but stay at least 9 studs off the track, so nothing blocks the road, the carts or the Cart Run roads.
    local clutterRegions = { table.unpack(regions) }
    table.insert(clutterRegions, { x1 = -420, x2 = 2050, z1 = 26, z2 = 46 })          -- along the main road (z = 60), either side
    table.insert(clutterRegions, { x1 = -420, x2 = 2050, z1 = 74, z2 = 94 })
    local clutterAreas, clutterTotal = {}, 0
    for i, r in ipairs(clutterRegions) do clutterAreas[i] = (r.x2 - r.x1) * (r.z2 - r.z1) clutterTotal += clutterAreas[i] end
    local function pickClutterRegion()
        if rng:NextNumber(0, 1) < 0.45 then return clutterRegions[#clutterRegions - rng:NextInteger(0, 1)] end        -- nearly half of it lines the main road, where players actually walk
        local roll = rng:NextNumber(0, clutterTotal)
        for i, a in ipairs(clutterAreas) do
            roll -= a
            if roll <= 0 then return clutterRegions[i] end
        end
        return clutterRegions[1]
    end
    local clutter = {   -- name, height range, how many, glow colour (nil = none)
        { "Rubble", 3, 6, 520 }, { "BrokenPlanks", 2, 3.2, 120 }, { "OreSacks", 3, 4.2, 120 }, { "Wheelbarrow", 3.4, 4.6, 55 },
        { "BarrelStack", 4.5, 6.5, 70 }, { "ToolRack", 5.5, 7.5, 40 },
        { "CaveMushrooms", 3.5, 7, 180, Color3.fromRGB(120, 255, 210), 0.4 }, { "FloorLantern", 4.5, 5.5, 90, Color3.fromRGB(255, 190, 100), 1 },
    }
    for _, k in ipairs(clutter) do
        if Template("World", k[1]) then
            for _ = 1, k[4] do
                local r = pickClutterRegion()
                local pos = Vector3.new(rng:NextNumber(r.x1, r.x2), 0.2, rng:NextNumber(r.z1, r.z2))
                if not CartCourseData.NearRoute(pos.X, pos.Z, 24) and math.abs(pos.Z - 60) > 10 then          -- (the minecart track runs along z = 60: keep it clear)
                    local m = MeshPiece(group, "World", k[1], pos, { height = rng:NextNumber(k[2], k[3]), yaw = rng:NextNumber(0, math.pi * 2) })
                    if m and k[5] and rng:NextNumber(0, 1) < (k[6] or 1) then GlowLight(m, k[5], 24, 0.9, rng:NextNumber(0, 6)) end
                end
            end
        end
    end
    rec.group = group
end

function BiomeArt.HubScatter(parent)
    scatterRec = { parent = parent }
    BuildScatter(scatterRec)
end

-- ── The Golem Anvil ───────────────────────────────────────────────────────────
-- The starter station's anvil: a large golden mesh when its pack is loaded (the "World" pack's GolemAnvil), otherwise the plain block from WorldBuilder.
-- The mesh's own colours come out peach-orange, so the golden parts (named anvil / chains in the model) get a yellow-green tint over their texture and
-- a metal finish here; the stone platform keeps its own look. `rec.part` is WorldBuilder's anvil block: it stays as the invisible collision and the E prompt's anchor.
local GOLD = Color3.fromRGB(215, 255, 85)         -- a yellow-green tint over the mesh's peach texture: it cancels the orange and leaves gold, texture kept
local anvilRec

local function BuildAnvil()
    local rec = anvilRec
    if not rec or not rec.world.Parent then return end
    if rec.art then rec.art:Destroy() rec.art = nil end
    local art = MeshPiece(rec.world, "World", "GolemAnvil", Vector3.new(rec.x, 0, rec.z), { width = rec.width })
    if not art then
        rec.part.Transparency = 0
        if rec.top then rec.top.Transparency = 0 end
        return
    end
    art.Name = "AnvilArt"
    for _, d in ipairs(art:GetDescendants()) do
        if d:IsA("MeshPart") then
            local n = d.Name:lower()
            if n:find("platform") or n:find("stone") or n:find("base") then
                d.Reflectance = 0
            else                                            -- the anvil itself, its chains, or a single-piece mesh: real shiny gold
                d.Color, d.Material, d.Reflectance = GOLD, Enum.Material.Metal, 0.12      -- the texture stays: its engraving and shading give the depth
            end
        end
    end
    local box, size = art:GetBoundingBox()
    rec.part.Transparency = 1                               -- the block becomes the invisible collision / prompt anchor
    rec.part.Size = Vector3.new(size.X * 0.8, math.min(size.Y, 8), size.Z * 0.8)
    rec.part.CFrame = CFrame.new(rec.x, rec.part.Size.Y / 2, rec.z)
    if rec.top then rec.top.Transparency = 1 end
    local embers = Instance.new("ParticleEmitter")
    embers.Color, embers.Rate, embers.Lifetime = ColorSequence.new(Color3.fromRGB(255, 170, 60)), 14, NumberRange.new(1.5, 3)
    embers.Speed, embers.LightEmission, embers.Size = NumberRange.new(2, 5), 1, NumberSequence.new(0.4, 0)
    embers.EmissionDirection, embers.Acceleration = Enum.NormalId.Top, Vector3.new(0, 3, 0)
    embers.Parent = art.PrimaryPart
    GlowLight(art, Color3.fromRGB(255, 190, 80), 36, 0.7, 0)
    rec.art = art
    rec.height = size.Y
end

function BiomeArt.Anvil(world, part, top, x, z, width)
    anvilRec = { world = world, part = part, top = top, x = x, z = z, width = width or 18 }
    BuildAnvil()
end

function BiomeArt.AnvilHeight() return anvilRec and anvilRec.height or nil end

BiomeArt.MakeCartArt = MakeCartArt

-- Other systems (the Cart Run courses) that need to redraw when the World mesh pack has loaded register here
local worldListeners = {}
function BiomeArt.OnWorldRefresh(fn) table.insert(worldListeners, fn) end

-- Called by GolemAssetLoader when a mesh pack has loaded: rebuild that area's art with the meshes
function BiomeArt.Refresh(zoneKey)
    if zoneKey == "World" then
        for _, fn in ipairs(worldListeners) do pcall(fn) end
        BuildAnvil()
        for _, rec in ipairs(padRecords) do BuildPadArt(rec) end
        if cartRec then BuildCarts(cartRec) end
        if frameRec then BuildFrames(frameRec) end
        if scatterRec then BuildScatter(scatterRec) end
    end
    for _, rec in ipairs(zoneRecords) do
        if rec.zone == zoneKey and rec.model.Parent then
            if rec.kind == "mesh" then BuildMeshZone(rec) else BuildGlacial(rec) end
        end
    end
end

return BiomeArt
