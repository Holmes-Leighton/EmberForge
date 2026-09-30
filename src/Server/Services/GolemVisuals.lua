-- Shows every player's deployed Golems in the world: a little blocky Golem swinging a
-- pickaxe on the pad of the mining zone it was sent to.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme             = require(game.ReplicatedStorage.Shared.Modules.Theme)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldBuilder      = require(script.Parent.WorldBuilder)

local GolemVisuals = {}

local RING_RADIUS = 30
local SLOTS       = 10          -- golems per zone ring before they start to overlap
local GROUND_Y    = 2           -- top of the zone pads

local entries = {}              -- golemId → { model, base, armL, armR, pick, zoneId, slot, phase }
local usedSlots = {}            -- zoneId → { [slot] = true }
local folder

local function Part(parent, name, size, color, material, transparency)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.Slate
    p.Transparency = transparency or 0
    p.Anchored = true
    p.CanCollide = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function FreeSlot(zoneId)
    usedSlots[zoneId] = usedSlots[zoneId] or {}
    for i = 0, SLOTS * 3 do
        if not usedSlots[zoneId][i] then
            usedSlots[zoneId][i] = true
            return i
        end
    end
    return 0
end

local function Build(golem, ownerName)
    local center = WorldBuilder.GetZoneCenter(golem.zoneId)
    if not center then return nil end

    local slot = FreeSlot(golem.zoneId)
    local angle = (slot % SLOTS) / SLOTS * math.pi * 2
    local radius = RING_RADIUS + math.floor(slot / SLOTS) * 8
    local pos = center + Vector3.new(math.cos(angle) * radius, GROUND_Y, math.sin(angle) * radius)
    local base = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))

    local color = Theme.Colors[golem.element] or Color3.fromRGB(150, 150, 150)
    local dark  = color:Lerp(Color3.new(0, 0, 0), 0.35)
    local scale = 1 + ((golem.tier or 1) - 1) * 0.18

    local model = Instance.new("Model")
    model.Name = "Golem_" .. golem.id
    local function place(part, offset) part.CFrame = base * CFrame.new(offset * scale) end

    local torso = Part(model, "Torso", Vector3.new(3.2, 4, 2) * scale, color)
    place(torso, Vector3.new(0, 5, 0))
    local head = Part(model, "Head", Vector3.new(2.4, 2.2, 2.4) * scale, dark)
    place(head, Vector3.new(0, 8.3, 0))
    for _, side in ipairs({ -0.6, 0.6 }) do
        local eye = Part(model, "Eye", Vector3.new(0.5, 0.4, 0.2) * scale, color:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon)
        place(eye, Vector3.new(side * 1.1, 8.5, -1.25))
    end
    for _, side in ipairs({ -0.85, 0.85 }) do
        local leg = Part(model, "Leg", Vector3.new(1.3, 3, 1.4) * scale, dark)
        place(leg, Vector3.new(side * 1, 1.5, 0))
    end
    local armL = Part(model, "ArmL", Vector3.new(1.1, 3, 1.1) * scale, dark)
    local armR = Part(model, "ArmR", Vector3.new(1.1, 3, 1.1) * scale, dark)
    local handle = Part(model, "PickHandle", Vector3.new(0.4, 0.4, 3.4) * scale, Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
    local pickHead = Part(model, "PickHead", Vector3.new(2.8, 0.5, 0.5) * scale, Color3.fromRGB(190, 190, 200), Enum.Material.Metal)

    local tag = Instance.new("BillboardGui")
    tag.Size = UDim2.new(0, 200, 0, 34)
    tag.StudsOffset = Vector3.new(0, 4.5, 0)
    tag.MaxDistance = 120
    tag.Adornee = head
    tag.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("%s's %s Golem", ownerName, tostring(golem.element))
    lbl.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.4
    lbl.Parent = tag

    model.Parent = folder
    return {
        model = model, base = base, scale = scale, armL = armL, armR = armR,
        handle = handle, pickHead = pickHead, zoneId = golem.zoneId, slot = slot,
        phase = math.random() * math.pi * 2,
    }
end

local function Remove(id)
    local e = entries[id]
    if not e then return end
    if usedSlots[e.zoneId] then usedSlots[e.zoneId][e.slot] = nil end
    e.model:Destroy()
    entries[id] = nil
end

local function Reconcile()
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataService.Get(player)
        for _, g in ipairs(data and data.Golems or {}) do
            if g.deployed and g.zoneId then
                seen[g.id] = true
                local e = entries[g.id]
                if e and e.zoneId ~= g.zoneId then Remove(g.id); e = nil end
                if not e then entries[g.id] = Build(g, player.DisplayName) end
            end
        end
    end
    for id in pairs(entries) do
        if not seen[id] then Remove(id) end
    end
end

local function Animate()
    local t = os.clock()
    for _, e in pairs(entries) do
        local s = e.scale
        local swing = math.sin(t * 4 + e.phase) * 0.9 - 0.4
        e.armL.CFrame = e.base * CFrame.new(-2.2 * s, 6.5 * s, 0) * CFrame.Angles(-0.3 - swing * 0.3, 0, 0) * CFrame.new(0, -1.5 * s, 0)
        e.armR.CFrame = e.base * CFrame.new(2.2 * s, 6.5 * s, 0) * CFrame.Angles(swing - 0.8, 0, 0) * CFrame.new(0, -1.5 * s, 0)
        -- pickaxe rides on the right hand
        local hand = e.armR.CFrame * CFrame.new(0, -1.4 * s, -1.4 * s)
        e.handle.CFrame = hand
        e.pickHead.CFrame = hand * CFrame.new(0, 0, -1.6 * s)
    end
end

function GolemVisuals.Init()
    folder = Instance.new("Folder")
    folder.Name = "DeployedGolems"
    folder.Parent = workspace:FindFirstChild("EmberWorld") or workspace

    task.spawn(function()
        while true do
            task.wait(1)
            Reconcile()
        end
    end)
    RunService.Heartbeat:Connect(Animate)
end

return GolemVisuals
