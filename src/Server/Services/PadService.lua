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
local tickCount = {} -- userId → ticks spent on pads (for the coal cadence)
local lastFullNotice   = {}   -- userId → os.clock() of the last "stock full" message
local lastLockedNotice = {}   -- userId → os.clock() of the last "locked" message

local IsAdmin = require(script.Parent.AdminService).IsAdmin

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
        if def and not CanUse(player, def, data) then
            local last = lastLockedNotice[player.UserId] or 0
            if os.clock() - last > 4 then
                lastLockedNotice[player.UserId] = os.clock()
                RemoteEvents.Notify:FireClient(player, def.displayName .. " locked", RequirementText(def))
            end
        elseif def then
            local n = (tickCount[player.UserId] or 0) + 1
            tickCount[player.UserId] = n

            local wanted = { BasicOre = PadData.ORE_PER_TICK * def.multiplier }
            if n % PadData.COAL_EVERY_N == 0 then
                wanted.Coal = def.multiplier
            end

            -- never push a stock above its cap
            local gains, anyRoom = {}, false
            for matId, qty in pairs(wanted) do
                local cap  = PadData.STOCK_CAP[matId] or math.huge
                local room = cap - (data.Inventory[matId] or 0)
                local give = math.min(qty, math.max(0, room))
                if room > 0 then anyRoom = true end
                if give > 0 then
                    gains[matId] = give
                    PlayerDataService.AddMaterial(player, matId, give)
                end
            end
            if next(gains) then
                require(script.Parent.AnalyticsHelper).Funnel(player, data, "pad", 1, "FirstPadMined")
                RemoteEvents.ResourcesCollected:FireClient(player, gains, 0)
            elseif not anyRoom then
                local last = lastFullNotice[player.UserId] or 0
                if os.clock() - last > 15 then
                    lastFullNotice[player.UserId] = os.clock()
                    RemoteEvents.Notify:FireClient(player, "Pad stock full",
                        "Pads top up to " .. PadData.STOCK_CAP.BasicOre .. " Basic Ore / "
                        .. PadData.STOCK_CAP.Coal .. " Coal. Spend some to keep mining.")
                end
            end
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

    Players.PlayerRemoving:Connect(function(p)
        tickCount[p.UserId] = nil
        lastLockedNotice[p.UserId] = nil
        lastFullNotice[p.UserId] = nil
    end)

    local function WelcomeAdmin(player)
        if IsAdmin(player) then
            print("[PadService] " .. player.Name .. " is an admin (Admin Pad unlocked)")
            task.delay(6, function()
                if player.Parent then
                    RemoteEvents.Notify:FireClient(player, "Admin mode", "You can use the 100x Admin Pad.")
                end
            end)
        end
    end
    Players.PlayerAdded:Connect(WelcomeAdmin)
    for _, p in ipairs(Players:GetPlayers()) do WelcomeAdmin(p) end

    task.spawn(function()
        while true do
            task.wait(PadData.TICK_SECONDS)
            Payout()
        end
    end)
end

return PadService
