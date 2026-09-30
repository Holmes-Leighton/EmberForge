-- Builds the visible forge on a player's plot. It grows with Forge Level (spec 4.1):
--   L1  small stone forge, fire pit, smelter, anvil
--   L3  expanded workshop: pillars, roof, glow
--   L5  elemental flames and lava channels
--   L8  full complex with animated machinery (gears spin on every client)
--   L10 grand forge: kiln dome and an elemental aura ring
-- Equipped cosmetics restyle it (skin colour/material, decoration).

local CollectionService = game:GetService("CollectionService")

local CosmeticData = require(game.ReplicatedStorage.Shared.Data.CosmeticData)

local ForgeBuilder = {}

local SKIN_MATERIALS = {
    { words = { "Ember", "Lava", "Magma" },          material = Enum.Material.Brick },
    { words = { "Frost", "Ice", "Glacial" },         material = Enum.Material.Ice },
    { words = { "Storm", "Thunder" },                material = Enum.Material.Metal },
    { words = { "Void", "Shadow" },                  material = Enum.Material.Basalt },
    { words = { "Ancient", "Primordial", "Gold" },   material = Enum.Material.Marble },
    { words = { "Bronze", "Copper" },                material = Enum.Material.CorrodedMetal },
}

local DEFAULT_SKIN = { color = Color3.fromRGB(95, 90, 88), material = Enum.Material.Cobblestone, fire = Color3.fromRGB(255, 140, 40) }

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
    return { color = color:Lerp(Color3.fromRGB(70, 70, 70), 0.25), material = material, fire = color }
end

function ForgeBuilder.Build(parent, center, level, equipped)
    equipped = equipped or {}
    local skin = SkinFor(equipped.ForgeSkin)
    local model = Instance.new("Model")
    model.Name = "Forge"

    local function part(name, size, cf, color, material, extra)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf
        p.Anchored = true
        p.Color = color or skin.color
        p.Material = material or skin.material
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        for k, v in pairs(extra or {}) do p[k] = v end
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

    -- ── Level 1 ───────────────────────────────────────────────────────────────
    part("StoneForge", Vector3.new(8, 6, 6), at(0, 4, -10))
    local mouth = part("ForgeMouth", Vector3.new(3.4, 2.6, 0.3), at(0, 3.2, -6.9), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
    light(mouth, skin.fire, 26, 2)

    local pit = part("FirePit", Vector3.new(1, 5, 5), at(0, 1.5, 4) * CFrame.Angles(0, 0, math.pi / 2),
        Color3.fromRGB(35, 30, 28), Enum.Material.Basalt, { Shape = Enum.PartType.Cylinder })
    fireOn(pit, 7, 9)
    light(pit, skin.fire, 30, 2)

    -- smelter: furnace box with a glowing hatch
    part("Smelter", Vector3.new(5, 5, 5), at(-14, 3.5, -8))
    local hatch = part("SmelterHatch", Vector3.new(2, 1.8, 0.3), at(-14, 3, -5.4), Color3.fromRGB(255, 90, 20), Enum.Material.Neon)
    light(hatch, Color3.fromRGB(255, 120, 40), 14, 1.5)
    part("SmelterChimney", Vector3.new(1.6, 4, 1.6), at(-14, 8, -9))

    -- anvil
    part("AnvilBase", Vector3.new(2.4, 1.6, 1.6), at(14, 1.8, -8), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
    part("AnvilTop", Vector3.new(4.2, 1, 1.9), at(14, 3.1, -8), Color3.fromRGB(105, 105, 115), Enum.Material.Metal)

    -- ── Level 3: workshop ─────────────────────────────────────────────────────
    if level >= 3 then
        for _, x in ipairs({ -18, 18 }) do
            for _, z in ipairs({ -16, 8 }) do
                part("Pillar", Vector3.new(2, 14, 2), at(x, 8, z))
            end
        end
        part("Roof", Vector3.new(42, 1.2, 28), at(0, 15.6, -4), skin.color:Lerp(Color3.new(0, 0, 0), 0.25))
        for _, x in ipairs({ -10, 10 }) do
            local lamp = part("Lamp", Vector3.new(1.4, 1.4, 1.4), at(x, 13.5, -4), Color3.fromRGB(255, 200, 120), Enum.Material.Neon,
                { Shape = Enum.PartType.Ball })
            light(lamp, Color3.fromRGB(255, 190, 110), 32, 1.6)
        end
    end

    -- ── Level 5: elemental flames + lava channels ─────────────────────────────
    if level >= 5 then
        local flameColors = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(90, 180, 255), Color3.fromRGB(180, 110, 255) }
        for i, x in ipairs({ -8, 0, 8 }) do
            local brazier = part("Brazier", Vector3.new(2, 2.4, 2), at(x, 2.2, 14), Color3.fromRGB(45, 40, 40), Enum.Material.Metal)
            fireOn(brazier, 5, 8, flameColors[i])
            light(brazier, flameColors[i], 16, 1.4)
        end
        for i, x in ipairs({ -3, 0, 3 }) do
            part("LavaChannel", Vector3.new(1.1, 0.3, 14), at(x, 1.15, -1), Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
        end
    end

    -- ── Level 8: animated machinery ───────────────────────────────────────────
    if level >= 8 then
        for _, x in ipairs({ -8, 8 }) do
            local gear = part("Gear", Vector3.new(1, 7, 7), at(x, 9, -13.3) * CFrame.Angles(0, math.pi / 2, 0),
                Color3.fromRGB(140, 140, 150), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
            gear:SetAttribute("SpinSpeed", x < 0 and 1.2 or -1.2)
            CollectionService:AddTag(gear, "EFSpin")
            local hub = part("GearHub", Vector3.new(1.2, 2, 2), at(x, 9, -13.6) * CFrame.Angles(0, math.pi / 2, 0),
                Color3.fromRGB(255, 190, 80), Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })
            hub:SetAttribute("SpinSpeed", x < 0 and 1.2 or -1.2)
            CollectionService:AddTag(hub, "EFSpin")
        end
        part("Conveyor", Vector3.new(30, 0.6, 2.4), at(0, 1.3, -14), Color3.fromRGB(45, 45, 52), Enum.Material.Metal)
    end

    -- ── Level 10: grand forge ─────────────────────────────────────────────────
    if level >= 10 then
        local dome = part("KilnDome", Vector3.new(15, 15, 15), at(0, 6, -22), skin.color:Lerp(Color3.new(1, 1, 1), 0.1),
            skin.material, { Shape = Enum.PartType.Ball })
        local door = part("KilnDoor", Vector3.new(4, 5, 0.4), at(0, 3.5, -14.9), Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
        light(door, Color3.fromRGB(255, 200, 100), 40, 3)
        local ring = part("AuraRing", Vector3.new(0.4, 56, 56), at(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
            skin.fire, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.35, CanCollide = false })
        local sparkle = Instance.new("ParticleEmitter")
        sparkle.Color = ColorSequence.new(skin.fire)
        sparkle.Rate = 8
        sparkle.Lifetime = NumberRange.new(3, 5)
        sparkle.Speed = NumberRange.new(2, 4)
        sparkle.SpreadAngle = Vector2.new(180, 180)
        sparkle.LightEmission = 1
        sparkle.Size = NumberSequence.new(0.6)
        sparkle.Parent = dome
    end

    -- ── Equipped decoration: a small monument in the plot corner ──────────────
    if equipped.ForgeDecoration then
        local d = CosmeticData.Describe(equipped.ForgeDecoration)
        part("DecorBase", Vector3.new(4, 1, 4), at(22, 1.5, 20), Color3.fromRGB(70, 65, 65), Enum.Material.Slate)
        local column = part("DecorColumn", Vector3.new(2, 6, 2), at(22, 5, 20), d.color:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.Marble)
        local orb = part("DecorOrb", Vector3.new(2.6, 2.6, 2.6), at(22, 9.4, 20), d.color, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
        light(orb, d.color, 20, 1.5)
    end

    model.Parent = parent
    return model
end

return ForgeBuilder
