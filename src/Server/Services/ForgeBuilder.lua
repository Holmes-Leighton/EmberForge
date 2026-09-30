-- Builds the visible forge on a player's plot. It grows with Forge Level (spec 4.1) and each
-- level adds something you can see:
--   L1  fenced courtyard, open-fronted forge shed, anvil, workbench, barrels, coal
--   L2  lanterns on the fence, brighter forge glow
--   L3  enclosed stone workshop with pitched roof and chimney smoke
--   L4  metal conduits along the walls
--   L5  elemental braziers and lava channels
--   L6  second wing added to the workshop
--   L7  conveyor line
--   L8  animated gears, upper tower
--   L9  glowing runes in the courtyard
--   L10 kiln dome, aura ring, floating crystals
-- Also shown: a Storage Vault building once built, the owner's idle Golems on pedestals,
-- and banners/trophies that follow the player's own level.
-- Equipped cosmetics restyle it (skin colour/material, decoration).

local CollectionService = game:GetService("CollectionService")

local CosmeticData = require(game.ReplicatedStorage.Shared.Data.CosmeticData)
local GolemModel   = require(game.ReplicatedStorage.Shared.Modules.GolemModel)

local ForgeBuilder = {}

local SKIN_MATERIALS = {
    { words = { "Ember", "Lava", "Magma" },          material = Enum.Material.Brick },
    { words = { "Frost", "Ice", "Glacial" },         material = Enum.Material.Ice },
    { words = { "Storm", "Thunder" },                material = Enum.Material.Metal },
    { words = { "Void", "Shadow" },                  material = Enum.Material.Basalt },
    { words = { "Ancient", "Primordial", "Gold" },   material = Enum.Material.Marble },
    { words = { "Bronze", "Copper" },                material = Enum.Material.CorrodedMetal },
}

local DEFAULT_SKIN = { trim = false, color = Color3.fromRGB(95, 90, 88), material = Enum.Material.Cobblestone, fire = Color3.fromRGB(255, 140, 40) }

local function SkinFor(skinId)
    if not skinId then return DEFAULT_SKIN end
    local d = CosmeticData.Describe(skinId)
    local material = Enum.Material.Cobblestone
    for _, entry in ipairs(SKIN_MATERIALS) do
        for _, w in ipairs(entry.words) do
            if skinId:find(w) then material = entry.material end
        end
    end
    local color = d.color
    if skinId:find("Basic") or skinId:find("Bronze") then color = Color3.fromRGB(150, 120, 90) end
    local trim = not (skinId:find("Basic") or skinId:find("Bronze"))   -- Standard and premium skins glow
    return { color = color:Lerp(Color3.fromRGB(70, 70, 70), 0.25), material = material, fire = color, trim = trim, custom = true }
end

local GROUND = 1.2      -- top of the courtyard tiles

-- extra = { playerLevel = n, storageTier = n, golems = { idle Golems } }
function ForgeBuilder.Build(parent, center, level, equipped, extra)
    equipped = equipped or {}
    extra = extra or {}
    level = level or 1
    local skin = SkinFor(equipped.ForgeSkin)
    local model = Instance.new("Model")
    model.Name = "Forge"

    local wood   = Color3.fromRGB(110, 78, 50)
    local iron   = Color3.fromRGB(60, 60, 66)
    local roofC  = skin.color:Lerp(Color3.fromRGB(120, 50, 40), 0.35)
    local wallC  = skin.color:Lerp(Color3.new(1, 1, 1), 0.12)

    local function part(name, size, cf, color, material, props)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf
        p.Anchored = true
        p.Color = color or skin.color
        p.Material = material or skin.material
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        for k, v in pairs(props or {}) do p[k] = v end
        p.Parent = model
        return p
    end
    local function at(x, y, z) return CFrame.new(center.X + x, y, center.Z + z) end
    local function fireOn(p, size, heat, color)
        local f = Instance.new("Fire")
        f.Size, f.Heat = size, heat
        f.Color = color or skin.fire
        f.SecondaryColor = (color or skin.fire):Lerp(Color3.new(1, 1, 0.6), 0.5)
        f.Parent = p
        return f
    end
    local function light(p, color, range, brightness)
        local l = Instance.new("PointLight")
        l.Color, l.Range, l.Brightness = color, range, brightness
        l.Parent = p
    end
    local function spin(p, speed)
        p:SetAttribute("SpinSpeed", speed)
        CollectionService:AddTag(p, "EFSpin")
    end
    local function ball(name, d, cf, color, material, props)
        props = props or {}
        props.Shape = Enum.PartType.Ball
        return part(name, Vector3.new(d, d, d), cf, color, material, props)
    end

    -- ── Courtyard ─────────────────────────────────────────────────────────────
    part("Courtyard", Vector3.new(54, 0.4, 54), at(0, GROUND - 0.2, 0), skin.color:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate)
    part("Path", Vector3.new(6, 0.45, 40), at(0, GROUND - 0.15, 8), Color3.fromRGB(150, 140, 125), Enum.Material.Cobblestone)
    part("Hearth", Vector3.new(14, 0.5, 12), at(0, GROUND - 0.1, -12), Color3.fromRGB(45, 40, 40), Enum.Material.Basalt)

    -- Fence with a gate gap on the visitor side (+z)
    local FENCE = 26
    for i = -4, 4 do
        local x = i * 6.4
        for _, z in ipairs({ -FENCE, FENCE }) do
            if not (z == FENCE and math.abs(x) < 5) then
                local post = part("FencePost", Vector3.new(1, 4, 1), at(x, GROUND + 2, z), wood, Enum.Material.Wood)
                if level >= 2 and i % 2 == 0 then
                    local lamp = ball("Lantern", 1.1, at(x, GROUND + 4.6, z), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
                    light(lamp, Color3.fromRGB(255, 190, 110), 16, 1)
                end
            end
        end
        for _, xx in ipairs({ -FENCE, FENCE }) do
            part("FencePost", Vector3.new(1, 4, 1), at(xx, GROUND + 2, x), wood, Enum.Material.Wood)
        end
    end
    part("FenceRailBack", Vector3.new(54, 0.6, 0.6), at(0, GROUND + 3, -FENCE), wood, Enum.Material.Wood)
    part("FenceRailL", Vector3.new(0.6, 0.6, 54), at(-FENCE, GROUND + 3, 0), wood, Enum.Material.Wood)
    part("FenceRailR", Vector3.new(0.6, 0.6, 54), at(FENCE, GROUND + 3, 0), wood, Enum.Material.Wood)
    part("FenceRailFrontL", Vector3.new(20.5, 0.6, 0.6), at(-15.75, GROUND + 3, FENCE), wood, Enum.Material.Wood)
    part("FenceRailFrontR", Vector3.new(20.5, 0.6, 0.6), at(15.75, GROUND + 3, FENCE), wood, Enum.Material.Wood)

    -- Gate arch
    for _, x in ipairs({ -5, 5 }) do
        part("GatePillar", Vector3.new(2, 9, 2), at(x, GROUND + 4.5, FENCE), wallC, skin.material)
    end
    part("GateBeam", Vector3.new(12, 1.4, 2.2), at(0, GROUND + 9.5, FENCE), roofC, skin.material)
    local gateGlow = ball("GateEmber", 1.6, at(0, GROUND + 8.4, FENCE), skin.fire, Enum.Material.Neon)
    light(gateGlow, skin.fire, 14, 1.2)

    -- ── Workshop building (back of the plot) ──────────────────────────────────
    local enclosed = level >= 3
    local wide = level >= 6
    local W = wide and 34 or 22
    local D, H = 14, 10
    local bz = -16

    if enclosed then
        part("WallBack", Vector3.new(W, H, 1.4), at(0, GROUND + H / 2, bz - D / 2), wallC)
        part("WallL", Vector3.new(1.4, H, D), at(-W / 2, GROUND + H / 2, bz), wallC)
        part("WallR", Vector3.new(1.4, H, D), at(W / 2, GROUND + H / 2, bz), wallC)
        -- open front: two half walls with a wide doorway so the forge is visible from the courtyard
        for _, sgn in ipairs({ -1, 1 }) do
            part("WallFront", Vector3.new(W / 2 - 5, H, 1.4), at(sgn * (W / 4 + 2.5), GROUND + H / 2, bz + D / 2), wallC)
        end
        part("DoorLintel", Vector3.new(10, 2, 1.4), at(0, GROUND + H - 1, bz + D / 2), wallC)
        -- pitched roof
        local ang = 0.45
        local half = W / 2
        local len = half / math.cos(ang) + 1.5
        for _, sgn in ipairs({ -1, 1 }) do
            part("Roof", Vector3.new(len, 0.9, D + 3),
                at(sgn * half / 2, GROUND + H + half / 2 * math.tan(ang) + 0.4, bz) * CFrame.Angles(0, 0, -sgn * ang), roofC, Enum.Material.Slate)
        end
        part("RoofRidge", Vector3.new(1.2, 1.2, D + 3.4), at(0, GROUND + H + half * math.tan(ang) + 0.9, bz), roofC:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Slate)
    else
        -- Level 1-2: an open lean-to over the forge
        for _, x in ipairs({ -9, 9 }) do
            for _, z in ipairs({ bz - 5, bz + 5 }) do
                part("ShedPost", Vector3.new(1.2, 9, 1.2), at(x, GROUND + 4.5, z), wood, Enum.Material.Wood)
            end
        end
        part("ShedRoof", Vector3.new(22, 0.8, 13), at(0, GROUND + 9.6, bz) * CFrame.Angles(0.12, 0, 0), wood:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.WoodPlanks)
        part("ShedBack", Vector3.new(20, 8, 1), at(0, GROUND + 4, bz - 6), skin.color)
    end

    -- Furnace with mouth and chimney (always)
    part("Furnace", Vector3.new(9, 7, 6), at(0, GROUND + 3.5, bz - 3.5))
    local mouth = part("ForgeMouth", Vector3.new(3.6, 2.8, 0.3), at(0, GROUND + 2.6, bz - 0.4), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
    light(mouth, skin.fire, 20 + level * 2, 1.5 + level * 0.12)
    fireOn(mouth, 4 + level * 0.3, 8)
    local chimney = part("Chimney", Vector3.new(2.4, 12, 2.4), at(0, GROUND + 12, bz - 4.5))
    local smoke = Instance.new("Smoke")
    smoke.Size, smoke.RiseVelocity, smoke.Opacity = 3 + level * 0.4, 6, 0.3
    smoke.Color = Color3.fromRGB(80, 80, 80)
    smoke.Parent = chimney

    -- Smelter (left) and anvil (right)
    part("Smelter", Vector3.new(4.6, 5, 4.6), at(-11.5, GROUND + 2.5, bz - 2))
    local hatch = part("SmelterHatch", Vector3.new(2, 1.8, 0.3), at(-11.5, GROUND + 2.4, bz + 0.4), Color3.fromRGB(255, 90, 20), Enum.Material.Neon)
    light(hatch, Color3.fromRGB(255, 120, 40), 12, 1.2)
    part("SmelterPipe", Vector3.new(1, 5, 1), at(-11.5, GROUND + 7.5, bz - 3), iron, Enum.Material.Metal)
    part("AnvilBase", Vector3.new(2.4, 1.8, 1.6), at(11, GROUND + 0.9, bz + 1), wood, Enum.Material.Wood)
    part("AnvilTop", Vector3.new(4.2, 1, 1.9), at(11, GROUND + 2.3, bz + 1), Color3.fromRGB(105, 105, 115), Enum.Material.Metal)
    part("AnvilHorn", Vector3.new(1.8, 0.7, 1), at(13.2, GROUND + 2.3, bz + 1), Color3.fromRGB(105, 105, 115), Enum.Material.Metal)

    -- Workbench with tools, barrels, coal pile, crates, fire pit
    part("BenchTop", Vector3.new(7, 0.6, 2.6), at(-5, GROUND + 3, -5), wood, Enum.Material.WoodPlanks)
    for _, dx in ipairs({ -2.9, 2.9 }) do
        part("BenchLeg", Vector3.new(0.6, 3, 2), at(-5 + dx, GROUND + 1.5, -5), wood, Enum.Material.Wood)
    end
    part("Hammer", Vector3.new(0.4, 0.4, 2), at(-6.5, GROUND + 3.5, -5), wood, Enum.Material.Wood)
    part("HammerHead", Vector3.new(1.2, 0.8, 0.8), at(-6.5, GROUND + 3.6, -6), iron, Enum.Material.Metal)
    for i, pos in ipairs({ { 15, -8 }, { 17, -6.5 }, { 16, -4 } }) do
        part("Barrel", Vector3.new(2.2, 3, 2.2), at(pos[1], GROUND + 1.5, pos[2]), wood, Enum.Material.Wood, { Shape = i == 2 and Enum.PartType.Cylinder or Enum.PartType.Block })
    end
    for i = 1, 5 do
        part("Coal", Vector3.new(1.4 + (i % 2), 1 + (i % 3) * 0.4, 1.4), at(-17 + (i % 3) * 1.4, GROUND + 0.6 + (i > 3 and 0.9 or 0), -6 + (i % 2) * 1.6),
            Color3.fromRGB(28, 26, 26), Enum.Material.Slate, { Shape = Enum.PartType.Ball })
    end
    part("Crate", Vector3.new(3, 3, 3), at(-19, GROUND + 1.5, -10), wood, Enum.Material.WoodPlanks)
    local pit = part("FirePit", Vector3.new(0.8, 4, 4), at(0, GROUND + 0.5, 3) * CFrame.Angles(0, 0, math.pi / 2),
        Color3.fromRGB(35, 30, 28), Enum.Material.Basalt, { Shape = Enum.PartType.Cylinder })
    fireOn(pit, 5 + level * 0.3, 8)
    light(pit, skin.fire, 24, 1.6)

    -- ── Level advancements ────────────────────────────────────────────────────
    if level >= 4 then      -- metal conduits along the back wall
        for _, x in ipairs({ -8, -4, 4, 8 }) do
            part("Conduit", Vector3.new(0.7, H - 1, 0.7), at(x, GROUND + (H - 1) / 2, bz - D / 2 + 1), iron, Enum.Material.Metal)
        end
        part("ConduitCross", Vector3.new(18, 0.7, 0.7), at(0, GROUND + 6, bz - D / 2 + 1), iron, Enum.Material.Metal)
    end

    if level >= 5 then      -- elemental braziers + lava channels
        local flameColors = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(90, 180, 255), Color3.fromRGB(180, 110, 255) }
        for i, x in ipairs({ -10, 0, 10 }) do
            local brazier = part("Brazier", Vector3.new(2, 2.6, 2), at(x, GROUND + 1.3, 14), Color3.fromRGB(45, 40, 40), Enum.Material.Metal)
            fireOn(brazier, 5, 8, flameColors[i])
            light(brazier, flameColors[i], 16, 1.4)
        end
        for _, x in ipairs({ -3, 0, 3 }) do
            part("LavaChannel", Vector3.new(0.9, 0.2, 12), at(x, GROUND + 0.1, -4), Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
        end
    end

    if level >= 6 then      -- side wing pillars + second chimney
        for _, sgn in ipairs({ -1, 1 }) do
            local c2 = part("WingChimney", Vector3.new(2, 9, 2), at(sgn * 13, GROUND + H + 3, bz - 2))
            local sm = Instance.new("Smoke")
            sm.Size, sm.RiseVelocity, sm.Opacity = 3, 5, 0.25
            sm.Parent = c2
        end
    end

    if level >= 7 then
        part("Conveyor", Vector3.new(26, 0.6, 2.2), at(0, GROUND + 0.5, bz + 5.5), Color3.fromRGB(45, 45, 52), Enum.Material.Metal)
        for i = -5, 5 do
            part("ConveyorRoller", Vector3.new(0.5, 0.5, 2.4), at(i * 2.4, GROUND + 0.95, bz + 5.5), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
        end
    end

    if level >= 8 then      -- gears on the wall + an upper tower
        for _, x in ipairs({ -6, 6 }) do
            local gear = part("Gear", Vector3.new(1, 7, 7), at(x, GROUND + 7, bz + D / 2 + 1) * CFrame.Angles(0, math.pi / 2, 0),
                Color3.fromRGB(140, 140, 150), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
            spin(gear, x < 0 and 1.2 or -1.2)
            local hub = part("GearHub", Vector3.new(1.2, 2, 2), at(x, GROUND + 7, bz + D / 2 + 1.5) * CFrame.Angles(0, math.pi / 2, 0),
                Color3.fromRGB(255, 190, 80), Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })
            spin(hub, x < 0 and 1.2 or -1.2)
        end
        part("TowerBase", Vector3.new(6, 8, 6), at(-W / 2 - 2, GROUND + 4, bz), wallC)
        part("TowerCap", Vector3.new(7.4, 1, 7.4), at(-W / 2 - 2, GROUND + 8.5, bz), roofC, Enum.Material.Slate)
        local beacon = ball("TowerBeacon", 2, at(-W / 2 - 2, GROUND + 10, bz), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
        light(beacon, Color3.fromRGB(255, 170, 60), 30, 2)
    end

    if level >= 9 then      -- runes glowing in the courtyard
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            part("Rune", Vector3.new(2.4, 0.15, 0.7), at(math.cos(a) * 11, GROUND + 0.25, 4 + math.sin(a) * 11)
                * CFrame.Angles(0, -a, 0), skin.fire, Enum.Material.Neon)
        end
    end

    if level >= 10 then     -- kiln dome, aura, floating crystals
        local dome = ball("KilnDome", 14, at(0, GROUND + H + 8, bz - 8), skin.color:Lerp(Color3.new(1, 1, 1), 0.1), skin.material)
        local door = part("KilnDoor", Vector3.new(4, 5, 0.4), at(0, GROUND + 3.5, bz + 0.2), Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
        light(door, Color3.fromRGB(255, 200, 100), 40, 3)
        part("AuraRing", Vector3.new(0.4, 50, 50), at(0, GROUND + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
            skin.fire, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.4, CanCollide = false })
        for i = 1, 4 do
            local a = i / 4 * math.pi * 2 + 0.6
            local crystal = part("Crystal", Vector3.new(1.4, 3.2, 1.4), at(math.cos(a) * 16, GROUND + 9, 4 + math.sin(a) * 16) * CFrame.Angles(0.3, a, 0.3),
                skin.fire, Enum.Material.Neon, { Transparency = 0.2 })
            spin(crystal, 0.8)
            light(crystal, skin.fire, 14, 1)
        end
        local sparkle = Instance.new("ParticleEmitter")
        sparkle.Color = ColorSequence.new(skin.fire)
        sparkle.Rate = 10
        sparkle.Lifetime = NumberRange.new(3, 5)
        sparkle.Speed = NumberRange.new(2, 4)
        sparkle.SpreadAngle = Vector2.new(180, 180)
        sparkle.LightEmission = 1
        sparkle.Size = NumberSequence.new(0.6)
        sparkle.Parent = dome
    end

    -- ── Storage Vault building ────────────────────────────────────────────────
    if (extra.storageTier or 0) >= 1 then
        part("VaultBody", Vector3.new(9, 7, 7), at(21, GROUND + 3.5, -20), iron:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Metal)
        part("VaultRoof", Vector3.new(10, 1, 8), at(21, GROUND + 7.5, -20), roofC, Enum.Material.Slate)
        local vd = part("VaultDoor", Vector3.new(0.5, 4.4, 4.4), at(16.4, GROUND + 3.4, -20), Color3.fromRGB(200, 165, 60), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
        light(vd, Color3.fromRGB(255, 220, 120), 10, 0.8)
    end

    -- ── Player-level banners and trophies (cosmetic only) ─────────────────────
    local pl = extra.playerLevel or 1
    local banners = pl >= 30 and 4 or pl >= 20 and 3 or pl >= 10 and 2 or pl >= 5 and 1 or 0
    for i = 1, banners do
        local x = (i % 2 == 0 and 1 or -1) * (6 + math.floor((i - 1) / 2) * 6)
        part("BannerPole", Vector3.new(0.5, 9, 0.5), at(x, GROUND + 4.5, 21), wood, Enum.Material.Wood)
        part("Banner", Vector3.new(3, 5, 0.25), at(x + 1.7, GROUND + 6.5, 21), Color3.fromRGB(190, 45, 40):Lerp(skin.fire, 0.3), Enum.Material.Fabric)
    end
    if pl >= 25 then
        part("TrophyBase", Vector3.new(2.4, 1.4, 2.4), at(-22, GROUND + 0.7, -22), Color3.fromRGB(80, 75, 72), Enum.Material.Marble)
        local cup = ball("Trophy", 2.2, at(-22, GROUND + 2.6, -22), Color3.fromRGB(255, 205, 70), Enum.Material.Neon)
        light(cup, Color3.fromRGB(255, 205, 70), 12, 1)
    end

    -- ── Golem gallery: your idle Golems on pedestals ──────────────────────────
    local shown = 0
    for i, g in ipairs(extra.golems or {}) do
        if shown >= 5 then break end
        shown += 1
        local x = -16 + (shown - 1) * 8
        part("Pedestal", Vector3.new(4.4, 1.4, 4.4), at(x, GROUND + 0.7, 18), Color3.fromRGB(85, 80, 78), Enum.Material.Marble)
        local ok, gm = pcall(function()
            return GolemModel.Build(g.element, g.tier or 1, { variant = g.variant })
        end)
        if ok and gm then
            gm.Name = "GalleryGolem"
            for _, d in ipairs(gm:GetDescendants()) do
                if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
            end
            pcall(function() gm:ScaleTo(0.42) end)
            pcall(function() gm:PivotTo(at(x, GROUND + 1.4 + 2.4, 18) * CFrame.Angles(0, math.pi, 0)) end)
            gm.Parent = model
        end
    end

    -- ── Skin trim: Standard / premium skins outline the forge in glowing colour ──
    if skin.trim then
        part("TrimFront", Vector3.new(54, 0.3, 0.5), at(0, GROUND + 0.15, -FENCE + 0.6), skin.fire, Enum.Material.Neon)
        part("TrimLeft", Vector3.new(0.5, 0.3, 54), at(-FENCE + 0.6, GROUND + 0.15, 0), skin.fire, Enum.Material.Neon)
        part("TrimRight", Vector3.new(0.5, 0.3, 54), at(FENCE - 0.6, GROUND + 0.15, 0), skin.fire, Enum.Material.Neon)
        part("TrimBeam", Vector3.new(12.2, 0.3, 2.4), at(0, GROUND + 8.7, FENCE), skin.fire, Enum.Material.Neon)
    end

    -- ── Equipped forge effect: animated glow around the forge ─────────────────
    if equipped.ForgeEffect then
        local d = CosmeticData.Describe(equipped.ForgeEffect)
        local c = d.color
        for i = 1, 6 do
            local a = i / 6 * math.pi * 2
            local orb = ball("EffectOrb", 1.6, at(math.cos(a) * 20, GROUND + 3, math.sin(a) * 20), c, Enum.Material.Neon, { Transparency = 0.15 })
            light(orb, c, 14, 1.2)
            local em = Instance.new("ParticleEmitter")
            em.Color = ColorSequence.new(c)
            em.Rate = 12
            em.Lifetime = NumberRange.new(1.5, 2.5)
            em.Speed = NumberRange.new(3, 6)
            em.SpreadAngle = Vector2.new(25, 25)
            em.LightEmission = 1
            em.Size = NumberSequence.new(0.8, 0)
            em.Parent = orb
        end
        local ringFx = part("EffectRing", Vector3.new(0.3, 40, 40), at(0, GROUND + 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), c,
            Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.5, CanCollide = false })
        spin(ringFx, 0.5)
    end

    -- ── Equipped decoration: each kind has its own shape ──────────────────────
    if equipped.ForgeDecoration then
        local id = equipped.ForgeDecoration
        local d = CosmeticData.Describe(id)
        local c = d.color
        local dark = c:Lerp(Color3.new(0, 0, 0), 0.45)
        local X, Z = 21, 21
        part("DecorBase", Vector3.new(5, 1, 5), at(X, GROUND + 0.5, Z), Color3.fromRGB(70, 65, 65), Enum.Material.Slate)
        local top
        if id:find("Statue") then                                   -- a figure: legs, torso, head, raised arm
            part("DecorLegs", Vector3.new(2.2, 2.5, 1.2), at(X, GROUND + 2.75, Z), dark, Enum.Material.Marble)
            part("DecorTorso", Vector3.new(2.8, 3, 1.6), at(X, GROUND + 5.5, Z), dark, Enum.Material.Marble)
            part("DecorArm", Vector3.new(0.8, 3, 0.8), at(X + 1.9, GROUND + 7, Z) * CFrame.Angles(0, 0, -0.4), dark, Enum.Material.Marble)
            top = ball("DecorHead", 2, at(X, GROUND + 8, Z), c, Enum.Material.Neon)
        elseif id:find("Portal") then                               -- glowing ring standing upright
            top = part("DecorPortal", Vector3.new(0.6, 7, 7), at(X, GROUND + 5, Z) * CFrame.Angles(0, math.pi / 4, 0), c,
                Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.2 })
            part("DecorPortalCore", Vector3.new(0.3, 5, 5), at(X, GROUND + 5, Z) * CFrame.Angles(0, math.pi / 4, 0), dark,
                Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.5 })
        elseif id:find("Obelisk") then
            part("DecorObelisk", Vector3.new(2, 9, 2), at(X, GROUND + 5.5, Z), dark, Enum.Material.Basalt)
            top = part("DecorTip", Vector3.new(1.6, 1.6, 1.6), at(X, GROUND + 10.8, Z) * CFrame.Angles(0.8, 0.8, 0), c, Enum.Material.Neon)
        elseif id:find("Rod") then                                  -- tall thin rod with arcs
            part("DecorRod", Vector3.new(0.6, 11, 0.6), at(X, GROUND + 6.5, Z), Color3.fromRGB(170, 170, 185), Enum.Material.Metal)
            top = ball("DecorSpark", 1.8, at(X, GROUND + 12.4, Z), c, Enum.Material.Neon)
            for i = 1, 3 do
                part("DecorArc", Vector3.new(0.25, 3, 0.25), at(X + (i - 2) * 1.3, GROUND + 11, Z) * CFrame.Angles(0, 0, (i - 2) * 0.6), c, Enum.Material.Neon)
            end
        elseif id:find("Altar") then
            part("DecorAltar", Vector3.new(5, 2, 3), at(X, GROUND + 2, Z), dark, Enum.Material.Marble)
            top = part("DecorFlame", Vector3.new(1.4, 1.4, 1.4), at(X, GROUND + 3.6, Z), c, Enum.Material.Neon)
            fireOn(top, 6, 9, c)
        elseif id:find("River") then                                -- glowing channel with a fiery pool
            part("DecorChannel", Vector3.new(2.2, 0.35, 8), at(X, GROUND + 1.1, Z), c, Enum.Material.Neon)
            top = part("DecorPool", Vector3.new(4.5, 0.4, 4.5), at(X, GROUND + 1.15, Z + 5), c, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })
            fireOn(top, 4, 6, c)
        elseif id:find("Pillar") then
            part("DecorColumn", Vector3.new(2.4, 8, 2.4), at(X, GROUND + 5, Z), dark, Enum.Material.Marble)
            part("DecorCap", Vector3.new(3.4, 0.8, 3.4), at(X, GROUND + 9.4, Z), c:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Marble)
            top = ball("DecorOrb", 2.2, at(X, GROUND + 10.9, Z), c, Enum.Material.Neon)
        elseif id:find("Anvil") then
            part("DecorAnvilBase", Vector3.new(2.6, 2, 2), at(X, GROUND + 2, Z), dark, Enum.Material.Metal)
            top = part("DecorAnvilTop", Vector3.new(5, 1.2, 2.4), at(X, GROUND + 3.6, Z), c:Lerp(Color3.fromRGB(150, 150, 160), 0.5), Enum.Material.Metal)
        else
            part("DecorColumn", Vector3.new(2, 6, 2), at(X, GROUND + 4, Z), dark, Enum.Material.Marble)
            top = ball("DecorOrb", 2.6, at(X, GROUND + 8.4, Z), c, Enum.Material.Neon)
        end
        light(top, c, 20, 1.5)
    end

    model.Parent = parent
    return model
end

-- Level-up flourish: a burst of embers over the forge
function ForgeBuilder.Celebrate(model)
    if not model or not model.Parent then return end
    local anchor = model:FindFirstChild("Furnace") or model:FindFirstChildWhichIsA("BasePart")
    if not anchor then return end
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
    e.Lifetime = NumberRange.new(1.5, 2.5)
    e.Speed = NumberRange.new(20, 40)
    e.SpreadAngle = Vector2.new(60, 60)
    e.LightEmission = 1
    e.Size = NumberSequence.new(1.2, 0)
    e.Rate = 0
    e.Parent = anchor
    pcall(function() e:Emit(120) end)
    task.delay(4, function() if e.Parent then e:Destroy() end end)
end

return ForgeBuilder
