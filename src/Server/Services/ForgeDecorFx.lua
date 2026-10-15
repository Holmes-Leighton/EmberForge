-- The forge decorations (CosmeticData ForgeDecoration_*): each one is a generated mesh (AssetData.ForgeDecorationMeshes, loaded into ServerStorage.ForgeDecorAssets)
-- plus its own animation, so they are alive and not just statues:
--   flames and embers   a living fire (Fire + flame sprites + embers + smoke) with a flickering light
--   orbiting pieces     small crystals / runes / sparks circling the decoration       (tag "EFOrbit",   moved by DecorAnimator on the client)
--   floating pieces     orbs and shards that bob up and down                          (tag "EFBob")
--   spinning discs      the swirl inside a portal                                     (tag "EFDecorSpin")
--   pulsing glows       halos that breathe                                            (tag "EFPulse")
--   lightning arcs      thin bolts that flash on and off                              (tag "EFArc")
--   drifting particles  mist, glitter, void motes, gold dust, lava bubbles
-- The server only builds the pieces and their attributes; the client animates them, so animation costs the server nothing.
-- Place() returns nil when the mesh is not available (or in the test environment); ForgeBuilder then builds the part-made decoration it always had.

local CollectionService = game:GetService("CollectionService")
local ServerStorage     = game:GetService("ServerStorage")

local ForgeDecorFx = {}

local PI = math.pi
local rgb = Color3.fromRGB

-- height = how tall the mesh is stood (studs); tint colours for its effects. `fx` adds the animations (see below).
ForgeDecorFx.Specs = {}

-- ── Little builders (everything here is decoration: never solid) ──────────────
local function Part(parent, name, size, cf, color, material, props)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, material or Enum.Material.Neon
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props or {}) do p[k] = v end
    p.Parent = parent
    return p
end

local function Light(parent, color, range, brightness, flicker)
    local l = Instance.new("PointLight")
    l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
    l.Parent = parent
    if flicker then CollectionService:AddTag(l, "EFFlicker") end        -- the client makes it breathe (TowerController)
    return l
end

local function Emitter(parent, props)
    local e = Instance.new("ParticleEmitter")
    e.Rate, e.Lifetime, e.Speed = props.rate or 10, props.life or NumberRange.new(1, 2), props.speed or NumberRange.new(1, 3)
    e.Color = props.color or ColorSequence.new(Color3.new(1, 1, 1))
    e.Size = props.size or NumberSequence.new(0.5, 0)
    e.Transparency = props.transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
    e.SpreadAngle = props.spread or Vector2.new(20, 20)
    e.Acceleration = props.accel or Vector3.new(0, 2, 0)
    e.LightEmission = props.glow == nil and 1 or props.glow
    e.EmissionDirection = props.dir or Enum.NormalId.Top
    e.Rotation, e.RotSpeed = props.rotation or NumberRange.new(0, 360), props.rotSpeed or NumberRange.new(-60, 60)
    e.LockedToPart = props.locked or false
    if props.texture then e.Texture = props.texture end
    e.Parent = parent
    return e
end

local SPARK  = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE  = "rbxasset://textures/particles/smoke_main.dds"
local FIREP  = "rbxasset://textures/particles/fire_main.dds"

-- A living flame: the built-in Fire, layered flame sprites, embers and (optionally) smoke, with a flickering light
local function Flame(parent, cf, scale, color, smoke)
    local base = Part(parent, "DecorFlame", Vector3.new(1.2 * scale, 0.3, 1.2 * scale), cf, color, Enum.Material.Neon, { Transparency = 1 })
    local fire = Instance.new("Fire")
    fire.Size, fire.Heat = 5.5 * scale, 6
    fire.Color, fire.SecondaryColor = color:Lerp(rgb(255, 215, 110), 0.4), color:Lerp(rgb(200, 40, 20), 0.5)
    fire.Parent = base
    Emitter(base, { texture = FIREP, rate = 22 * scale, life = NumberRange.new(0.45, 0.85), speed = NumberRange.new(2, 4), spread = Vector2.new(14, 14), accel = Vector3.new(0, 7, 0),
        color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color:Lerp(rgb(255, 240, 170), 0.6)), ColorSequenceKeypoint.new(0.5, color), ColorSequenceKeypoint.new(1, color:Lerp(rgb(120, 20, 10), 0.6)) }),
        size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * scale), NumberSequenceKeypoint.new(0.4, 1.4 * scale), NumberSequenceKeypoint.new(1, 0.1) }),
        transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }) })
    Emitter(base, { texture = SPARK, rate = 6 * scale, life = NumberRange.new(1.2, 2.4), speed = NumberRange.new(3, 8), spread = Vector2.new(25, 25), accel = Vector3.new(0, 4, 0),
        color = ColorSequence.new(color:Lerp(rgb(255, 230, 150), 0.5), color), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32 * scale), NumberSequenceKeypoint.new(1, 0) }) })
    if smoke then
        Emitter(base, { texture = SMOKE, rate = 3 * scale, life = NumberRange.new(2, 3.6), speed = NumberRange.new(2, 3.5), spread = Vector2.new(10, 10), accel = Vector3.new(0, 2.5, 0), glow = 0,
            color = ColorSequence.new(rgb(70, 62, 60)), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 4.5 * scale) }),
            transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }) })
    end
    Light(base, color:Lerp(rgb(255, 170, 80), 0.4), 26 * math.max(scale, 0.8), 2, true)
    return base
end

-- Small pieces that circle a point (client: tag EFOrbit). center is a world position; the tilt (degrees) tips the orbit's plane.
local function Orbiters(parent, center, count, radius, speed, tiltX, tiltZ, size, color, material, shape)
    for i = 1, count do
        local p = Part(parent, "DecorOrbiter", size, CFrame.new(center), color, material or Enum.Material.Neon, { Shape = shape or Enum.PartType.Block, Transparency = 0.1 })
        p:SetAttribute("OrbitCenter", center)
        p:SetAttribute("OrbitRadius", radius)
        p:SetAttribute("OrbitSpeed", speed)
        p:SetAttribute("OrbitPhase", (i - 1) / count * PI * 2)
        p:SetAttribute("OrbitTiltX", tiltX or 0)
        p:SetAttribute("OrbitTiltZ", tiltZ or 0)
        p:SetAttribute("Tumble", 1.4)
        CollectionService:AddTag(p, "EFOrbit")
    end
end

-- An orb or shard that floats up and down (client: tag EFBob)
local function Floater(parent, cf, size, color, shape, amplitude, speed)
    local p = Part(parent, "DecorFloater", size, cf, color, Enum.Material.Neon, { Shape = shape or Enum.PartType.Ball, Transparency = 0.12 })
    p:SetAttribute("BobAmp", amplitude or 0.5)
    p:SetAttribute("BobSpeed", speed or 1.3)
    p:SetAttribute("BobPhase", math.random() * 6.28)
    p:SetAttribute("SpinSpeed", 0.8)
    CollectionService:AddTag(p, "EFBob")
    Light(p, color, 14, 1.2, true)
    return p
end

-- A halo that breathes (client: tag EFPulse). kind "ring" = a flat neon ring; transparency swings between lo and hi.
local function Halo(parent, cf, diameter, color, lo, hi, speed)
    local p = Part(parent, "DecorHalo", Vector3.new(0.25, diameter, diameter), cf * CFrame.Angles(0, 0, PI / 2), color, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = hi or 0.6 })
    p:SetAttribute("PulseLo", lo or 0.15)
    p:SetAttribute("PulseHi", hi or 0.7)
    p:SetAttribute("PulseSpeed", speed or 1.6)
    p:SetAttribute("PulsePhase", math.random() * 6.28)
    CollectionService:AddTag(p, "EFPulse")
    return p
end

-- A flat disc that turns about its own axis (client: tag EFDecorSpin). axis "X" for a disc standing upright facing the Z direction.
local function SpinDisc(parent, cf, diameter, color, transparency, speed, axis)
    local p = Part(parent, "DecorSwirl", Vector3.new(0.2, diameter, diameter), cf, color, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = transparency })
    p:SetAttribute("SpinSpeed", speed)
    p:SetAttribute("SpinAxis", axis or "X")
    CollectionService:AddTag(p, "EFDecorSpin")
    return p
end

-- A thin lightning bolt that flashes (client: tag EFArc)
local function Arc(parent, a, b, color, thick)
    local len = (b - a).Magnitude
    local p = Part(parent, "DecorArc", Vector3.new(thick or 0.22, thick or 0.22, len), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Neon, { Transparency = 0.2 })
    p:SetAttribute("ArcOnMin", 0.04)
    p:SetAttribute("ArcOnMax", 0.22)
    p:SetAttribute("ArcOffMin", 0.15)
    p:SetAttribute("ArcOffMax", 0.9)
    p:SetAttribute("ArcA", a)
    p:SetAttribute("ArcB", b)
    CollectionService:AddTag(p, "EFArc")
    return p
end

local function Mist(parent, cf, radius, color, rate)
    local p = Part(parent, "DecorMist", Vector3.new(radius, 0.2, radius), cf, color, Enum.Material.Neon, { Transparency = 1 })
    Emitter(p, { texture = SMOKE, rate = rate or 4, life = NumberRange.new(2.4, 4), speed = NumberRange.new(0.5, 1.2), spread = Vector2.new(80, 80), accel = Vector3.new(0, 0.6, 0), glow = 0.4,
        color = ColorSequence.new(color), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4) }),
        transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }) })
    return p
end

local function Glitter(parent, cf, size, color, rate)
    local p = Part(parent, "DecorGlitter", size, cf, color, Enum.Material.Neon, { Transparency = 1 })
    Emitter(p, { texture = SPARK, rate = rate or 8, life = NumberRange.new(1.4, 2.8), speed = NumberRange.new(0.3, 1.2), spread = Vector2.new(180, 180), accel = Vector3.new(0, 0.5, 0),
        color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5), color), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }),
        transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) })
    return p
end

-- ── The ten decorations ───────────────────────────────────────────────────────
-- Each spec: height (studs), the effect colour, and fx(ctx). ctx = { parent, at(rx, ry, rz) -> world CFrame (rx, rz as a fraction of half the width, ry as a fraction of
-- the height), top = world position of the top centre, h = height, w = width, base = world position of the base centre }.
local S = ForgeDecorFx.Specs

S.ForgeDecoration_EmberStatue = { height = 10, color = rgb(255, 120, 40), fx = function(c)
    Flame(c.parent, c.at(0.55, 0.93, 0), 0.9, rgb(255, 130, 40), true)                              -- the flame in its raised hand
    Glitter(c.parent, c.at(0, 0.5, 0), Vector3.new(c.w * 0.8, c.h * 0.5, c.w * 0.8), rgb(255, 140, 50), 7)   -- embers drifting off the cracks
    Halo(c.parent, c.at(0, 0.02, 0), c.w * 2.2, rgb(255, 110, 30), 0.35, 0.8, 1.4)                  -- a glowing ring of heat at its feet
    Light(c.parent:FindFirstChildWhichIsA("BasePart"), rgb(255, 120, 40), 24, 1.4, true)
end }

S.ForgeDecoration_AncientAltar = { height = 5, color = rgb(255, 205, 90), fx = function(c)
    Flame(c.parent, c.at(0, 0.82, 0), 1.2, rgb(255, 190, 70), true)                                  -- the altar's sacred flame
    Glitter(c.parent, c.at(0, 0.9, 0), Vector3.new(c.w * 0.6, 1, c.w * 0.4), rgb(255, 215, 110), 10)    -- golden dust rising
    Orbiters(c.parent, c.at(0, 1.5, 0).Position, 3, c.w * 0.5, 1.1, 0, 0, Vector3.new(0.3, 0.3, 0.3), rgb(255, 215, 100))
end }

S.ForgeDecoration_IceStatue = { height = 10, color = rgb(150, 215, 255), fx = function(c)
    Glitter(c.parent, c.at(0, 0.55, 0), Vector3.new(c.w * 0.9, c.h * 0.6, c.w * 0.9), rgb(170, 230, 255), 12)
    Mist(c.parent, c.at(0, 0.03, 0), c.w * 1.6, rgb(190, 235, 255), 5)                               -- cold mist pooling at the base
    Halo(c.parent, c.at(0, 0.02, 0), c.w * 2.2, rgb(140, 210, 255), 0.4, 0.85, 1.0)
    Light(c.parent:FindFirstChildWhichIsA("BasePart"), rgb(150, 215, 255), 22, 1.2, true)
end }

S.ForgeDecoration_GlacialPillar = { height = 12, color = rgb(160, 225, 255), fx = function(c)
    Orbiters(c.parent, c.at(0, 0.8, 0).Position, 4, c.w * 0.95, 0.9, 12, 8, Vector3.new(0.45, 0.9, 0.45), rgb(170, 230, 255), Enum.Material.Ice)   -- ice shards circling the top
    Floater(c.parent, c.at(0, 1.12, 0), Vector3.new(1.1, 1.1, 1.1), rgb(190, 240, 255), Enum.PartType.Ball, 0.45, 1.2)
    Mist(c.parent, c.at(0, 0.02, 0), c.w * 1.8, rgb(190, 235, 255), 4)
    Glitter(c.parent, c.at(0, 0.5, 0), Vector3.new(c.w, c.h * 0.7, c.w), rgb(180, 235, 255), 9)
end }

S.ForgeDecoration_LavaRiver = { height = 1.6, color = rgb(255, 110, 30), fx = function(c)
    -- bubbles popping and embers lifting off the flowing lava
    local pool = Part(c.parent, "DecorLavaBubbles", Vector3.new(c.w * 0.6, 0.2, c.d * 0.8), c.at(0, 0.6, 0), rgb(255, 120, 30), Enum.Material.Neon, { Transparency = 1 })
    Emitter(pool, { texture = SPARK, rate = 14, life = NumberRange.new(0.5, 1.1), speed = NumberRange.new(2, 5), spread = Vector2.new(35, 35), accel = Vector3.new(0, -6, 0),
        color = ColorSequence.new(rgb(255, 210, 90), rgb(255, 80, 20)), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }) })
    Emitter(pool, { texture = SPARK, rate = 6, life = NumberRange.new(1.4, 2.6), speed = NumberRange.new(3, 7), spread = Vector2.new(30, 30), accel = Vector3.new(0, 4, 0),
        color = ColorSequence.new(rgb(255, 190, 80), rgb(255, 70, 20)), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
    Emitter(pool, { texture = SMOKE, rate = 2, life = NumberRange.new(2, 3.2), speed = NumberRange.new(2, 3), glow = 0, color = ColorSequence.new(rgb(60, 52, 50)),
        size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) }), transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }) })
    Halo(c.parent, c.at(0, 0.5, 0), c.d * 0.9, rgb(255, 120, 30), 0.5, 0.9, 1.1)
    Light(pool, rgb(255, 120, 40), 20, 1.6, true)
end }

S.ForgeDecoration_LightningRod = { height = 13, color = rgb(190, 140, 255), fx = function(c)
    local tip = c.at(0, 0.97, 0).Position
    Floater(c.parent, CFrame.new(tip + Vector3.new(0, 0.2, 0)), Vector3.new(1.3, 1.3, 1.3), rgb(235, 215, 255), Enum.PartType.Ball, 0.12, 4)  -- a crackling orb at the tip
    for i = 1, 4 do                                                                                     -- bolts snapping out to the sides
        local a = (i / 4) * PI * 2
        Arc(c.parent, tip, tip + Vector3.new(math.cos(a) * 3.4, -1.4 - (i % 2) * 1.2, math.sin(a) * 3.4), rgb(215, 180, 255), 0.2)
    end
    Orbiters(c.parent, c.at(0, 0.72, 0).Position, 3, c.w * 0.8, 3.2, 0, 0, Vector3.new(0.35, 0.35, 0.35), rgb(215, 180, 255), Enum.Material.Neon, Enum.PartType.Ball)
    local sp = Part(c.parent, "DecorSparks", Vector3.new(0.6, 0.6, 0.6), CFrame.new(tip), rgb(220, 190, 255), Enum.Material.Neon, { Transparency = 1 })
    Emitter(sp, { texture = SPARK, rate = 22, life = NumberRange.new(0.3, 0.7), speed = NumberRange.new(5, 11), spread = Vector2.new(180, 180), accel = Vector3.new(0, -12, 0),
        color = ColorSequence.new(Color3.new(1, 1, 1), rgb(190, 140, 255)), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }) })
    Light(sp, rgb(200, 160, 255), 30, 2.4, true)
end }

S.ForgeDecoration_StormPillar = { height = 11, color = rgb(185, 135, 255), fx = function(c)
    local top = c.at(0, 0.96, 0).Position
    Floater(c.parent, CFrame.new(top + Vector3.new(0, 0.9, 0)), Vector3.new(1.1, 1.1, 1.1), rgb(225, 200, 255), Enum.PartType.Ball, 0.3, 2.2)   -- a storm orb above the cup
    for i = 1, 3 do
        local a = (i / 3) * PI * 2
        Arc(c.parent, top + Vector3.new(0, 0.9, 0), c.at(math.cos(a) * 0.9, 0.55, math.sin(a) * 0.9).Position, rgb(205, 165, 255), 0.18)   -- bolts down the column
    end
    Orbiters(c.parent, top, 4, c.w * 0.85, 2.4, 20, -14, Vector3.new(0.3, 0.3, 0.3), rgb(205, 165, 255), Enum.Material.Neon, Enum.PartType.Ball)
    Glitter(c.parent, c.at(0, 0.6, 0), Vector3.new(c.w, c.h * 0.8, c.w), rgb(205, 165, 255), 10)
    Light(c.parent:FindFirstChildWhichIsA("BasePart"), rgb(190, 140, 255), 26, 1.6, true)
end }

S.ForgeDecoration_VoidObelisk = { height = 12, color = rgb(190, 110, 255), fx = function(c)
    Orbiters(c.parent, c.at(0, 0.86, 0).Position, 4, c.w * 0.9, 1.0, 10, 14, Vector3.new(0.5, 0.9, 0.5), rgb(170, 90, 240), Enum.Material.Neon)       -- shards circling the tip
    Floater(c.parent, c.at(0, 1.1, 0), Vector3.new(0.9, 1.4, 0.9), rgb(205, 130, 255), Enum.PartType.Block, 0.35, 1.0)
    Halo(c.parent, c.at(0, 0.02, 0), c.w * 2.4, rgb(170, 90, 240), 0.3, 0.85, 0.9)
    local motes = Part(c.parent, "DecorMotes", Vector3.new(c.w, 1, c.w), c.at(0, 0.05, 0), rgb(170, 90, 240), Enum.Material.Neon, { Transparency = 1 })
    Emitter(motes, { texture = SPARK, rate = 12, life = NumberRange.new(3, 5), speed = NumberRange.new(1.5, 3.5), spread = Vector2.new(25, 25), accel = Vector3.new(0, 1.6, 0),
        color = ColorSequence.new(rgb(215, 150, 255), rgb(120, 50, 200)), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }) })
    Light(motes, rgb(170, 90, 240), 24, 1.5, true)
end }

S.ForgeDecoration_VoidPortal = { height = 9, color = rgb(185, 100, 255), fx = function(c)
    -- the swirl in the ring: two discs turning in opposite directions, with a bright core, and motes spiralling in
    local mid = c.at(0, 0.5, 0)
    SpinDisc(c.parent, mid * CFrame.new(0, 0, 0.05), c.w * 0.74, rgb(150, 60, 230), 0.4, 1.2, "X")
    SpinDisc(c.parent, mid * CFrame.new(0, 0, -0.05), c.w * 0.5, rgb(210, 140, 255), 0.45, -2.0, "X")
    Halo(c.parent, mid, c.w * 0.18, rgb(255, 230, 255), 0.1, 0.5, 1.8)
    local core = Part(c.parent, "DecorPortalMotes", Vector3.new(c.w * 0.5, c.w * 0.5, 0.4), mid, rgb(190, 110, 255), Enum.Material.Neon, { Transparency = 1 })
    Emitter(core, { texture = SPARK, rate = 24, life = NumberRange.new(1.2, 2.2), speed = NumberRange.new(0.5, 2), spread = Vector2.new(180, 180), accel = Vector3.new(0, 0.2, 0),
        color = ColorSequence.new(rgb(230, 170, 255), rgb(130, 60, 220)), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }), dir = Enum.NormalId.Front })
    Orbiters(c.parent, mid.Position, 5, c.w * 0.42, 1.5, 0, 0, Vector3.new(0.4, 0.4, 0.4), rgb(215, 150, 255), Enum.Material.Neon, Enum.PartType.Ball)
    Light(core, rgb(185, 100, 255), 30, 2.2, true)
end }

S.ForgeDecoration_PrimordialPillar = { height = 13, color = rgb(255, 210, 90), fx = function(c)
    -- golden runes spiralling up the pillar, a breathing aura at the base, gold dust drifting up
    Orbiters(c.parent, c.at(0, 0.5, 0).Position, 4, c.w * 0.95, 0.7, 0, 0, Vector3.new(0.5, 0.5, 0.15), rgb(255, 215, 100), Enum.Material.Neon)
    Orbiters(c.parent, c.at(0, 0.78, 0).Position, 3, c.w * 0.85, -1.0, 8, 6, Vector3.new(0.4, 0.4, 0.12), rgb(255, 235, 150), Enum.Material.Neon)
    Floater(c.parent, c.at(0, 1.1, 0), Vector3.new(1.3, 1.3, 1.3), rgb(255, 225, 130), Enum.PartType.Ball, 0.4, 1.1)
    Halo(c.parent, c.at(0, 0.02, 0), c.w * 2.6, rgb(255, 205, 80), 0.25, 0.8, 0.8)
    Glitter(c.parent, c.at(0, 0.5, 0), Vector3.new(c.w, c.h * 0.8, c.w), rgb(255, 215, 110), 12)
end }

-- ── Placing one ───────────────────────────────────────────────────────────────
-- cosmeticId: the decoration; groundCF: the CFrame at the ground where its base centre stands; parent: the forge model.
-- Returns the model, or nil if the mesh (or its spec) is not available.
function ForgeDecorFx.Place(cosmeticId, groundCF, parent)
    local spec = ForgeDecorFx.Specs[cosmeticId]
    if not spec or not ServerStorage.FindFirstChild then return nil end            -- (the test environment's ServerStorage is a bare stub)
    local folder = ServerStorage:FindFirstChild("ForgeDecorAssets")
    local template = folder and folder:FindFirstChild(cosmeticId)
    if not template then return nil end

    local group = Instance.new("Model")
    group.Name = "Decor_" .. cosmeticId
    group.Parent = parent

    local m = template:Clone()
    local meshes = {}
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored, d.CanCollide = true, false
            if d:IsA("MeshPart") then table.insert(meshes, d) end
        end
    end
    local ext = m:GetExtentsSize()
    m:ScaleTo(m:GetScale() * spec.height / math.max(ext.Y, 0.01))
    local box, size = m:GetBoundingBox()
    m:PivotTo(m:GetPivot() + (groundCF.Position + Vector3.new(0, size.Y / 2, 0) - box.Position))
    m.Name = "DecorMesh"
    m.Parent = group
    local _, finalSize = m:GetBoundingBox()

    -- a solid footprint (the mesh itself never collides, so players can't snag on its details)
    local footprint = Part(group, "DecorCollider", Vector3.new(math.max(finalSize.X * 0.7, 1), math.min(finalSize.Y, spec.height >= 4 and 6 or finalSize.Y), math.max(finalSize.Z * 0.7, 1)),
        groundCF * CFrame.new(0, math.min(finalSize.Y, spec.height >= 4 and 6 or finalSize.Y) / 2, 0), spec.color, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = true })

    local h, w, d = finalSize.Y, math.max(finalSize.X, finalSize.Z), finalSize.Z
    local ctx = { parent = group, h = h, w = w, d = d, base = groundCF.Position, top = groundCF.Position + Vector3.new(0, h, 0) }
    function ctx.at(rx, ry, rz) return groundCF * CFrame.new(rx * (finalSize.X / 2), ry * h, rz * (finalSize.Z / 2)) end
    local ok, err = pcall(spec.fx, ctx)
    if not ok then warn("[ForgeDecorFx] " .. cosmeticId .. ": " .. tostring(err)) end
    return group
end

return ForgeDecorFx
