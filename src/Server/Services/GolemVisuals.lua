-- Puts every player's deployed Golems into the world, standing in the mining zone they were sent to.
-- The server only creates and removes the models; the arm/pickaxe swing and Neon colour effects
-- are animated by each client (GolemAnimator), so 20 players x 12 Golems cost the server nothing per frame.

local Players = game:GetService("Players")

local GolemModel        = require(game.ReplicatedStorage.Shared.Modules.GolemModel)
local GolemData         = require(game.ReplicatedStorage.Shared.Data.GolemData)
local GolemNames        = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldBuilder      = require(script.Parent.WorldBuilder)
local GolemMotion       = require(game.ReplicatedStorage.Shared.Modules.GolemMotion)
local GolemService      = require(script.Parent.GolemService)
local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local MaterialData      = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local GolemRoute        = require(game.ReplicatedStorage.Shared.Modules.GolemRoute)
local ForgeZoneService  = require(script.Parent.ForgeZoneService)

local GolemVisuals = {}

local RING_RADIUS = 30
local SLOTS       = 10          -- Golems per zone ring before a second ring starts
local GROUND_Y    = 2           -- top of the zone pads
local HUB_Y       = 0.2         -- the hub floor, where a Golem walking home stands
local HUB_ROAD_Z  = 60          -- the road along the cavern that every tunnel joins
local TRAVEL_SPEED = 12         -- studs per second of a worn-out Golem trudging between its zone and its owner's forge
local REST_SPACING = 11         -- studs between Golems waiting at the forge

local entries   = {}            -- golemId -> { model, zoneId, slot, variant, state, ... } (state: "mining" | "toForge" | "resting" | "toZone")
local usedSlots = {}            -- zoneId -> { [slot] = true }
local restSlots = {}            -- owner userId -> { [k] = true }: the places beside their forge where worn-out Golems wait
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
    return table.concat({ golem.variant or "", GolemData.StageOf(golem).id, golem.zoneId or "", equipped.GolemAccessory or "", equipped.ParticleEffect or "", equipped.GolemSkin or "", GolemModel.AssetVersion() }, "|")
end

-- "20 Basic Ore, 10 Coal" for the repair prompt
local function CostText(golem)
    local bits = {}
    for _, req in ipairs(GolemService.RepairCost(golem) or {}) do
        local def = MaterialData.Get(req.id)
        table.insert(bits, string.format("%d %s", req.qty, def and def.displayName or req.id))
    end
    return table.concat(bits, ", ")
end

local function Build(golem, ownerName, equipped, owner)
    local center = WorldBuilder.GetZoneCenter(golem.zoneId)
    if not center then return nil end

    local slot   = FreeSlot(golem.zoneId)
    local angle  = (slot % SLOTS) / SLOTS * math.pi * 2
    local radius = RING_RADIUS + math.floor(slot / SLOTS) * 8
    local pos    = center + Vector3.new(math.cos(angle) * radius, GROUND_Y, math.sin(angle) * radius)
    local base   = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
    local stage  = GolemData.StageOf(golem)
    local scale  = (1 + ((golem.tier or 1) - 1) * 0.18) * stage.scale       -- an Infant stands small, an Ancient tall

    local model = GolemModel.Build(golem.element, golem.tier, {
        stage = stage.id, variant = golem.variant, accessory = equipped.GolemAccessory, particle = equipped.ParticleEffect, skin = equipped.GolemSkin,
    })
    model.Name = "Golem_" .. golem.id
    model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic   -- streams in whole, so the client always finds every limb when it starts animating
    model:PivotTo(base * CFrame.new(0, 5 * scale, 0))          -- torso sits 5 studs up
    model:SetAttribute("Base", base)                             -- ground-level pose, used by the animator
    model:SetAttribute("Scale", scale)
    model:SetAttribute("Phase", math.random() * math.pi * 2)
    model:SetAttribute("Element", golem.element)                -- the animator gives each element its own pace and dust
    model:SetAttribute("OwnerUserId", owner and owner.UserId or 0)     -- the client shows a durability bar on its owner's Golems
    model:SetAttribute("Durability", GolemMotion.DurabilityOf(golem))  -- 1 fresh .. 0 broken: slows, slumps and dims the Golem, and fills the bar
    model:SetAttribute("GolemId", golem.id)

    local desc = GolemNames.Describe(golem)
    local head = model:FindFirstChild("Head", true)
    if not head then
        -- uploaded model without a Head part: an invisible marker where the head would be, so the name tag has something to sit on
        head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(0.2, 0.2, 0.2)
        head.Transparency = 1
        head.Anchored = true
        head.CanCollide = false
        head.CanQuery = false
        head.CFrame = base * CFrame.new(0, 8.3 * scale, 0)
        head.Parent = model
    end
    if head then
        -- three lines: whose Golem it is (always first and easy to read), what it is, and its rarity
        local tag = Instance.new("BillboardGui")
        tag.Name = "OwnerTag"
        tag.Size = UDim2.new(0, 250, 0, 70)
        tag.StudsOffset = Vector3.new(0, 4.8, 0)
        tag.MaxDistance = 170
        tag.Adornee = head
        tag.Parent = head

        local owner = Instance.new("TextLabel")
        owner.Name = "Owner"
        owner.Size = UDim2.new(1, 0, 0.38, 0)
        owner.BackgroundTransparency = 1
        owner.Text = tostring(ownerName) .. "'s"
        owner.TextColor3 = Color3.fromRGB(255, 255, 255)
        owner.Font = Enum.Font.GothamBlack
        owner.TextScaled = true
        owner.TextStrokeTransparency = 0.2
        owner.Parent = tag

        local name = Instance.new("TextLabel")
        name.Name = "NameLabel"
        name.Position = UDim2.new(0, 0, 0.38, 0)
        name.Size = UDim2.new(1, 0, 0.34, 0)
        name.BackgroundTransparency = 1
        name.Text = desc.shortName
        name.TextColor3 = desc.rarityColor
        name.Font = Enum.Font.GothamBold
        name.TextScaled = true
        name.TextStrokeTransparency = 0.4
        name.Parent = tag

        local rarity = Instance.new("TextLabel")
        rarity.Position = UDim2.new(0, 0, 0.72, 0)
        rarity.Size = UDim2.new(1, 0, 0.28, 0)
        rarity.BackgroundTransparency = 1
        rarity.Text = desc.rarity .. (desc.variantLabel and ("  -  " .. desc.variantLabel) or "") .. "  -  " .. desc.stage.id
        rarity.TextColor3 = desc.stage.color                       -- stage colour: pale green Infant, teal Young, white Adult, bronze Elder, gold Ancient
        rarity.Font = Enum.Font.Gotham
        rarity.TextScaled = true
        rarity.TextStrokeTransparency = 0.5
        rarity.Parent = tag
    end

    -- Repair in place: stand next to a tired Golem and press E (only its owner can; it costs 20% of its craft materials). Shown once it is low.
    local anchor = head or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    local prompt
    if anchor then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = "RepairPrompt"
        prompt.ActionText = "Repair"
        prompt.ObjectText = "Needs " .. CostText(golem)
        prompt.HoldDuration = 0.4
        prompt.MaxActivationDistance = 14
        prompt.RequiresLineOfSight = false
        prompt.Enabled = GolemMotion.DurabilityOf(golem) <= GolemMotion.LOW
        prompt.Parent = anchor
        local golemId = golem.id
        prompt.Triggered:Connect(function(who)
            if who ~= owner then
                RemoteEvents.Notify:FireClient(who, "Not yours", "Only " .. tostring(ownerName) .. " can repair this Golem.")
                return
            end
            local ok, err = GolemService.RepairGolem(who, golemId)
            if ok then
                RemoteEvents.Notify:FireClient(who, "Repaired!", "Your Golem is back to work.")
            else
                RemoteEvents.Notify:FireClient(who, "Can't repair yet", tostring(err))
            end
        end)
    end

    model.Parent = folder
    return { model = model, zoneId = golem.zoneId, slot = slot, style = StyleKey(golem, equipped), prompt = prompt, warned = 0,
        state = "mining", home = base, scale = scale, owner = owner, d = 0 }
end

-- ── The trip home ─────────────────────────────────────────────────────────────
-- A Golem that wears out stops mining, trudges out of its cave, along the hub road and down the gap beside its owner's forge, and sits there to wait for
-- a repair (stand by it and press E). Once repaired it walks back to its zone and carries on. The server moves it (a few Golems, ten times a second, only
-- while one is on the move) so it stays streamed in, and the repair prompt travels with it; the client animates the legs and the sit.
local function FreeRestSlot(userId)
    restSlots[userId] = restSlots[userId] or {}
    for k = 0, 40 do
        if not restSlots[userId][k] then restSlots[userId][k] = true return k end
    end
    return 0
end

local function ReleaseRest(e)
    if e.restOwnerId and e.restK and restSlots[e.restOwnerId] then restSlots[e.restOwnerId][e.restK] = nil end
    e.restOwnerId, e.restK = nil, nil
end

-- The route from the Golem's spot in its zone to its resting place beside its owner's forge (nil if the owner has no forge plot)
local function PlanRoute(e, owner)
    local plot = owner and ForgeZoneService.GetPlotCFrame(owner.UserId)
    local center = WorldBuilder.GetZoneCenter(e.zoneId)
    if not plot or not center then return nil end
    local k = FreeRestSlot(owner.UserId)
    e.restOwnerId, e.restK = owner.UserId, k
    local gapX = plot.Position.X + 40                                     -- the lane between this forge plot and the next
    local col = ({ 0, -6, 6 })[math.floor(k / 6) % 3 + 1]
    local restZ = 24 - REST_SPACING * (k % 6)
    local home = e.home.Position
    e.restCF = CFrame.lookAt(Vector3.new(gapX + col, HUB_Y, restZ), Vector3.new(gapX + col - 1, HUB_Y, restZ))      -- sits facing the forge
    return GolemRoute.New({
        { x = home.X, y = home.Y, z = home.Z },
        { x = center.X, y = home.Y, z = center.Z - 45 },                  -- out of the ring, to the middle of the cave mouth
        { x = center.X, y = HUB_Y, z = HUB_ROAD_Z },                      -- down the tunnel road to the hub road
        { x = gapX + col, y = HUB_Y, z = HUB_ROAD_Z },                    -- along the road to the forge
        { x = gapX + col, y = HUB_Y, z = restZ },                         -- down the gap to a free spot
    })
end

local function PlaceOnRoute(e)
    local x, y, z, dx, dz = GolemRoute.At(e.route, e.d)
    local dir = (e.dir or 1) >= 0 and Vector3.new(dx, 0, dz) or Vector3.new(-dx, 0, -dz)
    if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
    local pos = Vector3.new(x, y, z)
    local cf = CFrame.lookAt(pos, pos + dir)
    e.model:SetAttribute("Base", cf)
    e.model:PivotTo(cf * CFrame.new(0, 5 * e.scale, 0))
end

local function GoHome(e, justBuilt)
    if e.state == "toForge" or e.state == "resting" then return end
    if not e.route then e.route = PlanRoute(e, e.owner) end
    if not e.route then return end                                        -- no forge to go to: it just sits where it stopped
    e.dir = 1
    if justBuilt then
        e.d = e.route.total
        e.state = "resting"
        e.model:SetAttribute("Travelling", false)
        e.model:SetAttribute("Base", e.restCF)
        e.model:PivotTo(e.restCF * CFrame.new(0, 5 * e.scale, 0))
    else
        e.state = "toForge"
        e.model:SetAttribute("Travelling", true)
        PlaceOnRoute(e)
    end
end

local function GoBack(e)
    if e.state ~= "toForge" and e.state ~= "resting" then return end
    e.state = "toZone"
    e.dir = -1
    e.model:SetAttribute("Travelling", true)
end

local function StepTrips(dt)
    for _, e in pairs(entries) do
        if e.route and e.model and e.model.Parent and (e.state == "toForge" or e.state == "toZone") then
            e.d = math.clamp(e.d + (e.dir or 1) * TRAVEL_SPEED * dt, 0, e.route.total)
            PlaceOnRoute(e)
            if e.state == "toForge" and e.d >= e.route.total then
                e.state = "resting"
                e.model:SetAttribute("Travelling", false)
                e.model:SetAttribute("Base", e.restCF)                    -- settle into its seat, facing the forge
                e.model:PivotTo(e.restCF * CFrame.new(0, 5 * e.scale, 0))
            elseif e.state == "toZone" and e.d <= 0 then
                e.state = "mining"
                e.route = nil
                ReleaseRest(e)
                e.model:SetAttribute("Travelling", false)
                e.model:SetAttribute("Base", e.home)
                e.model:PivotTo(e.home * CFrame.new(0, 5 * e.scale, 0))
            end
        end
    end
end

local function Remove(id)
    local e = entries[id]
    if not e then return end
    ReleaseRest(e)
    if usedSlots[e.zoneId] then usedSlots[e.zoneId][e.slot] = nil end
    if e.model then e.model:Destroy() end
    entries[id] = nil
end

local function Reconcile()
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataService.Get(player)
        local repaired = GolemService.AutoRepair(player)            -- tired Golems are repaired where they stand (unless the player turned that off)
        if #repaired > 0 then
            local GolemNames = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
            local names = {}
            for _, r in ipairs(repaired) do table.insert(names, GolemNames.Describe(r.golem).shortName) end
            RemoteEvents.Notify:FireClient(player, "Auto-repaired", #names == 1 and string.format("Your %s was repaired for %s.", names[1], CostText(repaired[1].golem))
                or string.format("%d Golems were repaired (%s).", #names, table.concat(names, ", ")))
        end
        for _, g in ipairs(data and data.Golems or {}) do
            if g.deployed and g.zoneId then
                seen[g.id] = true
                local equipped = (data and data.Equipped) or {}
                local e = entries[g.id]
                if e and e.style ~= StyleKey(g, equipped) then Remove(g.id) e = nil end
                local justBuilt = false
                if not e then
                    e = Build(g, player.DisplayName, equipped, player)
                    entries[g.id] = e
                    justBuilt = true
                end
                if e and e.model then                      -- keep the wear showing, and tell the owner when a Golem is getting tired or has stopped
                    local f = GolemMotion.DurabilityOf(g)
                    e.model:SetAttribute("Durability", f)
                    if e.prompt then
                        e.prompt.Enabled = f <= GolemMotion.LOW
                        e.prompt.ObjectText = "Needs " .. CostText(g)
                    end
                    local level = f <= 0 and 2 or (f <= GolemMotion.LOW and 1 or 0)
                    if level > (e.warned or 0) then
                        local GolemNames = require(game.ReplicatedStorage.Shared.Modules.GolemNames)
                        local name = GolemNames.Describe(g).shortName
                        if level == 2 then
                            RemoteEvents.Notify:FireClient(player, "Golem stopped", string.format("Your %s has worn out and is walking back to your forge. Repair it there: stand by it and press E.", name))
                        else
                            RemoteEvents.Notify:FireClient(player, "Golem getting tired", string.format("Your %s is wearing down and auto-repair could not pay for it. Repair it soon (stand by it and press E), or keep the repair materials in your Bag.", name))
                        end
                    end
                    e.warned = level
                    if f <= 0 then GoHome(e, justBuilt) elseif e.state ~= "mining" then GoBack(e) end
                end
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
    task.spawn(function()
        while true do
            task.wait(0.1)
            StepTrips(0.1)
        end
    end)
end

return GolemVisuals
