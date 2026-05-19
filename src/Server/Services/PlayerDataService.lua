-- Handles all DataStore reads, writes, and the backup DataStore pattern.
-- All player data mutations go through this service.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig   = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local RecipeData   = require(game.ReplicatedStorage.Shared.Data.RecipeData)
local Utils        = require(game.ReplicatedStorage.Shared.Modules.Utils)

local PlayerDataService = {}

-- DataStore instances
local primaryStore = DataStoreService:GetDataStore("EmberForge_v1")
local backupStore  = DataStoreService:GetDataStore("EmberForge_v1_backup")

-- In-memory cache: userId → { data, dirty }
local cache = {}

-- ── Default data schema ─────────────────────────────────────────────────────
local function DefaultData()
    return {
        PlayerLevel     = 1,
        PlayerXP        = 0,
        ForgeLevel      = 1,
        ForgeXP         = 0,
        Golems          = {},          -- array of GolemObjects
        Inventory       = {},          -- materialId → quantity
        Blueprints      = Utils.DeepCopy(RecipeData.StartingBlueprintIds),
        LastOnline      = Utils.UnixTimestamp(),
        MasteryLevels   = {            -- elementId → xp
            Ember = 0, Stone = 0, Frost = 0, Storm = 0, Void = 0,
        },
        SeasonPassTier  = 0,
        SeasonProgress  = {},          -- seasonId → { claimedWeeks }
        Achievements    = {},
        DailyChallenges  = {},         -- challengeId → { progress, claimed } (resets daily)
        WeeklyChallenges = {},         -- challengeId → { progress, claimed } (resets weekly)
        LastDailyReset  = 0,
        LastWeeklyReset = 0,
        GolemSlots      = GameConfig.BASE_GOLEM_SLOTS,
        StorageTier     = 0,           -- 0=base, 1=upgraded, 2=premium
        EmberCoins      = GameConfig.STARTING_COINS,
        GuildId         = nil,
        Settings        = {},
        -- Forge
        SmeltQueue      = {},          -- persisted smelt jobs
        -- Purchases / boosts
        SpeedUps             = 0,
        TempSlotBoostExpiry  = 0,
        MaterialMagnetExpiry = 0,
        -- Cosmetics & receipts
        OwnedCosmetics    = {},
        OwnedAccessories  = {},
        Titles            = {},
        ProcessedReceipts = {},
        -- Achievement progress tracking (non-resettable counters)
        _achievementProgress = {},
    }
end

-- ── Load ────────────────────────────────────────────────────────────────────
function PlayerDataService.Load(player)
    local userId = tostring(player.UserId)
    local key    = GameConfig.DATASTORE_KEY_PREFIX .. userId

    local data
    local ok, err = pcall(function()
        data = primaryStore:GetAsync(key)
    end)

    if not ok then
        warn("[PlayerDataService] Primary load failed for " .. userId .. ": " .. tostring(err))
        -- Try backup
        local backupOk, _ = pcall(function()
            data = backupStore:GetAsync(key)
        end)
        if not backupOk then
            warn("[PlayerDataService] Backup load also failed — using default data")
        end
    end

    if not data or not Utils.ValidatePlayerData(data) then
        data = DefaultData()
    else
        -- Migrate any missing fields forward
        local defaults = DefaultData()
        for field, default in pairs(defaults) do
            if data[field] == nil then
                data[field] = Utils.DeepCopy(default)
            end
        end
    end

    cache[userId] = { data = data, dirty = false }
    return data
end

-- ── Get (from cache) ────────────────────────────────────────────────────────
function PlayerDataService.Get(player)
    local userId = tostring(player.UserId)
    local entry = cache[userId]
    if entry then return entry.data end
    return nil
end

-- ── Mark dirty (schedule save) ──────────────────────────────────────────────
function PlayerDataService.MarkDirty(player)
    local userId = tostring(player.UserId)
    if cache[userId] then
        cache[userId].dirty = true
    end
end

-- ── Save ────────────────────────────────────────────────────────────────────
function PlayerDataService.Save(player, force)
    local userId = tostring(player.UserId)
    local entry  = cache[userId]
    if not entry then return end
    if not force and not entry.dirty then return end

    local key  = GameConfig.DATASTORE_KEY_PREFIX .. userId
    local data = entry.data

    -- Update timestamp
    data.LastOnline = Utils.UnixTimestamp()

    local ok, err = pcall(function()
        primaryStore:SetAsync(key, data)
    end)

    if ok then
        -- Mirror to backup on every successful primary write
        pcall(function()
            backupStore:SetAsync(key, data)
        end)
        entry.dirty = false
    else
        warn("[PlayerDataService] Save failed for " .. userId .. ": " .. tostring(err))
    end
end

-- ── Mutate helpers ──────────────────────────────────────────────────────────
function PlayerDataService.AddMaterial(player, materialId, qty)
    local data = PlayerDataService.Get(player)
    if not data then return end
    data.Inventory[materialId] = (data.Inventory[materialId] or 0) + qty
    PlayerDataService.MarkDirty(player)
end

function PlayerDataService.RemoveMaterial(player, materialId, qty)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    local have = data.Inventory[materialId] or 0
    if have < qty then return false end
    data.Inventory[materialId] = have - qty
    if data.Inventory[materialId] <= 0 then
        data.Inventory[materialId] = nil
    end
    PlayerDataService.MarkDirty(player)
    return true
end

function PlayerDataService.HasMaterials(player, requirements)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    for _, req in ipairs(requirements) do
        local have = data.Inventory[req.id] or 0
        if have < req.qty then return false end
    end
    return true
end

function PlayerDataService.ConsumeMaterials(player, requirements)
    if not PlayerDataService.HasMaterials(player, requirements) then
        return false
    end
    for _, req in ipairs(requirements) do
        PlayerDataService.RemoveMaterial(player, req.id, req.qty)
    end
    return true
end

function PlayerDataService.UnlockBlueprint(player, blueprintId)
    local data = PlayerDataService.Get(player)
    if not data then return false end
    if Utils.TableContains(data.Blueprints, blueprintId) then return false end
    table.insert(data.Blueprints, blueprintId)
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Periodic auto-save loop ─────────────────────────────────────────────────
function PlayerDataService.StartAutoSave()
    task.spawn(function()
        while true do
            task.wait(GameConfig.DATASTORE_SAVE_INTERVAL)
            for userId, entry in pairs(cache) do
                if entry.dirty then
                    local player = Players:GetPlayerByUserId(tonumber(userId))
                    if player then
                        PlayerDataService.Save(player)
                    end
                end
            end
        end
    end)
end

-- ── Credit coins to a player who may be offline ────────────────────────────
-- Used by market sale proceeds when the seller has already disconnected.
function PlayerDataService.CreditOfflineCoins(userId, amount)
    local entry = cache[tostring(userId)]
    if entry then
        entry.data.EmberCoins = (entry.data.EmberCoins or 0) + amount
        entry.dirty = true
        return
    end
    local key = GameConfig.DATASTORE_KEY_PREFIX .. tostring(userId)
    pcall(function()
        primaryStore:UpdateAsync(key, function(existing)
            if type(existing) == "table" then
                existing.EmberCoins = (existing.EmberCoins or 0) + amount
                return existing
            end
        end)
    end)
end

-- ── On player leave: force save and evict cache ─────────────────────────────
function PlayerDataService.OnPlayerLeave(player)
    PlayerDataService.Save(player, true)
    local userId = tostring(player.UserId)
    cache[userId] = nil
end

return PlayerDataService
