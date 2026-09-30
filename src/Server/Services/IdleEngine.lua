-- Calculates offline resource production when a player returns.
-- All calculations are server-authoritative.

local GameConfig   = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local GolemData    = require(game.ReplicatedStorage.Shared.Data.GolemData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)
local ForgeData    = require(game.ReplicatedStorage.Shared.Data.ForgeData)

local IdleEngine = {}

-- ── Mastery bonuses (derived from playerData.MasteryLevels directly) ─────────
local function GetMasteryLevel(xp)
    local thresholds = GameConfig.MASTERY_XP_THRESHOLDS
    for lvl = #thresholds, 1, -1 do
        if xp >= (thresholds[lvl] or 0) then return lvl end
    end
    return 1
end

-- Returns { miningRateBonus, luckBonus, smeltSpeedBonus, allStatsBonus }
local function MasteryBonuses(playerData, elementId)
    local xp  = ((playerData.MasteryLevels or {})[elementId] or 0)
    local lvl = GetMasteryLevel(xp)
    return {
        miningRateBonus  = lvl >= 5  and 0.05 or 0,
        luckBonus        = lvl >= 10 and 0.10 or 0,
        allStatsBonus    = lvl >= 20 and 0.20 or 0,
    }
end

-- Storm Golems energise the rest of the crew (spec 3.1): each deployed Storm Golem adds
-- 3% x its tier to every other Golem's efficiency, up to +25%.
local function StormBoost(playerData)
    local sum = 0
    for _, g in ipairs(playerData.Golems or {}) do
        if g.deployed and g.element == "Storm" then sum += (g.tier or 1) end
    end
    return math.min(0.25, 0.03 * sum)
end

-- Rare blueprint discovery (spec 4.3: "Golem rare mining drops", Tier 2-4).
-- `produced` is how many resources were just mined; luck raises the odds. Returns the id or nil.
local function RollBlueprintDrop(playerData, produced, luck)
    local chance = (produced / 100) * 0.001 * (1 + (luck or 0) * 3)
    if math.random() >= chance then return nil end

    local RecipeData = require(game.ReplicatedStorage.Shared.Data.RecipeData)
    local pool = {}
    for bpId, bp in pairs(RecipeData.Blueprints) do
        if not bp.isEventGolem and bp.tier >= 2 and bp.tier <= 4
            and not Utils.TableContains(playerData.Blueprints, bpId)
            and (playerData.ForgeLevel or 1) >= ((bp.forgeLevelRequired or 1) - 2) then
            table.insert(pool, { item = bpId, weight = ({ 0, 6, 3, 1 })[bp.tier] })
        end
    end
    if #pool == 0 then return nil end
    local pick = Utils.WeightedRandom(pool)
    table.insert(playerData.Blueprints, pick)
    return pick
end
IdleEngine.RollBlueprintDrop = RollBlueprintDrop

-- Maximum offline accumulation time in seconds based on storage tier
local function StorageCapSeconds(storageTier)
    if storageTier >= 2 then
        return GameConfig.OFFLINE_STORAGE_PREMIUM_HOURS * 3600
    elseif storageTier >= 1 then
        return GameConfig.OFFLINE_STORAGE_UPGRADED_HOURS * 3600
    else
        return GameConfig.OFFLINE_STORAGE_BASE_HOURS * 3600
    end
end

IdleEngine.StorageCapSeconds = StorageCapSeconds

-- Returns a production summary for a single golem over `seconds` elapsed
local function GolemProduction(golem, seconds, storageTier, playerData, stormBoost)
    if not golem.deployed or not golem.zoneId then return {} end

    -- Durability: drain time, clamp at 0, produce nothing when broken
    local durability = golem._durabilitySeconds
    if durability ~= nil then
        local active = math.min(seconds, math.max(0, durability))
        golem._durabilitySeconds = math.max(0, durability - seconds)
        if active <= 0 then return {} end  -- fully broken
        seconds = active
    end

    local stats  = GolemData.ComputeStats(golem.element, golem.tier, golem.fusionBonus, golem.quality, golem.variant)
    if not stats then return {} end

    -- Apply mastery bonuses
    local mb = MasteryBonuses(playerData, golem.element)
    local fp = ForgeData.TotalPerks(playerData.ForgeLevel or 1)
    local miningRate = stats.miningRate * (1 + mb.miningRateBonus + mb.allStatsBonus + fp.mining)
    local luck       = stats.luck       * (1 + mb.luckBonus       + mb.allStatsBonus + fp.luck)

    -- Clamp time to storage cap
    local capSeconds = StorageCapSeconds(storageTier)
    local effectiveSeconds = math.min(seconds, capSeconds)

    local efficiency = stats.efficiency * (golem.element ~= "Storm" and (1 + (stormBoost or 0)) or 1)
    local rawRate = miningRate * efficiency
    local produced = math.floor(rawRate * (effectiveSeconds / 3600))
    local carryCapped = math.min(produced, math.floor(stats.carryCapacity * (1 + fp.carry)))

    return {
        golemId   = golem.id,
        element   = golem.element,
        zoneId    = golem.zoneId,
        produced  = carryCapped,
        luck      = luck,
    }
end

-- Main entry point: call on player join.
-- Returns a table of { materialId → quantity } to add to inventory.
function IdleEngine.CalculateOfflineProduction(playerData)
    local now       = Utils.UnixTimestamp()
    local lastOnline = playerData.LastOnline or now
    local elapsed   = math.max(0, now - lastOnline)

    if elapsed < 1 then return {} end  -- no meaningful time passed

    local storageTier = playerData.StorageTier or 0
    local gains = {}

    -- Community event drop multiplier
    local SeasonPassService = require(script.Parent.SeasonPassService)
    local SeasonData_ = require(game.ReplicatedStorage.Shared.Data.SeasonData)
    local currentSeason_ = SeasonData_.GetCurrentSeason()
    local eventMult = SeasonPassService.GetEventDropMultiplier(currentSeason_ and currentSeason_.id) or 1.0

    -- Material Magnet: 2× resource output for 24h after purchase
    local magnetActive = (playerData.MaterialMagnetExpiry or 0) > Utils.UnixTimestamp()
    if magnetActive then eventMult = eventMult * 2 end
    eventMult = eventMult * require(script.Parent.LiveOpsService).GetMultiplier("drops")

    local stormBoost = StormBoost(playerData)
    for _, golem in ipairs(playerData.Golems or {}) do
        if golem.deployed then
            local production = GolemProduction(golem, elapsed, storageTier, playerData, stormBoost)
            if production.produced and production.produced > 0 then
                -- Sample drop types based on zone drop table and luck
                local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
                local luckMult = 1 + (production.luck * 3)  -- luck → up to 3x multiplier on rare weight

                -- Distribute production across drops (apply event multiplier)
                local remaining = math.floor(production.produced * eventMult)
                while remaining > 0 do
                    local batch = math.min(remaining, 10)
                    local materialId = MiningZoneData.SampleDrop(production.zoneId, luckMult)
                    if materialId then
                        gains[materialId] = (gains[materialId] or 0) + batch
                    end
                    remaining = remaining - batch
                end

                -- Rare blueprint discovery
                local found = RollBlueprintDrop(playerData, production.produced, production.luck)
                if found then gains["__blueprint:" .. found] = 1 end
            end
        end
    end

    return gains, elapsed
end

-- Apply the offline gains to player data and update timestamp
function IdleEngine.ApplyOfflineGains(playerData, gains)
    for materialId, qty in pairs(gains) do
        playerData.Inventory[materialId] = (playerData.Inventory[materialId] or 0) + qty
    end
    playerData.LastOnline = Utils.UnixTimestamp()
end

-- Called each second for online players to tick deployed golem productions
-- Returns incremental gains for this tick (used to update HUD)
function IdleEngine.TickOnlineProduction(playerData, deltaSeconds)
    local gains = {}
    local byElement = {}   -- element → resources its Golems mined this tick (for mastery)
    local storageTier = playerData.StorageTier or 0
    local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
    local SeasonPassService = require(script.Parent.SeasonPassService)
    local SeasonData__ = require(game.ReplicatedStorage.Shared.Data.SeasonData)
    local currentSeason__ = SeasonData__.GetCurrentSeason()
    local eventMult = SeasonPassService.GetEventDropMultiplier(currentSeason__ and currentSeason__.id) or 1.0
    local magnetActive = (playerData.MaterialMagnetExpiry or 0) > Utils.UnixTimestamp()
    if magnetActive then eventMult = eventMult * 2 end
    eventMult = eventMult * require(script.Parent.LiveOpsService).GetMultiplier("drops")

    local stormBoost = StormBoost(playerData)
    local fp = ForgeData.TotalPerks(playerData.ForgeLevel or 1)
    for _, golem in ipairs(playerData.Golems or {}) do
        if golem.deployed and golem.zoneId then
            -- Drain durability; skip production when broken
            if golem._durabilitySeconds ~= nil then
                golem._durabilitySeconds = math.max(0, golem._durabilitySeconds - deltaSeconds)
                if golem._durabilitySeconds <= 0 then
                    continue  -- broken golem produces nothing
                end
            end

            local stats = GolemData.ComputeStats(golem.element, golem.tier, golem.fusionBonus, golem.quality, golem.variant)
            local carried = golem._carriedResources or 0
            local carryCap = stats and math.floor(stats.carryCapacity * (1 + fp.carry)) or 0
            -- A full Golem waits (still deployed) until the player collects
            if stats and carried < carryCap then
                local mb     = MasteryBonuses(playerData, golem.element)
                local mRate  = stats.miningRate * (1 + mb.miningRateBonus + mb.allStatsBonus + fp.mining)
                local luckM  = stats.luck       * (1 + mb.luckBonus       + mb.allStatsBonus + fp.luck)
                local efficiency = stats.efficiency * (golem.element ~= "Storm" and (1 + stormBoost) or 1)
                local rate   = mRate * efficiency
                local speed  = GameConfig.ONLINE_PRODUCTION_SPEED or 1
                golem._accumulatedResources = (golem._accumulatedResources or 0) + rate * (deltaSeconds * speed / 3600)

                local toCommit = math.floor(golem._accumulatedResources)
                if toCommit > 0 then
                    golem._accumulatedResources = golem._accumulatedResources - toCommit
                    local actual = math.min(toCommit, carryCap - carried)
                    if actual > 0 then
                        local luckMult = 1 + (luckM * 3)
                        local materialId = MiningZoneData.SampleDrop(golem.zoneId, luckMult)
                        if materialId then
                            local amount = math.floor(actual * eventMult)
                            gains[materialId] = (gains[materialId] or 0) + amount
                            byElement[golem.element] = (byElement[golem.element] or 0) + amount
                            golem._carriedResources = carried + actual

                            local found = RollBlueprintDrop(playerData, actual, luckM)
                            if found then gains["__blueprint:" .. found] = 1 end
                        end
                    end
                end
            end
        end
    end

    return gains, byElement
end

return IdleEngine
