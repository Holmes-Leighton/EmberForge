-- Builds the mining pads and pays out materials once per second to any player
-- standing on one they're allowed to use.

local Players    = game:GetService("Players")

local MarketplaceService = game:GetService("MarketplaceService")

local PadData           = require(game.ReplicatedStorage.Shared.Data.PadData)
local SpeedData         = require(game.ReplicatedStorage.Shared.Data.SpeedData)
local ProductData       = require(game.ReplicatedStorage.Shared.Data.ProductData)
local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SignArt           = require(script.Parent.SignArt)

local PadService = {}

local pads = {}      -- { def, part }
local tickCount = {} -- userId → ticks spent on pads (for the coal cadence)
local lastFullNotice   = {}   -- userId → os.clock() of the last "stock full" message
local lastLockedNotice = {}   -- userId → os.clock() of the last "locked" message
local lastOffer       = {}   -- "userId:padId" → os.clock() of the last Robux purchase offer
local lastDialog      = {}   -- "userId:padId" → os.clock() of the last unlock dialog shown
local near            = {}   -- "userId:padId" → true while the player is standing close to that pad (the dialog opens when they walk up, not every tick)
local APPROACH        = 16   -- studs beyond a pad's edge at which walking up to a locked pad opens the unlock dialog
local DIALOG_COOLDOWN = 60   -- seconds before the same dialog can open again for the same pad

local IsAdmin = require(script.Parent.AdminService).IsAdmin

-- A pad is usable at its level, or forever once bought with Robux (admins get every pad for free)
local function CanUse(player, def, data)
    if IsAdmin(player) then return true end
    if def.adminOnly then return false end
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
    -- the hard neon bar becomes a soft shaft of light: a camera-facing ribbon that is bright at the pad and fades away as it rises (the cylinder stays,
    -- invisible, as the thing the sparkles come from). The tier is still readable from across the cavern by how tall the shaft is.
    beam.Transparency = 1
    local lower, upper = Instance.new("Attachment"), Instance.new("Attachment")
    lower.Position, upper.Position = Vector3.new(-style.beam / 2, 0, 0), Vector3.new(style.beam / 2, 0, 0)       -- (the cylinder's X axis points up)
    lower.Parent, upper.Parent = beam, beam
    local shaft = Instance.new("Beam")
    shaft.Attachment0, shaft.Attachment1 = lower, upper
    shaft.Color = ColorSequence.new(def.color:Lerp(Color3.new(1, 1, 1), 0.35))
    shaft.LightEmission, shaft.LightInfluence = 1, 0
    shaft.Width0, shaft.Width1 = 9, 1.5
    shaft.Segments = 1
    shaft.FaceCamera = true
    shaft.Transparency = NumberSequence.new(0.3, 1)
    shaft.Parent = beam
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

    -- an info board behind the pad (a carved frame mesh around a dark panel): its name, its speed, what it mines, how much it stores and how to unlock it
    local boardCF = CFrame.lookAt(Vector3.new(x, 11, z - 17), Vector3.new(x, 11, z))               -- faces the player's side (+Z)
    local panel = Block(model, "PadBoard", Vector3.new(24, 12, 0.4), boardCF, Color3.fromRGB(30, 22, 18), Enum.Material.SmoothPlastic, { CanCollide = false })
    for _, side in ipairs({ -1, 1 }) do
        SignArt.Post(Block(model, "PadBoardPost", Vector3.new(2, 11, 2), CFrame.new(x + side * 14.5, 5.5, z - 17.4), dark:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Wood))
    end
    local bg = Instance.new("SurfaceGui")
    bg.Name, bg.Face, bg.SizingMode, bg.PixelsPerStud = "BoardLettering", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
    bg.Parent = panel
    local function line(text, y, h, color, font)
        local l = Instance.new("TextLabel")
        l.Position, l.Size, l.BackgroundTransparency = UDim2.new(0, 20, 0, y), UDim2.new(1, -40, 0, h), 1
        l.Text, l.TextColor3, l.Font, l.TextScaled = text, color, font or Enum.Font.GothamBold, true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = bg
    end
    local orePerSec = def.multiplier * PadData.ORE_PER_TICK / PadData.TICK_SECONDS
    local coalPerSec = def.multiplier / PadData.COAL_EVERY_N / PadData.TICK_SECONDS
    line(string.upper(def.displayName), 8, 86, def.color, Enum.Font.GothamBlack)
    line(string.format("SPEED  x%d", def.multiplier), 96, 118, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
    line(string.format("Mines %s Ore + %s Coal every second", tostring(orePerSec), tostring(coalPerSec)), 222, 56, Color3.fromRGB(235, 225, 205))
    line(string.format("Stores up to %d Ore / %d Coal", PadData.StockCap(def, "BasicOre"), PadData.StockCap(def, "Coal")), 282, 56, Color3.fromRGB(235, 225, 205))
    line(string.format("Trains Speed up to level %d", def.speedCap or SpeedData.MAX_LEVEL), 410, 56, Color3.fromRGB(150, 220, 255))
    line(RequirementText(def), 346, 62, def.adminOnly and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 220, 120))
    SignArt.Frame("Plank", panel)

    -- the pad's custom mesh (when its set has loaded) replaces the plinth, rim and glow; the walkable surface and everything above stay
    require(script.Parent.BiomeArt).Pad(model, def.id, part, x, z, 1.4 + PadData.SIZE.Y)

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

-- The unlock dialog: what the pad gives, how to reach it by level, and the Robux button. Opened when a player walks up to a locked pad (or presses E at it).
-- Only pads with a game pass get one (the Starter pad is free, the Admin pad is for admins).
local function ShowOffer(player, def, data, force)
    local key, pass = ProductData.PassForPad(def.id)
    if not pass then return end
    local offerKey = player.UserId .. ":" .. def.id
    if not force and os.clock() - (lastDialog[offerKey] or -1e9) < DIALOG_COOLDOWN then return end
    lastDialog[offerKey] = os.clock()
    RemoteEvents.PadOffer:FireClient(player, {
        padId = def.id, name = def.displayName, multiplier = def.multiplier, minLevel = def.minLevel or 1,
        level = data.PlayerLevel or 1, robux = pass.robux, available = ProductData.PassIsAvailable(key),
    })
end

-- "Unlock forever" pressed: validate, then open Roblox's own purchase prompt
local lastBuy = {}
function PadService.Buy(player, padId)
    if type(padId) ~= "string" then return end
    if os.clock() - (lastBuy[player.UserId] or -1e9) < 2 then return end
    lastBuy[player.UserId] = os.clock()
    local data = PlayerDataService.Get(player)
    if not data then return end
    for _, entry in ipairs(pads) do
        if entry.def.id == padId then
            if CanUse(player, entry.def, data) then return end
            PadService.OfferPass(player, entry.def, true)
            return
        end
    end
end

-- Walking up to a locked pad (not just stepping on it) opens its unlock dialog once
local function WatchApproach()
    for _, player in ipairs(Players:GetPlayers()) do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local data = PlayerDataService.Get(player)
        if root and data then
            for _, entry in ipairs(pads) do
                local rel = entry.part.CFrame:PointToObjectSpace(root.Position)
                local half = entry.part.Size / 2
                local inside = math.abs(rel.X) <= half.X + APPROACH and math.abs(rel.Z) <= half.Z + APPROACH
                local key = player.UserId .. ":" .. entry.def.id
                if inside and not near[key] then
                    near[key] = true
                    if not CanUse(player, entry.def, data) then ShowOffer(player, entry.def, data, false) end
                elseif near[key] and (math.abs(rel.X) > half.X + APPROACH + 12 or math.abs(rel.Z) > half.Z + APPROACH + 12) then
                    near[key] = nil                                              -- walked away: it can open again next time they walk up
                end
            end
        end
    end
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
        ShowOffer(player, def, data, true)
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

-- ── Movement speed ───────────────────────────────────────────────────────────
-- Standing on a pad also trains movement speed (SpeedData): a higher pad trains faster, even when its material stock is full. The player's SpeedLevel attribute
-- feeds the HUD's speed row and the Zombie Golem (MazeService). The bonus applies in the hub and the Hollow Maze; the Sky Tower is built for the normal pace.
local appliedWalk = {}   -- userId → the WalkSpeed this service last set (so another system's temporary change, like a Courier crate, is left alone)

local function SetSpeedAttributes(player, data)
    local level = data.SpeedLevel or 0
    local need = SpeedData.XpToNext(level)
    player:SetAttribute("SpeedLevel", level)
    player:SetAttribute("SpeedNeed", need or 0)
    player:SetAttribute("SpeedXp", need and math.floor(data.SpeedXp or 0) or 0)
end

local lastCapNotice = {}   -- userId → os.clock() of the last "this pad has taught you all it can" message

local function TrainSpeed(player, data, def)
    local level = data.SpeedLevel or 0
    if level >= SpeedData.MAX_LEVEL then return end
    local cap = math.min(def.speedCap or SpeedData.MAX_LEVEL, SpeedData.MAX_LEVEL)
    if level >= cap then                                              -- this pad has taught all it can: the next pad up trains further
        if os.clock() - (lastCapNotice[player.UserId] or -1e9) > 30 then
            lastCapNotice[player.UserId] = os.clock()
            RemoteEvents.Notify:FireClient(player, "Speed level " .. level, string.format("The %s trains speed up to level %d. Try a higher pad to keep getting faster.", def.displayName, cap))
        end
        return
    end
    local xp = (data.SpeedXp or 0) + SpeedData.XpPerTick(def.multiplier)
    local need = SpeedData.XpToNext(level)
    while need and xp >= need and level < cap do
        xp -= need
        level += 1
        need = SpeedData.XpToNext(level)
        data.SpeedLevel = level
        if level % SpeedData.NOTICE_EVERY == 0 or level >= cap then
            RemoteEvents.Notify:FireClient(player, "Speed level " .. level, string.format("You now walk at %.1f (normal is %d).", SpeedData.WalkSpeed(level), SpeedData.BASE_WALK))
        end
    end
    data.SpeedXp = (need and level < cap) and xp or 0                 -- (at the cap the bar waits, empty)
    PlayerDataService.MarkDirty(player)
    SetSpeedAttributes(player, data)
end

local function ApplyWalkSpeed(player, data)
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local desired = SpeedData.BASE_WALK
    if player:GetAttribute("TowerLevel") == nil then desired = SpeedData.WalkSpeed(data.SpeedLevel or 0) end
    local last = appliedWalk[player.UserId]
    if math.abs(hum.WalkSpeed - SpeedData.BASE_WALK) < 0.01 or (last and math.abs(hum.WalkSpeed - last) < 0.01) then
        hum.WalkSpeed = desired
        appliedWalk[player.UserId] = desired
    end
end

local function Payout()
    for _, player in ipairs(Players:GetPlayers()) do
        local pd = PlayerDataService.Get(player)
        if pd then
            if player:GetAttribute("SpeedLevel") ~= (pd.SpeedLevel or 0) or player:GetAttribute("SpeedNeed") == nil then SetSpeedAttributes(player, pd) end
            ApplyWalkSpeed(player, pd)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataService.Get(player)
        local def = data and PadUnderPlayer(player)
        if def and not CanUse(player, def, data) then
            local last = lastLockedNotice[player.UserId] or 0
            if os.clock() - last > 4 then
                lastLockedNotice[player.UserId] = os.clock()
                RemoteEvents.Notify:FireClient(player, def.displayName .. " locked", RequirementText(def))
            end
            -- (the unlock dialog opened when they walked up; see WatchApproach.) Standing on a paid pad you don't own also opens Roblox's own purchase prompt
            -- (rate-limited to once per 30 s per pad)
            ShowOffer(player, def, data, false)
            PadService.OfferPass(player, def, false)
        elseif def then
            TrainSpeed(player, data, def)
            local n = (tickCount[player.UserId] or 0) + 1
            tickCount[player.UserId] = n

            local wanted = { BasicOre = PadData.ORE_PER_TICK * def.multiplier }
            if n % PadData.COAL_EVERY_N == 0 then
                wanted.Coal = def.multiplier
            end

            -- never push a stock above its cap
            local gains, anyRoom = {}, false
            for matId, qty in pairs(wanted) do
                local cap  = PadData.StockCap(def, matId)
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
                        def.displayName .. " tops up to " .. PadData.StockCap(def, "BasicOre") .. " Basic Ore / "
                        .. PadData.StockCap(def, "Coal") .. " Coal. Spend some to keep mining.")
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
        appliedWalk[p.UserId] = nil
        lastCapNotice[p.UserId] = nil
        lastLockedNotice[p.UserId] = nil
        lastFullNotice[p.UserId] = nil
        lastBuy[p.UserId] = nil
        for _, tbl in ipairs({ lastDialog, near }) do
            for k in pairs(tbl) do if k:sub(1, #tostring(p.UserId) + 1) == p.UserId .. ":" then tbl[k] = nil end end
        end
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
    task.spawn(function()
        while true do
            task.wait(0.5)
            WatchApproach()
        end
    end)
end

return PadService
