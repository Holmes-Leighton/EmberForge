-- Puts every player's deployed Golems into the world, standing in the mining zone they were sent to.
-- The server only creates and removes the models; the arm/pickaxe swing and Neon colour effects
-- are animated by each client (GolemAnimator), so 20 players x 12 Golems cost the server nothing per frame.

local Players = game:GetService("Players")

local GolemModel        = require(game.ReplicatedStorage.Shared.Modules.GolemModel)
local GolemNames        = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldBuilder      = require(script.Parent.WorldBuilder)

local GolemVisuals = {}

local RING_RADIUS = 30
local SLOTS       = 10          -- Golems per zone ring before a second ring starts
local GROUND_Y    = 2           -- top of the zone pads

local entries   = {}            -- golemId -> { model, zoneId, slot, variant }
local usedSlots = {}            -- zoneId -> { [slot] = true }
local folder

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

local function StyleKey(golem, equipped)
    return table.concat({ golem.variant or "", golem.zoneId or "", equipped.GolemAccessory or "", equipped.ParticleEffect or "" }, "|")
end

local function Build(golem, ownerName, equipped)
    local center = WorldBuilder.GetZoneCenter(golem.zoneId)
    if not center then return nil end

    local slot   = FreeSlot(golem.zoneId)
    local angle  = (slot % SLOTS) / SLOTS * math.pi * 2
    local radius = RING_RADIUS + math.floor(slot / SLOTS) * 8
    local pos    = center + Vector3.new(math.cos(angle) * radius, GROUND_Y, math.sin(angle) * radius)
    local base   = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
    local scale  = 1 + ((golem.tier or 1) - 1) * 0.18

    local model = GolemModel.Build(golem.element, golem.tier, {
        variant = golem.variant, accessory = equipped.GolemAccessory, particle = equipped.ParticleEffect,
    })
    model.Name = "Golem_" .. golem.id
    model:PivotTo(base * CFrame.new(0, 5 * scale, 0))          -- torso sits 5 studs up
    model:SetAttribute("Base", base)                             -- ground-level pose, used by the animator
    model:SetAttribute("Scale", scale)
    model:SetAttribute("Phase", math.random() * math.pi * 2)

    local desc = GolemNames.Describe(golem)
    local head = model:FindFirstChild("Head")
    if head then
        local tag = Instance.new("BillboardGui")
        tag.Size = UDim2.new(0, 220, 0, 46)
        tag.StudsOffset = Vector3.new(0, 4.5, 0)
        tag.MaxDistance = 120
        tag.Adornee = head
        tag.Parent = head

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, 0, 0.55, 0)
        name.BackgroundTransparency = 1
        name.Text = string.format("%s's %s", ownerName, desc.shortName)
        name.TextColor3 = desc.rarityColor
        name.Font = Enum.Font.GothamBold
        name.TextScaled = true
        name.TextStrokeTransparency = 0.4
        name.Parent = tag

        local rarity = Instance.new("TextLabel")
        rarity.Position = UDim2.new(0, 0, 0.55, 0)
        rarity.Size = UDim2.new(1, 0, 0.45, 0)
        rarity.BackgroundTransparency = 1
        rarity.Text = desc.rarity .. (desc.variantLabel and ("  -  " .. desc.variantLabel) or "")
        rarity.TextColor3 = Color3.fromRGB(235, 235, 235)
        rarity.Font = Enum.Font.Gotham
        rarity.TextScaled = true
        rarity.TextStrokeTransparency = 0.5
        rarity.Parent = tag
    end

    model.Parent = folder
    return { model = model, zoneId = golem.zoneId, slot = slot, style = StyleKey(golem, equipped) }
end

local function Remove(id)
    local e = entries[id]
    if not e then return end
    if usedSlots[e.zoneId] then usedSlots[e.zoneId][e.slot] = nil end
    if e.model then e.model:Destroy() end
    entries[id] = nil
end

local function Reconcile()
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataService.Get(player)
        for _, g in ipairs(data and data.Golems or {}) do
            if g.deployed and g.zoneId then
                seen[g.id] = true
                local equipped = (data and data.Equipped) or {}
                local e = entries[g.id]
                if e and e.style ~= StyleKey(g, equipped) then Remove(g.id) e = nil end
                if not e then entries[g.id] = Build(g, player.DisplayName, equipped) end
            end
        end
    end
    for id in pairs(entries) do
        if not seen[id] then Remove(id) end
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
end

return GolemVisuals
