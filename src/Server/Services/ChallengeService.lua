-- Tracks challenge progress, handles daily/weekly resets, awards rewards.

local ChallengeData     = require(game.ReplicatedStorage.Shared.Data.ChallengeData)
local GameConfig        = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ChallengeService = {}

-- Seconds in a day and week
local DAY_SECONDS  = 86400
local WEEK_SECONDS = 604800

-- ── Reset checks ─────────────────────────────────────────────────────────────
local function ShouldResetDaily(data)
    local now  = Utils.UnixTimestamp()
    local last = data.LastDailyReset or 0
    return (now - last) >= DAY_SECONDS
end

local function ShouldResetWeekly(data)
    local now  = Utils.UnixTimestamp()
    local last = data.LastWeeklyReset or 0
    return (now - last) >= WEEK_SECONDS
end

-- Select 3 random daily challenges for the player
local function PickDailyChallenges()
    local pool = {}
    for _, c in ipairs(ChallengeData.Daily) do
        table.insert(pool, c.id)
    end
    -- Fisher-Yates shuffle
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local picks = {}
    for i = 1, math.min(3, #pool) do
        picks[pool[i]] = { progress = 0, claimed = false }
    end
    return picks
end

-- Select 3 random weekly challenges
local function PickWeeklyChallenges()
    local pool = {}
    for _, c in ipairs(ChallengeData.Weekly) do
        table.insert(pool, c.id)
    end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local picks = {}
    for i = 1, math.min(3, #pool) do
        picks[pool[i]] = { progress = 0, claimed = false }
    end
    return picks
end

-- ── Initialise / reset on login ──────────────────────────────────────────────
-- Returns { daily = bool, weekly = bool } so callers can fire client events.
function ChallengeService.CheckResets(player)
    local data = PlayerDataService.Get(player)
    if not data then return { daily = false, weekly = false } end

    local resets = { daily = false, weekly = false }

    if ShouldResetDaily(data) then
        data.DailyChallenges = PickDailyChallenges()
        data.LastDailyReset  = Utils.UnixTimestamp()
        data.EmberCoins      = (data.EmberCoins or 0) + GameConfig.DAILY_COIN_REWARD
        PlayerDataService.MarkDirty(player)
        resets.daily = true
    end

    if ShouldResetWeekly(data) then
        data.WeeklyChallenges = PickWeeklyChallenges()
        data.LastWeeklyReset  = Utils.UnixTimestamp()
        PlayerDataService.MarkDirty(player)
        resets.weekly = true
    end

    return resets
end

-- ── Event tracking ────────────────────────────────────────────────────────────
-- Call this whenever a game event occurs; updates all matching challenges.
-- Returns array of newly completed challenge ids.
function ChallengeService.TrackEvent(player, eventName, eventData)
    local data = PlayerDataService.Get(player)
    if not data then return {} end

    local completed = {}

    local function tryProgress(challengeMap, challengeList)
        for _, challengeDef in ipairs(challengeList) do
            if challengeMap[challengeDef.id] and not challengeMap[challengeDef.id].claimed then
                local entry = challengeMap[challengeDef.id]
                if challengeDef.trackEvent == eventName then
                    -- Check filter conditions
                    local passes = true
                    if challengeDef.trackFilter then
                        local f = challengeDef.trackFilter
                        if f.minTier and (not eventData or (eventData.tier or 0) < f.minTier) then
                            passes = false
                        end
                        if f.minLevel and (not eventData or (eventData.level or 0) < f.minLevel) then
                            passes = false
                        end
                    end

                    if passes then
                        local increment = (eventData and eventData.count) or 1
                        entry.progress = (entry.progress or 0) + increment
                        if entry.progress >= challengeDef.target then
                            entry.progress = challengeDef.target  -- cap
                            table.insert(completed, challengeDef.id)
                        end
                    end
                end
            end
        end
    end

    tryProgress(data.DailyChallenges or {},  ChallengeData.Daily)
    tryProgress(data.WeeklyChallenges or {}, ChallengeData.Weekly)

    -- Lifetime achievements (separate tracking, no reset)
    for _, ach in ipairs(ChallengeData.Lifetime) do
        if not Utils.TableContains(data.Achievements, ach.id) then
            if not data._achievementProgress then data._achievementProgress = {} end
            if ach.trackEvent == eventName then
                local passes = true
                if ach.trackFilter then
                    local f = ach.trackFilter
                    if f.minTier and (not eventData or (eventData.tier or 0) < f.minTier) then
                        passes = false
                    end
                    if f.minLevel and (not eventData or (eventData.level or 0) < f.minLevel) then
                        passes = false
                    end
                end
                if passes then
                    local increment = (eventData and eventData.count) or 1
                    data._achievementProgress[ach.id] = (data._achievementProgress[ach.id] or 0) + increment
                    if data._achievementProgress[ach.id] >= ach.target then
                        table.insert(data.Achievements, ach.id)
                        table.insert(completed, ach.id)
                    end
                end
            end
        end
    end

    if #completed > 0 then
        PlayerDataService.MarkDirty(player)
    end
    return completed
end

-- ── Claim reward ──────────────────────────────────────────────────────────────
function ChallengeService.ClaimReward(player, challengeId)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local challengeDef = ChallengeData.Get(challengeId)
    if not challengeDef then return false, "Unknown challenge" end

    -- Find the progress entry
    local entry
    if challengeDef.type == ChallengeData.Type.Daily then
        entry = (data.DailyChallenges or {})[challengeId]
    elseif challengeDef.type == ChallengeData.Type.Weekly then
        entry = (data.WeeklyChallenges or {})[challengeId]
    elseif challengeDef.type == ChallengeData.Type.Lifetime then
        -- Lifetime reward is auto-claimed on completion
        entry = Utils.TableContains(data.Achievements, challengeId) and { progress = 1, claimed = false } or nil
    end

    if not entry then return false, "Challenge not active" end
    if entry.claimed then return false, "Already claimed" end
    if entry.progress < challengeDef.target then return false, "Challenge not complete" end

    -- Award rewards
    local rewards = challengeDef.rewards or {}
    if rewards.coins then
        data.EmberCoins = (data.EmberCoins or 0) + rewards.coins
    end
    if rewards.xp then
        local ProgressionService = require(script.Parent.ProgressionService)
        ProgressionService.AddPlayerXP(player, rewards.xp)
    end
    if rewards.materials then
        for _, mat in ipairs(rewards.materials) do
            data.Inventory[mat.id] = (data.Inventory[mat.id] or 0) + mat.qty
        end
    end
    if rewards.blueprints then
        for _, bpId in ipairs(rewards.blueprints) do
            if not Utils.TableContains(data.Blueprints, bpId) then
                table.insert(data.Blueprints, bpId)
            end
        end
    end
    if rewards.title then
        data.Titles = data.Titles or {}
        if not Utils.TableContains(data.Titles, rewards.title) then
            table.insert(data.Titles, rewards.title)
        end
    end
    if rewards.accessories then
        data.OwnedAccessories = data.OwnedAccessories or {}
        for _, accId in ipairs(rewards.accessories) do
            if not Utils.TableContains(data.OwnedAccessories, accId) then
                table.insert(data.OwnedAccessories, accId)
            end
        end
    end

    entry.claimed = true
    PlayerDataService.MarkDirty(player)

    return true, rewards
end

return ChallengeService
