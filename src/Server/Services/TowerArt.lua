-- Builds the Sky Tower out of parts: every level's platforms and obstacles (the same pieces as the Courier courses), a big numbered sign at each level's start, a colour
-- that changes with height, a glowing summit, and the portals (one in the hub, one back down). Everything static; the moving pieces are tagged for CourierController.
local CourierArt = require(script.Parent.CourierArt)
local TowerData  = require(game.ReplicatedStorage.Shared.Data.TowerData)

local TowerArt = {}

local P, Sign = CourierArt.P, CourierArt.Sign
local TIMBER = Color3.fromRGB(100, 70, 44)

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
        base = T.base,
    }
    if isLast then lay.finish = T.finish end
    return lay
end

-- A glowing archway with a name, used for both portals
function TowerArt.Portal(parent, position, facing, label, color)
    local unit = Instance.new("Model")
    unit.Name = "TowerPortal"
    local f = CFrame.lookAt(position, position + facing)
    for _, side in ipairs({ -1, 1 }) do
        P({ Name = "PortalPost", Material = Enum.Material.Basalt, Color = Color3.fromRGB(58, 42, 38), Size = Vector3.new(4, 26, 4), CFrame = f * CFrame.new(side * 9, 13, 0) }, unit)
    end
    P({ Name = "PortalArch", Material = Enum.Material.Basalt, Color = Color3.fromRGB(58, 42, 38), Size = Vector3.new(22, 4, 4), CFrame = f * CFrame.new(0, 27, 0) }, unit)
    local gate = P({ Name = "PortalGlow", Material = Enum.Material.Neon, Color = color, Transparency = 0.45, Size = Vector3.new(14, 25, 0.6), CanCollide = false, CFrame = f * CFrame.new(0, 12.5, 0) }, unit)
    local light = Instance.new("PointLight")
    light.Color, light.Range, light.Brightness = color, 50, 2.4
    light.Parent = gate
    local base = P({ Name = "PortalBase", Material = Enum.Material.Slate, Color = Color3.fromRGB(80, 64, 60), Size = Vector3.new(22, 1, 14), CFrame = f * CFrame.new(0, 0.5, 0) }, unit)
    Sign(unit, gate, label, UDim2.new(0, 280, 0, 60), Vector3.new(0, 18, 0), color, 150)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PortalPrompt"
    prompt.ActionText = "Enter"
    prompt.ObjectText = label
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 16
    prompt.RequiresLineOfSight = false
    prompt.Parent = gate
    unit.PrimaryPart = base
    unit.Parent = parent
    return unit, prompt
end

-- Builds the whole tower for a layout T under `parent`. Returns the folder.
function TowerArt.Build(parent, T)
    local folder = Instance.new("Folder")
    folder.Name = "SkyTower"
    for i, lv in ipairs(T.levels) do
        local color = LevelColor(i, T.total)
        local r = { id = "Tower", def = { tier = lv.tier, color = color }, layout = LevelLayout(T, i, i == T.total) }
        local group = Instance.new("Folder")
        group.Name = "Level" .. i
        group.Parent = folder
        CourierArt.Platforms(group, r)
        CourierArt.Obstacles(group, r)
        -- the level's number, big on a sign above its start platform (readable from the level below)
        local cp = r.layout.checkpoints[1]
        if cp then
            local anchor = P({ Name = "LevelSignAnchor", Transparency = 1, CanCollide = false, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(cp.x, cp.y + 14, cp.z) }, group)
            Sign(group, anchor, "LEVEL " .. i, UDim2.new(0, 260, 0, 70), Vector3.new(0, 0, 0), color, 220)
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
