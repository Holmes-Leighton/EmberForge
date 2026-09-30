-- Builds the mining pads and pays out materials once per second to any player
-- standing on one they're allowed to use.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local PadData           = require(game.ReplicatedStorage.Shared.Data.PadData)
local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PadService = {}

local pads = {}      -- { def, part }
local tickCount = {} -- userId → seconds spent on pads (for the coal cadence)

local function IsAdmin(player)
    if RunService:IsStudio() then return true end   -- so you can test the Admin pad
    for _, id in ipairs(GameConfig.ADMIN_USER_IDS or {}) do
        if id == player.UserId then return true end
    end
    if game.CreatorType == Enum.CreatorType.User then
        return game.CreatorId == player.UserId
    end
    local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
    return ok and rank >= 250
end

local function CanUse(player, def, data)
    if def.adminOnly then return IsAdmin(player) end
    return (data.PlayerLevel or 1) >= (def.minLevel or 1)
end

local function RequirementText(def)
    if def.adminOnly then return "Admins only" end
    if (def.minLevel or 1) <= 1 then return "Open to everyone" end
    return "Requires Level " .. def.minLevel
end

local function BuildPad(world, def)
    local part = Instance.new("Part")
    part.Name = "Pad_" .. def.id
    part.Anchored = true
    part.Size = PadData.SIZE
    part.CFrame = CFrame.new(def.x, PadData.SIZE.Y / 2, def.z)
    part.Material = Enum.Material.Neon
    part.Color = def.color
    part.Transparency = 0.25
    part.TopSurface = Enum.SurfaceType.Smooth
    part.Parent = world

    local rim = Instance.new("SelectionBox")   -- bright outline so pads read from a distance
    rim.Adornee = part
    rim.Color3 = def.color
    rim.LineThickness = 0.12
    rim.Parent = part

    local light = Instance.new("PointLight")
    light.Color = def.color
    light.Range = 26
    light.Brightness = 1.5
    light.Parent = part

    local anchor = Instance.new("Part")
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.Position = Vector3.new(def.x, 11, def.z)
    anchor.Parent = world

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 260, 0, 80)
    bb.MaxDistance = 220
    bb.Parent = anchor

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.5, 0)
    title.BackgroundTransparency = 1
    title.Text = string.format("%dx  %s", def.multiplier, def.displayName)
    title.TextColor3 = def.color
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.TextStrokeTransparency = 0.3
    title.Parent = bb

    local sub = Instance.new("TextLabel")
    sub.Position = UDim2.new(0, 0, 0.5, 0)
    sub.Size = UDim2.new(1, 0, 0.35, 0)
    sub.BackgroundTransparency = 1
    sub.Text = RequirementText(def) .. "  •  stand here to mine"
    sub.TextColor3 = Color3.fromRGB(235, 235, 235)
    sub.Font = Enum.Font.Gotham
    sub.TextScaled = true
    sub.TextStrokeTransparency = 0.5
    sub.Parent = bb

    return part
end

local function PadUnderPlayer(player)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    for _, entry in ipairs(pads) do
        local rel = entry.part.CFrame:PointToObjectSpace(root.Position)
        local half = entry.part.Size / 2
        if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y > 0 and rel.Y < 9 then
            return entry.def
        end
    end
    return nil
end

local function Payout()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataService.Get(player)
        local def = data and PadUnderPlayer(player)
        if def and CanUse(player, def, data) then
            local n = (tickCount[player.UserId] or 0) + 1
            tickCount[player.UserId] = n

            local gains = { BasicOre = PadData.ORE_PER_SECOND * def.multiplier }
            if n % PadData.COAL_EVERY_N == 0 then
                gains.Coal = def.multiplier
            end
            for matId, qty in pairs(gains) do
                PlayerDataService.AddMaterial(player, matId, qty)
            end
            RemoteEvents.ResourcesCollected:FireClient(player, gains, 0)
        end
    end
end

function PadService.Init()
    local world = workspace:FindFirstChild("EmberWorld")
    if not world then
        warn("[PadService] EmberWorld not found — build the world first")
        return
    end
    for _, def in ipairs(PadData.Pads) do
        table.insert(pads, { def = def, part = BuildPad(world, def) })
    end

    Players.PlayerRemoving:Connect(function(p) tickCount[p.UserId] = nil end)

    task.spawn(function()
        while true do
            task.wait(1)
            Payout()
        end
    end)
end

return PadService
