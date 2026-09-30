-- Manages forge leveling, smelting queues, and crafting.

local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local ForgeData         = require(game.ReplicatedStorage.Shared.Data.ForgeData)
local MaterialData      = require(game.ReplicatedStorage.Shared.Data.MaterialData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ForgeService = {}

local STORAGE_VAULT_RECIPE = ForgeData.StorageVault

-- Active smelt timers: userId → array of smelt job records
local smeltJobs = {}

-- ── Forge XP & Leveling ──────────────────────────────────────────────────────
function ForgeService.AddForgeXP(player, xp)
    local data = PlayerDataService.Get(player)
    if not data then return false end

    data.ForgeXP = (data.ForgeXP or 0) + xp
    PlayerDataService.MarkDirty(player)

    -- Check for level-up
    local leveledUp = false
    while data.ForgeLevel < GameConfig.MAX_FORGE_LEVEL do
        local fd  = ForgeData.Get(data.ForgeLevel)
        local nfd = ForgeData.Get(data.ForgeLevel + 1)
        if nfd and data.ForgeXP >= nfd.xpRequired then
            data.ForgeLevel = data.ForgeLevel + 1
            leveledUp = true

            -- Grant any golem slot unlock at this level
            if nfd.golemSlotUnlock then
                data.GolemSlots = math.max(data.GolemSlots, nfd.golemSlotUnlock)
            end
        else
            break
        end
    end

    if leveledUp then
        local ChallengeService = require(script.Parent.ChallengeService)
        ChallengeService.TrackEvent(player, "ForgeLevelUp", { level = data.ForgeLevel })
        ForgeService.GrantMilestoneBlueprints(player)
        local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
        if RemoteEvents.ForgeUpgraded then RemoteEvents.ForgeUpgraded:FireClient(player, data.ForgeLevel) end
        task.defer(function()
            local ok, ForgeZoneService = pcall(function() return require(script.Parent.ForgeZoneService) end)
            if ok then ForgeZoneService.Refresh(player) end
        end)
    end

    return leveledUp
end

-- Spec 4.3: Tier 2-3 blueprints unlock at forge-level milestones. Safe to call any time
-- (also runs on join so existing saves catch up).
function ForgeService.GrantMilestoneBlueprints(player)
    local data = PlayerDataService.Get(player)
    if not data then return {} end
    local RecipeData = require(game.ReplicatedStorage.Shared.Data.RecipeData)
    local granted = {}
    for bpId, bp in pairs(RecipeData.Blueprints) do
        if bp.source == RecipeData.Source.ForgeMilestone and bp.forgeLevelRequired
            and (data.ForgeLevel or 1) >= bp.forgeLevelRequired
            and not Utils.TableContains(data.Blueprints, bpId) then
            table.insert(data.Blueprints, bpId)
            table.insert(granted, bp)
        end
    end
    if #granted > 0 then
        PlayerDataService.MarkDirty(player)
        local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
        for _, bp in ipairs(granted) do
            if RemoteEvents.Notify then
                RemoteEvents.Notify:FireClient(player, "New blueprint!",
                    string.format("%s Golem (Tier %d) unlocked by your Forge level", bp.element, bp.tier))
            end
        end
    end
    return granted
end

-- ── Smelting ─────────────────────────────────────────────────────────────────
-- Queue a material for smelting; returns job record or nil + error
function ForgeService.StartSmelt(player, materialId, quantity)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end

    local mat = MaterialData.Raw[materialId]
    if not mat then return nil, "Not a smeltable material" end
    if not mat.smeltOutput then return nil, "Material has no smelt output" end
    if mat.smeltTime <= 0 then return nil, "Material smelts instantly" end

    quantity = math.max(1, math.floor(quantity))

    -- Check material availability
    local have = data.Inventory[materialId] or 0
    if have < quantity then return nil, "Insufficient material" end

    -- Check smelt queue capacity
    local userId = tostring(player.UserId)
    smeltJobs[userId] = smeltJobs[userId] or {}
    local forgeLvl = ForgeData.Get(data.ForgeLevel)
    local maxSlots = forgeLvl and forgeLvl.unlocks.smeltSlots or GameConfig.BASE_SMELT_SLOTS
    if #smeltJobs[userId] >= maxSlots then
        return nil, "Smelt queue full"
    end

    -- Consume raw materials
    if not PlayerDataService.RemoveMaterial(player, materialId, quantity) then
        return nil, "Failed to consume material"
    end

    -- Speed bonus: forge level + element mastery (if mat has an element association)
    local speedBonus = forgeLvl and forgeLvl.smeltSpeedBonus or 0
    local masteryXP  = ((data.MasteryLevels or {})[mat.element or ""] or 0)
    local masteryLvl = 0
    local thresholds = GameConfig.MASTERY_XP_THRESHOLDS
    for lvl = #thresholds, 1, -1 do
        if masteryXP >= (thresholds[lvl] or 0) then masteryLvl = lvl; break end
    end
    if masteryLvl >= 15 then speedBonus = math.min(0.55, speedBonus + 0.15) end

    -- The smelter works through SMELT_BATCH_SIZE units per cycle of the material's smelt time
    local cycles   = math.ceil(quantity / GameConfig.SMELT_BATCH_SIZE)
    local duration = math.floor(mat.smeltTime * cycles * (1 - speedBonus))

    local job = {
        id          = Utils.GenerateId(),
        materialId  = materialId,
        quantity    = quantity,
        outputId    = mat.smeltOutput,
        outputQty   = math.floor(quantity / (mat.smeltRatio or 1)),
        startTime   = Utils.UnixTimestamp(),
        endTime     = Utils.UnixTimestamp() + duration,
        duration    = duration,
        completed   = false,
    }

    table.insert(smeltJobs[userId], job)

    -- Store active jobs on player data so they survive server restart
    data.SmeltQueue = data.SmeltQueue or {}
    table.insert(data.SmeltQueue, job)
    PlayerDataService.MarkDirty(player)

    return job, nil
end

-- Deliver a finished job: output, XP, and removal from the persisted queue
local function FinishJob(player, data, job)
    job.completed = true
    PlayerDataService.AddMaterial(player, job.outputId, job.outputQty)

    -- Smelting earns Forge XP and Player XP (spec 6.1)
    ForgeService.AddForgeXP(player, GameConfig.XP_PER_SMELT * job.quantity)
    local ProgressionService = require(script.Parent.ProgressionService)
    local leveled, newLevel = ProgressionService.AddPlayerXP(player, GameConfig.XP_PER_SMELT * job.quantity)
    if leveled then
        local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
        RemoteEvents.LevelUp:FireClient(player, newLevel)
    end

    data.SmeltQueue = data.SmeltQueue or {}
    for j, sq in ipairs(data.SmeltQueue) do
        if sq.id == job.id then
            table.remove(data.SmeltQueue, j)
            break
        end
    end
    PlayerDataService.MarkDirty(player)
end

-- Spend one Speed-Up to finish a smelt job instantly (spec 4.2)
function ForgeService.SpeedUpSmelt(player, jobId)
    local data   = PlayerDataService.Get(player)
    local userId = tostring(player.UserId)
    if not data or not smeltJobs[userId] then return false, "No active jobs" end
    if (data.SpeedUps or 0) < 1 then return false, "You have no Speed-Ups" end

    for i, job in ipairs(smeltJobs[userId]) do
        if job.id == jobId and not job.completed then
            table.remove(smeltJobs[userId], i)
            data.SpeedUps = data.SpeedUps - 1
            FinishJob(player, data, job)
            return true, job
        end
    end
    return false, "Job not found"
end

-- Tick smelt jobs (call each 5s from Main) — awards completed jobs
function ForgeService.TickSmeltJobs(player)
    local userId = tostring(player.UserId)
    local data   = PlayerDataService.Get(player)
    if not data or not smeltJobs[userId] then return {} end

    local now = Utils.UnixTimestamp()
    local completed = {}
    for i = #smeltJobs[userId], 1, -1 do
        local job = smeltJobs[userId][i]
        if not job.completed and now >= job.endTime then
            table.remove(smeltJobs[userId], i)
            FinishJob(player, data, job)
            table.insert(completed, job)
        end
    end
    return completed
end

-- Restore smelt jobs from DataStore on player join
function ForgeService.RestoreSmeltJobs(player)
    local data   = PlayerDataService.Get(player)
    local userId = tostring(player.UserId)
    if not data then return end

    smeltJobs[userId] = {}
    local now = Utils.UnixTimestamp()
    data.SmeltQueue = data.SmeltQueue or {}

    local stillActive = {}
    for _, job in ipairs(data.SmeltQueue) do
        if job.completed then
            -- Already done — award immediately
            PlayerDataService.AddMaterial(player, job.outputId, job.outputQty)
        elseif now >= job.endTime then
            -- Completed while offline
            PlayerDataService.AddMaterial(player, job.outputId, job.outputQty)
        else
            -- Still in progress
            table.insert(smeltJobs[userId], job)
            table.insert(stillActive, job)
        end
    end
    data.SmeltQueue = stillActive
    PlayerDataService.MarkDirty(player)
end

-- Get active smelt jobs for a player (for UI)
function ForgeService.GetSmeltQueue(player)
    local userId = tostring(player.UserId)
    return smeltJobs[userId] or {}
end

-- ── Storage Vault Craft ───────────────────────────────────────────────────────
-- Upgrades StorageTier from 0 → 1 by consuming materials. Tier 2 is Robux-only.
function ForgeService.CraftStorageVault(player)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    if (data.StorageTier or 0) >= 1 then
        return false, "Storage Vault already built"
    end
    if (data.ForgeLevel or 1) < STORAGE_VAULT_RECIPE.forgeLevelRequired then
        return false, "Forge level too low (need Forge " .. STORAGE_VAULT_RECIPE.forgeLevelRequired .. ")"
    end
    if not PlayerDataService.ConsumeMaterials(player, STORAGE_VAULT_RECIPE.materialsRequired) then
        return false, "Insufficient materials"
    end

    data.StorageTier = 1
    PlayerDataService.MarkDirty(player)
    return true, nil
end

function ForgeService.GetStorageVaultRecipe()
    return STORAGE_VAULT_RECIPE
end

-- Clean up on leave
function ForgeService.OnPlayerLeave(player)
    local userId = tostring(player.UserId)
    smeltJobs[userId] = nil
end

return ForgeService
