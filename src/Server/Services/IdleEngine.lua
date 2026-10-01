-- Calculates offline resource production when a player returns.
-- All calculations are server-authoritative.

local GameConfig   = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local GolemData    = require(game.ReplicatedStorage.Shared.Data.GolemData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)
local ForgeData    = require(game.ReplicatedStorage.Shared.Data.ForgeData)
local PetData      = require(game.ReplicatedStorage.Shared.Data.PetData)
local ForgeBuildData = require(game.ReplicatedStorage.Shared.Data.ForgeBuildData)

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

-- ── Special Golem skills (GolemData.Specials) ────────────────────────────────
-- Aura skills come from the deployed crew; self skills are read per Golem. All of them are read from
-- GolemData.Specials[element].skill.params so the numbers shown to the player and the numbers used here
-- can never drift apart.
local function SkillParams(element)
    local def = GolemData.Specials[element]
    return def and def.skill.params or nil
end

-- { luck = +luck for everyone, shelter = durability wear saved on everyone else, blueprint = blueprint-find multiplier }
local function CrewAuras(playerData)
    local coral, jar, bone = 0, 0, 0
    for _, g in ipairs(playerData.Golems or {}) do
        if g.deployed then
            if g.element == "Coral" then coral += 1
            elseif g.element == "StormJar" then jar += 1
            elseif g.element == "Dragonbone" then bone += 1 end
        end
    end
    local cp, jp, bp = SkillParams("Coral"), SkillParams("StormJar"), SkillParams("Dragonbone")
    local pets = PetData.Boosts(playerData)            -- the pets being worn (small boosts)
    local forge = ForgeBuildData.Perks(playerData.ForgeBuild and playerData.ForgeBuild.placed)   -- pieces on your plot
    return {
        luck      = math.min(cp.luckCap, cp.luckPer * coral) + pets.luck + forge.luck,
        shelter   = math.min(jp.shelterCap, jp.shelterPer * jar),
        blueprint = (1 + math.min(bp.blueprintCap, bp.blueprintPer * bone)) * (1 + pets.bp),
        rate      = pets.rate + forge.rate,      -- mining speed
        carry     = pets.carry + forge.carry,    -- carry capacity
        eff       = pets.eff + forge.eff,        -- efficiency
        wear      = math.min(0.9, pets.wear + forge.wear),   -- durability wear saved
    }
end
IdleEngine.CrewAuras = CrewAuras

-- How fast this Golem wears out: 1 = normal. Patchwork lasts longer, Clockwork wears faster, and every
-- Storm in a Jar on the crew shelters everyone except other Jars.
local function DrainFactor(golem, auras)
    local p = SkillParams(golem.element)
    local f = (p and p.drain) or 1
    if golem.element ~= "StormJar" then f *= (1 - auras.shelter) end
    return f * (1 - auras.wear)
end

-- Rare blueprint discovery (spec 4.3: "Golem rare mining drops", Tier 2-4).
-- `produced` is how many resources were just mined; luck raises the odds. Returns the id or nil.
-- `bpMult` multiplies the odds (Dragonbone's Hoarder's Instinct).
local function RollBlueprintDrop(playerData, produced, luck, bpMult)
    local chance = (produced / 100) * 0.001 * (1 + (luck or 0) * 3) * (bpMult or 1)
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
local function GolemProduction(golem, seconds, storageTier, playerData, stormBoost, auras)
    if not golem.deployed or not golem.zoneId then return {} end
    auras = auras or CrewAuras(playerData)
    local skill = SkillParams(golem.element)

    -- Durability: drain time, clamp at 0, produce nothing when broken
    local durability = golem._durabilitySeconds
    if durability ~= nil then
        local drain = DrainFactor(golem, auras)
        local active = math.min(seconds, math.max(0, durability) / drain)
        golem._durabilitySeconds = math.max(0, durability - seconds * drain)
        if active <= 0 then return {} end  -- fully broken
        seconds = active
    end

    local stats  = GolemData.ComputeStats(golem.element, golem.tier, golem.fusionBonus, golem.quality, golem.variant)
    if not stats then return {} end

    -- Apply mastery bonuses
    local mb = MasteryBonuses(playerData, golem.element)
    local fp = ForgeData.TotalPerks(playerData.ForgeLevel or 1, playerData.Ascensions)
    local miningRate = stats.miningRate * (1 + mb.miningRateBonus + mb.allStatsBonus + fp.mining)
    local luck       = stats.luck       * (1 + mb.luckBonus       + mb.allStatsBonus + fp.luck) + auras.luck
    -- self skills: Clockwork's Overclock, Gargoyle's Night Watch (this is the offline path)
    if skill then
        miningRate *= (skill.rate or 1) * (skill.offlineRate or 1)
    end
    miningRate *= (1 + auras.rate)                                   -- pets

    -- Clamp time to storage cap
    local capSeconds = StorageCapSeconds(storageTier)
    local effectiveSeconds = math.min(seconds, capSeconds)

    local efficiency = stats.efficiency * (golem.element ~= "Storm" and (1 + (stormBoost or 0)) or 1) * (1 + auras.eff)
    local rawRate = miningRate * efficiency
    local produced = math.floor(rawRate * (effectiveSeconds / 3600))
    -- Woven's Net Haul: its doubled hauls, as the average over a long absence
    if skill and skill.doubleChance then produced = math.floor(produced * (1 + skill.doubleChance)) end
    local carryCapped = math.min(produced, math.floor(stats.carryCapacity * (1 + fp.carry) * (1 + auras.carry)))

    return {
        golemId   = golem.id,
        element   = golem.element,
        zoneId    = golem.zoneId,
        produced  = carryCapped,
        luck      = luck,
        transmute = skill and skill.chance or 0,          -- Alchemist
        transmuteLuck = skill and skill.luckMult or 1,
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
    local LiveOps = require(script.Parent.LiveOpsService)
    eventMult = eventMult * LiveOps.GetMultiplier("drops")
    local eventLuck = LiveOps.GetMultiplier("luck") * ((playerData.LuckBoostExpiry or 0) > Utils.UnixTimestamp() and 2 or 1)   -- + the Lucky Boost

    local stormBoost = StormBoost(playerData)
    local auras = CrewAuras(playerData)
    for _, golem in ipairs(playerData.Golems or {}) do
        if golem.deployed then
            local production = GolemProduction(golem, elapsed, storageTier, playerData, stormBoost, auras)
            if production.produced and production.produced > 0 then
                -- Sample drop types based on zone drop table and luck
                local MiningZoneData = require(game.ReplicatedStorage.Shared.Data.MiningZoneData)
                local luckMult = (1 + (production.luck * 3)) * eventLuck  -- luck → up to 3x multiplier on rare weight

                -- Distribute production across drops (apply event multiplier)
                local remaining = math.floor(production.produced * eventMult * LiveOps.GetElementMultiplier(golem.element))
                while remaining > 0 do
                    local batch = math.min(remaining, 10)
                    -- Alchemist's Transmutation: some batches are brewed into something rarer
                    local batchLuck = luckMult
                    if production.transmute > 0 and math.random() < production.transmute then
                        batchLuck = luckMult * production.transmuteLuck
                    end
                    local materialId = MiningZoneData.SampleDrop(production.zoneId, batchLuck)
                    if materialId then
                        gains[materialId] = (gains[materialId] or 0) + batch
                    end
                    remaining = remaining - batch
                end

                -- Rare blueprint discovery
                local found = RollBlueprintDrop(playerData, production.produced, production.luck, auras.blueprint)
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
    local LiveOps = require(script.Parent.LiveOpsService)
    eventMult = eventMult * LiveOps.GetMultiplier("drops")
    local eventLuck = LiveOps.GetMultiplier("luck") * ((playerData.LuckBoostExpiry or 0) > Utils.UnixTimestamp() and 2 or 1)   -- + the Lucky Boost

    local stormBoost = StormBoost(playerData)
    local auras = CrewAuras(playerData)
    local fp =ForgeData.TotalPerks(playerData.ForgeLevel or 1, playerData.Ascensions)
    for _, golem in ipairs(playerData.Golems or {}) do
        if golem.deployed and golem.zoneId then
            local skill = SkillParams(golem.element)
            -- Drain durability; skip production when broken
            if golem._durabilitySeconds ~= nil then
                golem._durabilitySeconds = math.max(0, golem._durabilitySeconds - deltaSeconds * DrainFactor(golem, auras))
                if golem._durabilitySeconds <= 0 then
                    continue  -- broken golem produces nothing
                end
            end

            local stats = GolemData.ComputeStats(golem.element, golem.tier, golem.fusionBonus, golem.quality, golem.variant)
            local carried = golem._carriedResources or 0
            local carryCap = stats and math.floor(stats.carryCapacity * (1 + fp.carry) * (1 + auras.carry)) or 0
            -- A full Golem waits (still deployed) until the player collects
            if stats and carried < carryCap then
                local mb     = MasteryBonuses(playerData, golem.element)
                local mRate  = stats.miningRate * (1 + mb.miningRateBonus + mb.allStatsBonus + fp.mining)
                local luckM  = stats.luck       * (1 + mb.luckBonus       + mb.allStatsBonus + fp.luck) + auras.luck
                local efficiency = stats.efficiency * (golem.element ~= "Storm" and (1 + stormBoost) or 1) * (1 + auras.eff)
                local rate   = mRate * efficiency * (1 + auras.rate)            -- pets
                -- self skills: Clockwork's Overclock, Gargoyle's Night Watch (slower while you play)
                if skill then rate *= (skill.rate or 1) * (skill.onlineRate or 1) end
                local speed  = GameConfig.ONLINE_PRODUCTION_SPEED or 1
                golem._accumulatedResources = (golem._accumulatedResources or 0) + rate * (deltaSeconds * speed / 3600)

                local toCommit = math.floor(golem._accumulatedResources)
                if toCommit > 0 then
                    golem._accumulatedResources = golem._accumulatedResources - toCommit
                    local actual = math.min(toCommit, carryCap - carried)
                    if actual > 0 then
                        local luckMult = (1 + (luckM * 3)) * eventLuck
                        -- Alchemist's Transmutation: sometimes a haul is brewed into something rarer
                        if skill and skill.chance and math.random() < skill.chance then luckMult *= skill.luckMult end
                        local materialId = MiningZoneData.SampleDrop(golem.zoneId, luckMult)
                        if materialId then
                            local amount = math.floor(actual * eventMult * LiveOps.GetElementMultiplier(golem.element))
                            -- Woven's Net Haul: sometimes a haul comes back doubled
                            if skill and skill.doubleChance and math.random() < skill.doubleChance then amount *= 2 end
                            gains[materialId] = (gains[materialId] or 0) + amount
                            byElement[golem.element] = (byElement[golem.element] or 0) + amount
                            golem._carriedResources = carried + actual

                            local found = RollBlueprintDrop(playerData, actual, luckM, auras.blueprint)
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
