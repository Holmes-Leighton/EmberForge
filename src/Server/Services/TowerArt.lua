-- Builds the Sky Tower out of parts: every level's platforms and obstacles (the same pieces as the Courier courses), a big numbered sign at each level's start, a colour
-- that changes with height, a glowing summit, and the portals (one in the hub, one back down). Everything static; the moving pieces are tagged for CourierController.
local CourierArt = require(script.Parent.CourierArt)
local TowerData  = require(game.ReplicatedStorage.Shared.Data.TowerData)

local TowerArt = {}

local P, Sign = CourierArt.P, CourierArt.Sign
local TIMBER = Color3.fromRGB(100, 70, 44)

-- Each level design has its own look: platform material and colours, and the glow colour of its edges
TowerArt.Themes = {
    wood      = { material = Enum.Material.Wood,         color = Color3.fromRGB(150, 104, 64),  rest = Color3.fromRGB(190, 140, 90),  accent = Color3.fromRGB(255, 190, 90), scaffold = true },
    sandstone = { material = Enum.Material.Sandstone,    color = Color3.fromRGB(196, 150, 100), rest = Color3.fromRGB(220, 180, 120), accent = Color3.fromRGB(255, 220, 130) },
    metal     = { material = Enum.Material.DiamondPlate, color = Color3.fromRGB(110, 116, 128), rest = Color3.fromRGB(150, 156, 168), accent = Color3.fromRGB(255, 160, 60), scaffold = true },
    neon      = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(70, 56, 110),  rest = Color3.fromRGB(96, 80, 150),   accent = Color3.fromRGB(120, 255, 230) },
    ice       = { material = Enum.Material.Ice,          color = Color3.fromRGB(150, 205, 245), rest = Color3.fromRGB(190, 230, 255), accent = Color3.fromRGB(170, 235, 255) },
    dark      = { material = Enum.Material.Basalt,       color = Color3.fromRGB(56, 48, 56),    rest = Color3.fromRGB(84, 72, 84),    accent = Color3.fromRGB(255, 120, 60), scaffold = true },
    glass     = { material = Enum.Material.Glass,        color = Color3.fromRGB(120, 200, 230), rest = Color3.fromRGB(160, 225, 245), accent = Color3.fromRGB(200, 250, 255) },
    slate     = { material = Enum.Material.Slate,        color = Color3.fromRGB(80, 84, 96),    rest = Color3.fromRGB(110, 114, 126), accent = Color3.fromRGB(200, 160, 255), scaffold = true },
    lava      = { material = Enum.Material.Basalt,       color = Color3.fromRGB(70, 36, 30),    rest = Color3.fromRGB(110, 52, 40),   accent = Color3.fromRGB(255, 90, 40), scaffold = true },
}

-- A hue that climbs through the rainbow with height, so players can see how high they are by colour
local function LevelColor(level, total)
    return Color3.fromHSV(0.02 + 0.72 * (level - 1) / math.max(1, total - 1), 0.75, 1)
end
TowerArt.LevelColor = LevelColor

local function Subset(list, level)
    local out = {}
    for _, item in ipairs(list) do if item.level == level then out[#out + 1] = item end end
    return out
end

-- The layout of one level, in the shape CourierArt's builders expect
local function LevelLayout(T, i, isLast)
    local lay = {
        platforms = Subset(T.platforms, i), movers = Subset(T.movers, i), crumbles = Subset(T.crumbles, i),
        spinners = Subset(T.spinners, i), crushers = Subset(T.crushers, i), checkpoints = Subset(T.checkpoints, i),
        trusses = Subset(T.trusses, i), bounces = Subset(T.bounces, i), sweepers = Subset(T.sweepers, i),
        base = T.base,
    }
    if isLast then lay.finish = T.finish end
    return lay
end

-- A glowing archway with a name: walk into the glow and `onEnter(player)` runs (no button). Used for the hub portal and the ways back.
function TowerArt.Portal(parent, position, facing, label, color, onEnter)
    local unit = Instance.new("Model")
    unit.Name = "TowerPortal"
    local f = CFrame.lookAt(position, position + facing)
    for _, side in ipairs({ -1, 1 }) do
        P({ Name = "PortalPost", Material = Enum.Material.Basalt, Color = Color3.fromRGB(58, 42, 38), Size = Vector3.new(4, 26, 4), CFrame = f * CFrame.new(side * 9, 13, 0) }, unit)
    end
    P({ Name = "PortalArch", Material = Enum.Material.Basalt, Color = Color3.fromRGB(58, 42, 38), Size = Vector3.new(22, 4, 4), CFrame = f * CFrame.new(0, 27, 0) }, unit)
    local gate = P({ Name = "PortalGlow", Material = Enum.Material.Neon, Color = color, Transparency = 0.45, Size = Vector3.new(14, 25, 2.4), CanCollide = false, CFrame = f * CFrame.new(0, 12.5, 0) }, unit)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = color, 50, 2.4
    light.Parent = gate
    local base = P({ Name = "PortalBase", Material = Enum.Material.Slate, Color = Color3.fromRGB(80, 64, 60), Size = Vector3.new(22, 1, 14), CFrame = f * CFrame.new(0, 0.5, 0) }, unit)
    Sign(unit, gate, label, UDim2.new(0, 280, 0, 60), Vector3.new(0, 18, 0), color, 150)
    local recent = {}                                                 -- userId -> last time it fired (so one step through is one trip)
    gate.Touched:Connect(function(hit)
        local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
        if not player or not onEnter then return end
        local now = os.clock()
        if recent[player.UserId] and now - recent[player.UserId] < 3 then return end
        recent[player.UserId] = now
        onEnter(player)
    end)
    unit.PrimaryPart = base
    unit.Parent = parent
    return unit
end

-- A construction scaffold around the whole tower: four tall steel poles at the corners with horizontal braces every few levels and X-braces between them, so the climb
-- happens inside a structure you can see all the way up (and down). Decorative: nothing here is solid, so it never blocks a jump.
local function Frame(folder, T)
    local lo, hi, zlo, zhi = 1e9, -1e9, 1e9, -1e9
    for _, p in ipairs(T.platforms) do
        lo, hi = math.min(lo, p.x - p.sx / 2), math.max(hi, p.x + p.sx / 2)
        zlo, zhi = math.min(zlo, p.z - p.sz / 2), math.max(zhi, p.z + p.sz / 2)
    end
    local m = 16
    lo, hi, zlo, zhi = lo - m, hi + m, zlo - m, zhi + m
    local y0, y1 = T.base.y - 40, (T.finish and T.finish.y or T.base.y) + 60
    local group = Instance.new("Folder")
    group.Name = "ScaffoldFrame"
    group.Parent = folder
    local STEEL, YELLOW = Color3.fromRGB(110, 116, 128), Color3.fromRGB(255, 200, 60)
    local function pole(x, z)
        P({ Name = "ScaffoldPole", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = STEEL, Size = Vector3.new(y1 - y0, 3, 3), CanCollide = false,
            CFrame = CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.pi / 2) }, group)
    end
    pole(lo, zlo) pole(lo, zhi) pole(hi, zlo) pole(hi, zhi)
    local function bar(a, b, name)
        local mid, span = (a + b) / 2, (b - a)
        P({ Name = name, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Color = STEEL, Size = Vector3.new(span.Magnitude, 1.4, 1.4), CanCollide = false,
            CFrame = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0) }, group)
    end
    local step = 40
    local flip = false
    for y = y0 + step, y1, step do
        bar(Vector3.new(lo, y, zlo), Vector3.new(hi, y, zlo), "BraceX")
        bar(Vector3.new(lo, y, zhi), Vector3.new(hi, y, zhi), "BraceX")
        bar(Vector3.new(lo, y, zlo), Vector3.new(lo, y, zhi), "BraceZ")
        bar(Vector3.new(hi, y, zlo), Vector3.new(hi, y, zhi), "BraceZ")
        if y + step <= y1 then                                              -- a diagonal in each bay, alternating, on the two long faces
            local a, b = flip and lo or hi, flip and hi or lo
            bar(Vector3.new(a, y, zlo), Vector3.new(b, y + step, zlo), "Diagonal")
            bar(Vector3.new(b, y, zhi), Vector3.new(a, y + step, zhi), "Diagonal")
            flip = not flip
        end
        for _, corner in ipairs({ { lo, zlo }, { lo, zhi }, { hi, zlo }, { hi, zhi } }) do      -- a yellow coupling band where the braces meet the poles
            P({ Name = "PoleBand", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = YELLOW, Size = Vector3.new(2, 3.6, 3.6), CanCollide = false,
                CFrame = CFrame.new(corner[1], y, corner[2]) * CFrame.Angles(0, 0, math.pi / 2) }, group)
        end
    end
end

-- Builds the whole tower for a layout T under `parent`. Returns the folder.
function TowerArt.Build(parent, T)
    local folder = Instance.new("Folder")
    folder.Name = "SkyTower"
    Frame(folder, T)
    for i, lv in ipairs(T.levels) do
        local color = LevelColor(i, T.total)
        local theme = TowerArt.Themes[lv.theme] or TowerArt.Themes.slate
        local r = { id = "Tower", def = { tier = lv.tier, color = theme.accent, look = theme }, layout = LevelLayout(T, i, i == T.total) }
        local group = Instance.new("Folder")
        group.Name = "Level" .. i
        group.Parent = folder
        CourierArt.Platforms(group, r)
        CourierArt.Obstacles(group, r)
        -- the level's number, big on a sign above its start platform (readable from the level below)
        local cp = r.layout.checkpoints[1]
        if cp then
            local anchor = P({ Name = "LevelSignAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(cp.x, cp.y + 14, cp.z) }, group)
            Sign(group, anchor, "LEVEL " .. i .. "\n" .. (lv.design or ""), UDim2.new(0, 280, 0, 84), Vector3.new(0, 0, 0), color, 220)
            local beam = P({ Name = "LevelBeam", Material = Enum.Material.Neon, Color = color, Transparency = 0.75, Size = Vector3.new(2, 40, 2), CanCollide = false,
                CFrame = CFrame.new(cp.x, cp.y + 17, cp.z) }, group)
            local light = Instance.new("PointLight")
            light.Color, light.Range, light.Brightness = color, 40, 1.4
            light.Parent = beam
        end
    end
    -- the summit: the drop-off ring and arch from the Courier art, in gold
    local lastLayout = LevelLayout(T, T.total, true)
    CourierArt.Finish(folder, { id = "Tower", def = { tier = 3, color = Color3.fromRGB(255, 215, 90) }, layout = lastLayout })
    folder.Parent = parent
    return folder
end

return TowerArt
