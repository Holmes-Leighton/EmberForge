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

    -- Level 1 forge: small stone forge with a fire pit
    local c = PlotCentre(plotIndex)
    local forge = Instance.new("Part")
    forge.Name = "StoneForge"
    forge.Anchored = true
    forge.Size = Vector3.new(8, 6, 6)
    forge.Material = Enum.Material.Cobblestone
    forge.Color = Color3.fromRGB(95, 90, 88)
    forge.CFrame = CFrame.new(c.X, 4, c.Z - 10)
    forge.Parent = zonesFolder

    local pit = Instance.new("Part")
    pit.Name = "FirePit"
    pit.Anchored = true
    pit.Shape = Enum.PartType.Cylinder
    pit.Size = Vector3.new(1, 5, 5)
    pit.Material = Enum.Material.Basalt
    pit.Color = Color3.fromRGB(35, 30, 28)
    pit.CFrame = CFrame.new(c.X, 1.5, c.Z + 4) * CFrame.Angles(0, 0, math.pi / 2)
    pit.Parent = zonesFolder

    local fire = Instance.new("Fire")
    fire.Heat = 9
    fire.Size = 7
    fire.Parent = pit
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(255, 140, 50)
    glow.Range = 30
    glow.Brightness = 2
    glow.Parent = pit

    -- Label above zone
    local billboard = Instance.new("BillboardGui")
    billboard.Size        = UDim2.new(0, 200, 0, 36)
    billboard.StudsOffset = Vector3.new(0, ZONE_SIZE.Y / 2 + 3, 0)
    billboard.AlwaysOnTop = false
    billboard.Parent      = part

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size               = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text               = "🔥 " .. player.DisplayName .. "'s Forge"
    nameLabel.TextColor3         = Color3.fromRGB(255, 200, 80)
    nameLabel.Font               = Enum.Font.GothamBold
    nameLabel.TextSize           = 14
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.Parent             = billboard

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
function ForgeZoneService.OnPlayerAdded(player)
    local plotIndex = nextPlotIndex
    nextPlotIndex = nextPlotIndex + 1
    plotAssignments[player.UserId] = plotIndex

    local part = BuildZone(player, plotIndex)
    zones[player.UserId] = { part = part, playersInside = {} }
    WireZoneTouched(player, part)
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
        zones[player.UserId] = nil
    end
    plotAssignments[player.UserId] = nil
end

-- Returns the world CFrame of a player's forge plot (so clients can teleport to it)
function ForgeZoneService.GetPlotCFrame(userId)
    local idx = plotAssignments[userId]
    if not idx then return nil end
    return CFrame.new(PlotCentre(idx))
end

return ForgeZoneService
