-- Builds the mining pads and pays out materials once per second to any player
-- standing on one they're allowed to use.

local Players    = game:GetService("Players")

local MarketplaceService = game:GetService("MarketplaceService")

local PadData           = require(game.ReplicatedStorage.Shared.Data.PadData)
local ProductData       = require(game.ReplicatedStorage.Shared.Data.ProductData)
local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PadService = {}

local pads = {}      -- { def, part }
local tickCount = {} -- userId → ticks spent on pads (for the coal cadence)
local lastFullNotice   = {}   -- userId → os.clock() of the last "stock full" message
local lastLockedNotice = {}   -- userId → os.clock() of the last "locked" message
local lastOffer       = {}   -- "userId:padId" → os.clock() of the last Robux purchase offer

local IsAdmin = require(script.Parent.AdminService).IsAdmin

-- A pad is usable at its level, or forever once bought with Robux (admins get the Admin pad)
local function CanUse(player, def, data)
    if def.adminOnly then return IsAdmin(player) end
    if (data.UnlockedPads or {})[def.id] then return true end
    return (data.PlayerLevel or 1) >= (def.minLevel or 1)
end
PadService.CanUse = CanUse

local function RequirementText(def)
    if def.adminOnly then return "Admins only" end
    if (def.minLevel or 1) <= 1 then return "Open to everyone" end
    local _, pass = ProductData.PassForPad(def.id)
    if pass then
        return string.format("Level %d   or   R$%d forever", def.minLevel, pass.robux)
    end
    return "Requires Level " .. def.minLevel
end

-- Each pad tier looks clearly different from the one before, like the tiered pads in Adopt Me /
-- Grow a Garden: a bigger plinth, richer material, a taller beam of light, more sparkle,
-- and a huge "x3" painted on the top so the multiplier reads from across the cavern.
local STYLE = {
    Starter = { plinth = Enum.Material.WoodPlanks,     beam = 26, sparkle = 6,  posts = 4, gem = false },
    Copper  = { plinth = Enum.Material.CorrodedMetal,  beam = 36, sparkle = 10, posts = 4, gem = false },
    Iron    = { plinth = Enum.Material.DiamondPlate,   beam = 46, sparkle = 16, posts = 4, gem = true  },
    Gold    = { plinth = Enum.Material.Metal,          beam = 60, sparkle = 26, posts = 4, gem = true  },
    Legend  = { plinth = Enum.Material.Marble,         beam = 75, sparkle = 34, posts = 4, gem = true  },
    Admin   = { plinth = Enum.Material.Neon,           beam = 100, sparkle = 44, posts = 4, gem = true  },
}

local function Block(parent, name, size, cf, color, material, extra)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(extra or {}) do p[k] = v end
    p.Parent = parent
    return p
end

local PAD_Y = 1.4 + PadData.SIZE.Y / 2      -- sits on the plinth (top at 1.4)

local function BuildPad(world, def)
    local style = STYLE[def.id] or STYLE.Starter
    local model = Instance.new("Model")
    model.Name = "PadModel_" .. def.id
    model.Parent = world
    local x, z = def.x, def.z
    local dark = def.color:Lerp(Color3.new(0, 0, 0), 0.55)

    -- plinth: a wide low step with a bright rim, then the stepping surface itself
    Block(model, "PadBase", Vector3.new(28, 1.4, 28), CFrame.new(x, 0.7, z), dark, style.plinth)
    Block(model, "PadRim", Vector3.new(26, 0.3, 26), CFrame.new(x, 1.45, z), def.color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.1 })
    -- the walkable, detected surface (name must stay Pad_<id>)
    local part = Block(model, "Pad_" .. def.id, PadData.SIZE, CFrame.new(x, PAD_Y, z),
        def.color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic, { Transparency = 0 })
    -- inner glow tile
    Block(model, "PadGlow", Vector3.new(18, 0.1, 18), CFrame.new(x, PAD_Y + PadData.SIZE.Y / 2 + 0.06, z), def.color, Enum.Material.Neon,
        { CanCollide = false, Transparency = 0.35 })

    -- the multiplier, painted big on the top face
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 24
    gui.Parent = part
    local big = Instance.new("TextLabel")
    big.Size = UDim2.new(1, 0, 0.72, 0)
    big.BackgroundTransparency = 1
    big.Text = "x" .. def.multiplier
    big.TextColor3 = Color3.fromRGB(255, 255, 255)
    big.Font = Enum.Font.GothamBlack
    big.TextScaled = true
    big.TextStrokeColor3 = dark
    big.TextStrokeTransparency = 0
    big.Parent = gui
    local small = Instance.new("TextLabel")
    small.Position = UDim2.new(0, 0, 0.72, 0)
    small.Size = UDim2.new(1, 0, 0.2, 0)
    small.BackgroundTransparency = 1
    small.Text = string.upper(def.displayName)
    small.TextColor3 = Color3.fromRGB(255, 255, 255)
    small.Font = Enum.Font.GothamBold
    small.TextScaled = true
    small.TextStrokeTransparency = 0.3
    small.Parent = gui

    -- corner posts with glowing lanterns
    local corners = { { -13, -13 }, { 13, -13 }, { -13, 13 }, { 13, 13 } }
    for i = 1, style.posts do
        local c = corners[i]
        Block(model, "PadPost", Vector3.new(1.6, 9, 1.6), CFrame.new(x + c[1], 5.2, z + c[2]), dark:Lerp(Color3.new(1, 1, 1), 0.15), style.plinth)
        local orb = Block(model, "PadLantern", Vector3.new(2.4, 2.4, 2.4), CFrame.new(x + c[1], 10.6, z + c[2]), def.color, Enum.Material.Neon,
            { Shape = Enum.PartType.Ball, CanCollide = false })
        local l = Instance.new("PointLight")
        l.Color = def.color
        l.Range = 30
        l.Brightness = 1.6
        l.Parent = orb
    end

    -- arch over the back edge carrying the name
    Block(model, "PadArch", Vector3.new(28, 2.4, 1.6), CFrame.new(x, 13.4, z + 13), dark, style.plinth)

    -- beam of light: the tier is visible from the far side of the cavern
    local beam = Block(model, "PadBeam", Vector3.new(style.beam, 5, 5), CFrame.new(x, 2 + style.beam / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
        def.color, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.82, CanCollide = false })
    local sparkle = Instance.new("ParticleEmitter")
    sparkle.Color = ColorSequence.new(def.color)
    sparkle.Rate = style.sparkle
    sparkle.Lifetime = NumberRange.new(2, 3.5)
    sparkle.Speed = NumberRange.new(6, 12)
    sparkle.EmissionDirection = Enum.NormalId.Top
    sparkle.SpreadAngle = Vector2.new(20, 20)
    sparkle.LightEmission = 1
    sparkle.Size = NumberSequence.new(0.7, 0)
    sparkle.Parent = beam

    -- higher tiers: a spinning gem above the pad
    if style.gem then
        local gem = Block(model, "PadGem", Vector3.new(3.2, 4.4, 3.2), CFrame.new(x, 17, z) * CFrame.Angles(0.6, 0.6, 0), def.color,
            Enum.Material.Neon, { CanCollide = false, Transparency = 0.1 })
        gem:SetAttribute("SpinSpeed", 1.4)
        game:GetService("CollectionService"):AddTag(gem, "EFSpin")
    end

    local light = Instance.new("PointLight")
    light.Color = def.color
    light.Range = 40
    light.Brightness = 2
    light.Parent = part

    -- name plate above the arch
    local anchor = Block(model, "PadSignAnchor", Vector3.new(1, 1, 1), CFrame.new(x, 20, z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
        { Transparency = 1, CanCollide = false })
    local bb = Instance.new("BillboardGui")
    -- sized in studs (pads are 60 apart) so neighbouring signs never overlap at range
    bb.Size = UDim2.fromScale(44, 13)
    bb.MaxDistance = 90      -- (400 piled every pad sign onto the Anvil's labels)
    bb.Parent = anchor
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.55, 0)
    title.BackgroundTransparency = 1
    title.Text = string.format("%s   x%d", def.displayName, def.multiplier)
    title.TextColor3 = def.color
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.TextStrokeTransparency = 0
    title.Parent = bb
    local sub = Instance.new("TextLabel")
    sub.Position = UDim2.new(0, 0, 0.55, 0)
    sub.Size = UDim2.new(1, 0, 0.4, 0)
    sub.BackgroundTransparency = 1
    sub.Text = RequirementText(def)
    sub.TextColor3 = Color3.fromRGB(245, 245, 245)
    sub.Font = Enum.Font.GothamBold
    sub.TextScaled = true
    sub.TextStrokeTransparency = 0.3
    sub.Parent = bb

    -- "Press E" info point just in front of the pad (outside the plinth, so it only shows when you walk up
    -- to it, not while you stand on the pad mining)
    local info = Block(model, "PadInfoPoint", Vector3.new(2, 1, 2), CFrame.new(x, 2.5, z + 19), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
        { Transparency = 1, CanCollide = false })
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PadInfoPrompt"
    prompt.ActionText = "Pad info"
    prompt.ObjectText = string.format("%s  x%d", def.displayName, def.multiplier)
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt:SetAttribute("PadId", def.id)
    prompt.Parent = info

    return part
end

-- Offers the Robux game pass for a locked pad. Stepping on it is rate-limited (30s per pad); pressing E
-- at the pad asks for it, so `force` skips the limit. Ownership is re-checked first, so a pass bought
-- on the game page unlocks the pad at once.
function PadService.OfferPass(player, def, force)
    local key, pass = ProductData.PassForPad(def.id)
    if not (key and ProductData.PassIsAvailable(key)) then return end
    local offerKey = player.UserId .. ":" .. def.id
    if not force and os.clock() - (lastOffer[offerKey] or -1e9) <= 30 then return end
    lastOffer[offerKey] = os.clock()
    task.spawn(function()
        if not require(script.Parent.ShopService).RefreshPasses(player, key) then
            pcall(function() MarketplaceService:PromptGamePassPurchase(player, pass.id) end)
        end
    end)
end

-- Pressing E at a pad: what it gives, or what it needs
local function PadInfo(player, def)
    local data = PlayerDataService.Get(player)
    if not data then return end
    if CanUse(player, def, data) then
        RemoteEvents.Notify:FireClient(player, string.format("%s  x%d", def.displayName, def.multiplier),
            string.format("Unlocked. Stand on the pad to mine %dx materials.", def.multiplier))
    else
        RemoteEvents.Notify:FireClient(player, def.displayName .. " locked", RequirementText(def))
        PadService.OfferPass(player, def, true)
    end
end

PadService.Info = PadInfo

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
            -- Stepping onto a locked pad offers the Robux game pass (at most every 30s per pad).
            -- Ownership is re-checked first, so a pass bought on the game page unlocks it at once.
            PadService.OfferPass(player, def, false)
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
        local part = BuildPad(world, def)
        table.insert(pads, { def = def, part = part })
        local prompt = part.Parent:FindFirstChild("PadInfoPrompt", true)
        if prompt then
            prompt.Triggered:Connect(function(player) PadInfo(player, def) end)
        end
    end

    Players.PlayerRemoving:Connect(function(p)
        tickCount[p.UserId] = nil
        lastLockedNotice[p.UserId] = nil
        lastFullNotice[p.UserId] = nil
        for k in pairs(lastOffer) do
            if k:sub(1, #tostring(p.UserId) + 1) == p.UserId .. ":" then lastOffer[k] = nil end
        end
    end)

    local function WelcomeAdmin(player)
        if IsAdmin(player) then
            print("[PadService] " .. player.Name .. " is an admin (Admin Pad unlocked)")
            task.delay(6, function()
                if player.Parent then
                    RemoteEvents.Notify:FireClient(player, "Admin mode", "You can use the 250x Admin Pad.")
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
