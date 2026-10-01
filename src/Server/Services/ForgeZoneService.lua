-- World-based forge plot system (Adopt Me / Grow a Garden style).
-- Each player gets a rectangular zone Part in the workspace when they join.
-- Walking into another player's zone fires ForgeZoneEntered/Left events.
--
-- Plot layout: a row of 30×30 stud zones spaced 60 studs apart on the X axis,
-- all centred on Z = 0, Y = 0 (adjust Y to match your world floor).
-- Zones are created at runtime so no manual Studio work is needed.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local RemoteEvents      = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ChallengeService  = require(script.Parent.ChallengeService)
local ForgeBuilder      = require(script.Parent.ForgeBuilder)
local ForgeData         = require(game.ReplicatedStorage.Shared.Data.ForgeData)
local AscensionData     = require(game.ReplicatedStorage.Shared.Data.AscensionData)

local ForgeZoneService = {}

-- Config ──────────────────────────────────────────────────────────────────────
local ZONE_SIZE      = Vector3.new(60, 20, 60)   -- width × height × depth of each plot
local ZONE_SPACING   = 80                         -- studs between zone centres on X axis
local ZONE_Y_CENTRE  = 10                         -- Y centre of the zone Part
local ZONE_COLOR     = Color3.fromRGB(255, 140, 0)

-- State ───────────────────────────────────────────────────────────────────────
local plotAssignments = {}   -- userId → plotIndex (1-based)
local nextPlotIndex   = 1
local zones           = {}   -- userId → { part, playersInside = {userId → true} }

local zonesFolder
local function EnsureFolder()
    if not zonesFolder or not zonesFolder.Parent then
        zonesFolder = workspace:FindFirstChild("ForgeZones")
        if not zonesFolder then
            zonesFolder = Instance.new("Folder")
            zonesFolder.Name = "ForgeZones"
            zonesFolder.Parent = workspace
        end
    end
end

-- ── Plot position ─────────────────────────────────────────────────────────────
local function PlotCentre(plotIndex)
    return Vector3.new((plotIndex - 1) * ZONE_SPACING, ZONE_Y_CENTRE, 0)
end

-- ── Build zone Part for a player ─────────────────────────────────────────────
local function BuildZone(player, plotIndex)
    EnsureFolder()
    local part = Instance.new("Part")
    part.Name             = "ForgeZone_" .. player.UserId
    part.Size             = ZONE_SIZE
    part.CFrame           = CFrame.new(PlotCentre(plotIndex))
    part.Anchored         = true
    part.CanCollide        = false
    part.Transparency      = 0.85
    part.Color             = ZONE_COLOR
    part.Material          = Enum.Material.Neon
    part.CastShadow        = false
    part.Parent            = zonesFolder

    -- Visible ground platform so the plot is easy to see
    local pad = Instance.new("Part")
    pad.Name          = "ForgePad_" .. player.UserId
    pad.Size          = Vector3.new(ZONE_SIZE.X, 1, ZONE_SIZE.Z)
    pad.CFrame        = CFrame.new(PlotCentre(plotIndex).X, 0.5, PlotCentre(plotIndex).Z)
    pad.Anchored      = true
    pad.Material      = Enum.Material.Slate
    pad.Color         = Color3.fromRGB(70, 55, 45)
    pad.Parent        = zonesFolder

    -- Label above the zone: owner name, then forge level + equipped title (see Refresh)
    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "PlotSign"
    billboard.Size        = UDim2.new(0, 260, 0, 56)
    billboard.StudsOffset = Vector3.new(0, ZONE_SIZE.Y / 2 + 4, 0)
    billboard.MaxDistance = 150
    billboard.AlwaysOnTop = false
    billboard.Parent      = part

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name               = "Owner"
    nameLabel.Size               = UDim2.new(1, 0, 0.55, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text               = player.DisplayName .. "'s Forge"
    nameLabel.TextColor3         = Color3.fromRGB(255, 200, 80)
    nameLabel.Font               = Enum.Font.GothamBold
    nameLabel.TextScaled         = true
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.Parent             = billboard

    local subLabel = Instance.new("TextLabel")
    subLabel.Name                = "Sub"
    subLabel.Position            = UDim2.new(0, 0, 0.55, 0)
    subLabel.Size                = UDim2.new(1, 0, 0.45, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.Text                = ""
    subLabel.TextColor3          = Color3.fromRGB(235, 235, 235)
    subLabel.Font                = Enum.Font.Gotham
    subLabel.TextScaled          = true
    subLabel.TextStrokeTransparency = 0.5
    subLabel.Parent              = billboard

    return part
end

-- ── Touched detection helpers ─────────────────────────────────────────────────
local function GetPlayerFromHit(hit)
    local char = hit.Parent
    if not char then return nil end
    return Players:GetPlayerFromCharacter(char)
end

local function WireZoneTouched(ownerPlayer, part)
    local entry = zones[ownerPlayer.UserId]

    part.Touched:Connect(function(hit)
        local visitor = GetPlayerFromHit(hit)
        if not visitor or visitor.UserId == ownerPlayer.UserId then return end
        if entry.playersInside[visitor.UserId] then return end

        -- Friends-only forges turn strangers away (spec 7.2)
        local ownerData = PlayerDataService.Get(ownerPlayer)
        if ownerData and ownerData.Settings and ownerData.Settings.ForgeFriendsOnly then
            entry.friendCache = entry.friendCache or {}
            local isFriend = entry.friendCache[visitor.UserId]
            if isFriend == nil then
                local ok, res = pcall(function() return visitor:IsFriendsWith(ownerPlayer.UserId) end)
                isFriend = ok and res or false
                entry.friendCache[visitor.UserId] = isFriend
            end
            if not isFriend then
                entry.turnedAway = entry.turnedAway or {}
                if not entry.turnedAway[visitor.UserId] or os.clock() - entry.turnedAway[visitor.UserId] > 5 then
                    entry.turnedAway[visitor.UserId] = os.clock()
                    RemoteEvents.Notify:FireClient(visitor, "Private forge", ownerPlayer.DisplayName .. "'s forge is friends-only.")
                end
                local char = visitor.Character
                if char then char:PivotTo(CFrame.new(entry.part.Position.X, 6, entry.part.Position.Z - 45)) end
                return
            end
        end

        entry.playersInside[visitor.UserId] = true

        -- Challenge tracking: visitor visited a forge
        ChallengeService.TrackEvent(visitor, "ForgeVisit", { count = 1 })

        -- Send forge data snapshot to the visiting player
        local data = PlayerDataService.Get(ownerPlayer)
        local forgeSnapshot
        if data then
            local golemSummary = {}
            for _, g in ipairs(data.Golems or {}) do
                table.insert(golemSummary, {
                    element  = g.element,
                    tier     = g.tier,
                    deployed = g.deployed,
                })
            end
            forgeSnapshot = {
                userId       = ownerPlayer.UserId,
                displayName  = ownerPlayer.DisplayName,
                forgeLevel   = data.ForgeLevel,
                playerLevel  = data.PlayerLevel,
                golemCount   = #(data.Golems or {}),
                golems       = golemSummary,
                masteryLevels = data.MasteryLevels,
            }
        end

        RemoteEvents.ForgeZoneEntered:FireClient(
            visitor, ownerPlayer.UserId, ownerPlayer.DisplayName, forgeSnapshot)
    end)

    part.TouchEnded:Connect(function(hit)
        local visitor = GetPlayerFromHit(hit)
        if not visitor or visitor.UserId == ownerPlayer.UserId then return end
        if not entry.playersInside[visitor.UserId] then return end

        -- Only fire Left once all character parts have exited (debounce via task.defer)
        task.defer(function()
            if not entry.playersInside[visitor.UserId] then return end
            local char = visitor.Character
            if char then
                local still = false
                for _, p in ipairs(workspace:GetPartsInPart(part)) do
                    if p:IsDescendantOf(char) then still = true; break end
                end
                if still then return end
            end

            entry.playersInside[visitor.UserId] = nil
            RemoteEvents.ForgeZoneLeft:FireClient(visitor)
        end)
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────
local function FreePlotIndex()
    local used = {}
    for _, idx in pairs(plotAssignments) do used[idx] = true end
    local i = 1
    while used[i] do i += 1 end
    return i
end

-- Rebuild a player's forge (level / skin / decoration) and refresh its sign
local function IdleGolems(data)
    local list = {}
    for _, g in ipairs(data.Golems or {}) do
        if not g.deployed then table.insert(list, { element = g.element, tier = g.tier, variant = g.variant }) end
    end
    table.sort(list, function(a, b) return (a.tier or 1) > (b.tier or 1) end)
    return list
end

-- Everything that changes how the forge looks; the watcher rebuilds when this changes
local function Signature(data)
    local parts = { data.ForgeLevel or 1, data.StorageTier or 0, data.PlayerLevel or 1, "A" .. (data.Ascensions or 0) }
    for k, v in pairs(data.Equipped or {}) do table.insert(parts, k .. "=" .. tostring(v)) end
    table.sort(parts, function(a, b) return tostring(a) < tostring(b) end)
    for i, g in ipairs(IdleGolems(data)) do
        if i > 5 then break end
        table.insert(parts, tostring(g.element) .. tostring(g.tier) .. tostring(g.variant))
    end
    return table.concat(parts, "|")
end

function ForgeZoneService.Refresh(player)
    local entry = zones[player.UserId]
    local idx = plotAssignments[player.UserId]
    local data = PlayerDataService.Get(player)
    if not entry or not idx or not data then return end

    if entry.forge then entry.forge:Destroy() end
    EnsureFolder()
    local levelUp = entry.builtLevel and (data.ForgeLevel or 1) > entry.builtLevel
    entry.forge = ForgeBuilder.Build(zonesFolder, PlotCentre(idx), data.ForgeLevel or 1, data.Equipped, {
        playerLevel = data.PlayerLevel or 1,
        storageTier = data.StorageTier or 0,
        golems      = IdleGolems(data),
    })
    entry.builtLevel = data.ForgeLevel or 1
    entry.signature = Signature(data)
    if levelUp then ForgeBuilder.Celebrate(entry.forge) end

    local sign = entry.part:FindFirstChild("PlotSign")
    local sub = sign and sign:FindFirstChild("Sub")
    if sub then
        local title = data.Equipped and data.Equipped.Title
        local fd = ForgeData.Get(data.ForgeLevel or 1)
        local asc = (data.Ascensions or 0) > 0 and ("  *" .. AscensionData.Title(data.Ascensions) .. "*") or ""
        sub.Text = "Forge Level " .. (data.ForgeLevel or 1) .. asc .. (fd and ("  " .. fd.displayName) or "") .. (title and ("  -  " .. title) or "")
                   .. ((data.Settings and data.Settings.ForgeFriendsOnly) and "  (friends only)" or "")
    end
end

-- ── Forge Builder pieces ──────────────────────────────────────────────────────
local ForgeBuildData = require(game.ReplicatedStorage.Shared.Data.ForgeBuildData)
local FLOOR_Y = 1            -- top of the plot's ground pad

local function BuildPiece(def, placed, centre)
    local template = game.ReplicatedStorage:FindFirstChild("BuildAssets")
    template = template and template:FindFirstChild(def.id)
    local piece
    if template then
        piece = template:Clone()
        for _, d in ipairs(piece:GetDescendants()) do
            if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
        end
        local _, size = piece:GetBoundingBox()
        if size.Y > 0.01 then piece:ScaleTo(piece:GetScale() * def.height / size.Y) end
    else
        -- no model uploaded yet: a plain labelled block
        piece = Instance.new("Model")
        local block = Instance.new("Part")
        block.Name = "Block"
        block.Size = Vector3.new(def.height * 0.6, def.height, def.height * 0.6)
        block.Color = def.color or Color3.fromRGB(170, 140, 110)
        block.Anchored, block.CanCollide = true, false
        block.Parent = piece
        piece.PrimaryPart = block
    end
    piece.Name = def.id
    local _, size = piece:GetBoundingBox()
    local pos = Vector3.new(centre.X + placed.x, FLOOR_Y + size.Y / 2, centre.Z + placed.z)
    piece:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(placed.rot or 0), 0))
    return piece
end

local function BuildSignature(data)
    local assets = game.ReplicatedStorage:FindFirstChild("BuildAssets")
    local parts = { tostring(assets and assets:GetAttribute("Version") or 0) }     -- redraw once the models have loaded
    for _, p in ipairs(data.ForgeBuild and data.ForgeBuild.placed or {}) do
        table.insert(parts, string.format("%s@%d,%d,%d", p.id, p.x, p.z, p.rot or 0))
    end
    return table.concat(parts, ";")
end

-- Redraw the pieces placed on a player's plot (visible to everyone)
function ForgeZoneService.RefreshBuild(player)
    local entry = zones[player.UserId]
    local idx = plotAssignments[player.UserId]
    local data = PlayerDataService.Get(player)
    if not entry or not idx or not data then return end
    EnsureFolder()
    if entry.build then entry.build:Destroy() end
    local model = Instance.new("Model")
    model.Name = "ForgeBuild_" .. player.UserId
    local centre = PlotCentre(idx)
    for _, placed in ipairs(data.ForgeBuild and data.ForgeBuild.placed or {}) do
        local def = ForgeBuildData.Get(placed.id)
        if def then
            local ok, piece = pcall(BuildPiece, def, placed, centre)
            if ok and piece then piece.Parent = model else warn("[ForgeBuild] could not draw " .. tostring(placed.id) .. ": " .. tostring(piece)) end
        end
    end
    model.Parent = zonesFolder
    entry.build = model
    entry.buildSignature = BuildSignature(data)
end

function ForgeZoneService.OnPlayerAdded(player)
    local plotIndex = FreePlotIndex()
    plotAssignments[player.UserId] = plotIndex

    local part = BuildZone(player, plotIndex)
    zones[player.UserId] = { part = part, playersInside = {} }
    WireZoneTouched(player, part)
    ForgeZoneService.Refresh(player)
    ForgeZoneService.RefreshBuild(player)

    -- Keep the forge in step with the player's Golems, equipment and vault
    task.spawn(function()
        while player.Parent and zones[player.UserId] and plotAssignments[player.UserId] == plotIndex do
            task.wait(3)
            local data = PlayerDataService.Get(player)
            local entry = zones[player.UserId]
            if data and entry and entry.signature ~= Signature(data) then
                ForgeZoneService.Refresh(player)
            end
            if data and entry and entry.buildSignature ~= BuildSignature(data) then
                ForgeZoneService.RefreshBuild(player)
            end
        end
    end)
end

-- Move a player's character to their own forge
function ForgeZoneService.Teleport(player)
    local idx = plotAssignments[player.UserId]
    local char = player.Character
    if not idx or not char then return false end
    local c = PlotCentre(idx)
    char:PivotTo(CFrame.lookAt(Vector3.new(c.X, 6, c.Z + 20), Vector3.new(c.X, 6, c.Z - 10)))
    return true
end

function ForgeZoneService.OnPlayerLeave(player)
    local entry = zones[player.UserId]
    if entry then
        -- Notify any visitors still inside that the forge owner left
        for visitorId in pairs(entry.playersInside) do
            local visitor = Players:GetPlayerByUserId(visitorId)
            if visitor then
                RemoteEvents.ForgeZoneLeft:FireClient(visitor)
            end
        end
        if entry.part and entry.part.Parent then
            entry.part:Destroy()
        end
        if entry.forge then entry.forge:Destroy() end
        if entry.build then entry.build:Destroy() end
        local pad = zonesFolder and zonesFolder:FindFirstChild("ForgePad_" .. player.UserId)
        if pad then pad:Destroy() end
        zones[player.UserId] = nil
    end
    plotAssignments[player.UserId] = nil
end

-- Returns the world CFrame of a player's forge plot
function ForgeZoneService.GetPlotCFrame(userId)
    local idx = plotAssignments[userId]
    if not idx then return nil end
    return CFrame.new(PlotCentre(idx))
end

return ForgeZoneService
