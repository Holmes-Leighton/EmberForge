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
local SafeDataStore = require(script.Parent.SafeDataStore)
local primaryStore = SafeDataStore.GetDataStore("EmberForge_v1")
local backupStore  = SafeDataStore.GetDataStore("EmberForge_v1_backup")
local creditStore  = SafeDataStore.GetDataStore("EmberForge_Credits_v1")   -- coins owed to players who weren't here

-- Session locking: a record is "owned" by one server (game.JobId) at a time so two servers
-- can never overwrite each other. A lock older than LOCK_TIMEOUT is assumed dead (crashed server).
local JOB_ID       = (game.JobId ~= "" and game.JobId) or "studio"
local LOCK_TIMEOUT = 900

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
        Pending         = {},          -- materialId → quantity mined by Golems, waiting to be collected
        Blueprints      = Utils.DeepCopy(RecipeData.StartingBlueprintIds),
        LastOnline      = Utils.UnixTimestamp(),
        MasteryLevels   = {            -- elementId → xp
            Ember = 0, Stone = 0, Frost = 0, Storm = 0, Void = 0,
        },
        SeasonPassTier  = 0,
        SeasonProgress  = {},          -- seasonId → { claimedWeeks }
        Achievements    = {},
        ClaimedAchievements = {},      -- achievementId → true once its reward is taken
        TradeHistory    = {},          -- last trades, newest first
        SeenCosmetics   = {},          -- cosmetics/titles the player has already looked at
        SupplierPurchases = { day = 0, bought = {} },
        Funnel          = {},          -- onboarding steps already logged to analytics
        Equipped        = {},          -- slot → cosmetic id (Title is stored as its text)
        CraftedByTier   = {},          -- tier → how many Golems of that tier were ever crafted
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

-- ── Locking helpers ─────────────────────────────────────────────────────────
local function LockedByOther(record)
    local lock = type(record) == "table" and record._lock or nil
    if type(lock) ~= "table" then return false end
    return lock.jobId ~= JOB_ID and (Utils.UnixTimestamp() - (lock.time or 0)) < LOCK_TIMEOUT
end

-- Claims the record for this server and returns it. Returns nil, reason on failure.
local function AcquireRecord(key)
    local lastReason = "unavailable"
    for attempt = 1, 5 do
        local acquired = false
        local record
        local ok, err = pcall(function()
            record = primaryStore:UpdateAsync(key, function(old)
                if LockedByOther(old) then return nil end          -- another server has it: don't write
                acquired = true
                old = type(old) == "table" and old or {}
                old._lock = { jobId = JOB_ID, time = Utils.UnixTimestamp() }
                return old
            end)
        end)
        if ok and acquired then return record or {} end
        lastReason = ok and "locked" or tostring(err)
        task.wait(attempt < 3 and 2 or 4)
    end
    return nil, lastReason
end

-- ── Load ────────────────────────────────────────────────────────────────────
-- Returns the player's data, or nil + reason if it could not be loaded *safely*.
-- (We never fall back to fresh data when a real record might exist: saving that would erase progress.)
function PlayerDataService.Load(player)
    local userId = tostring(player.UserId)
    local key    = GameConfig.DATASTORE_KEY_PREFIX .. userId

    local data, reason = AcquireRecord(key)
    if not data then
        warn("[PlayerDataService] Could not load " .. userId .. ": " .. tostring(reason))
        return nil, reason
    end

    if not Utils.ValidatePlayerData(data) then
        if next(data) ~= nil and data.PlayerLevel ~= nil then
            -- a record exists but failed validation: try the backup before starting over
            local okB, backup = pcall(function() return backupStore:GetAsync(key) end)
            if okB and Utils.ValidatePlayerData(backup) then data = backup end
        end
        if not Utils.ValidatePlayerData(data) then
            data = DefaultData()
        end
    else
        -- Migrate any missing fields forward
        local defaults = DefaultData()
        for field, default in pairs(defaults) do
            if data[field] == nil then
                data[field] = Utils.DeepCopy(default)
            end
        end
    end
    -- Older saves: rebuild the crafted-per-tier counters from the Golems they own
    if next(data.CraftedByTier or {}) == nil then
        data.CraftedByTier = {}
        for _, g in ipairs(data.Golems or {}) do
            data.CraftedByTier[g.tier] = (data.CraftedByTier[g.tier] or 0) + 1
        end
    end
    data._lock = { jobId = JOB_ID, time = Utils.UnixTimestamp() }

    cache[userId] = { data = data, dirty = true }
    PlayerDataService.ApplyCredits(player)
    return data
end

-- Coins owed while the player was away (market sales handled by another server)
function PlayerDataService.ApplyCredits(player)
    local userId = tostring(player.UserId)
    local entry = cache[userId]
    if not entry then return end
    local taken = 0
    local ok = pcall(function()
        creditStore:UpdateAsync(GameConfig.DATASTORE_KEY_PREFIX .. userId, function(old)
            taken = tonumber(old) or 0
            if taken == 0 then return nil end
            return 0
        end)
    end)
    if ok and taken > 0 then
        entry.data.EmberCoins = (entry.data.EmberCoins or 0) + taken
        entry.dirty = true
        local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
        if RemoteEvents.Notify then
            RemoteEvents.Notify:FireClient(player, "Market sales", "You earned " .. taken .. " Ember Coins while away.")
        end
    end
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
-- `release` clears our session lock (used when the player leaves).
function PlayerDataService.Save(player, force, release)
    local userId = tostring(player.UserId)
    local entry  = cache[userId]
    if not entry then return false end
    if not force and not entry.dirty then return true end

    local key  = GameConfig.DATASTORE_KEY_PREFIX .. userId
    local data = entry.data
    data.LastOnline = Utils.UnixTimestamp()

    local wrote = false
    local ok, err = pcall(function()
        primaryStore:UpdateAsync(key, function(old)
            if LockedByOther(old) then return nil end   -- we lost the lock: refuse to overwrite the other server
            data._lock = (not release) and { jobId = JOB_ID, time = Utils.UnixTimestamp() } or nil
            wrote = true
            return data
        end)
    end)

    if ok and wrote then
        pcall(function() backupStore:SetAsync(key, data) end)   -- mirror to backup
        entry.dirty = false
        return true
    end
    warn("[PlayerDataService] Save failed for " .. userId .. ": " .. tostring(ok and "record locked by another server" or err))
    return false
end

-- ── Mutate helpers ──────────────────────────────────────────────────────────
function PlayerDataService.AddMaterial(player, materialId, qty)
    local data = PlayerDataService.Get(player)
    if not data then return end
    data.Inventory[materialId] = (data.Inventory[materialId] or 0) + qty
    PlayerDataService.MarkDirty(player)
end

function PlayerDataService.AddPending(player, materialId, qty)
    local data = PlayerDataService.Get(player)
    if not data then return end
    data.Pending = data.Pending or {}
    data.Pending[materialId] = (data.Pending[materialId] or 0) + qty
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
                local player = Players:GetPlayerByUserId(tonumber(userId))
                if player then
                    PlayerDataService.ApplyCredits(player)
                    PlayerDataService.Save(player, true)   -- also refreshes our session lock
                end
            end
        end
    end)

    -- Make sure everyone is saved (and unlocked) when the server shuts down
    game:BindToClose(function()
        for userId in pairs(cache) do
            local player = Players:GetPlayerByUserId(tonumber(userId))
            if player then PlayerDataService.Save(player, true, true) end
        end
    end)
end

-- ── Credit coins to a player who may be on another server ──────────────────
function PlayerDataService.CreditOfflineCoins(userId, amount)
    local entry = cache[tostring(userId)]
    if entry then
        entry.data.EmberCoins = (entry.data.EmberCoins or 0) + amount
        entry.dirty = true
        return
    end
    pcall(function()
        creditStore:UpdateAsync(GameConfig.DATASTORE_KEY_PREFIX .. tostring(userId), function(old)
            return (tonumber(old) or 0) + amount
        end)
    end)
end

-- ── On player leave: force save, release the session lock, evict cache ───────
function PlayerDataService.OnPlayerLeave(player)
    PlayerDataService.Save(player, true, true)
    cache[tostring(player.UserId)] = nil
end

return PlayerDataService
