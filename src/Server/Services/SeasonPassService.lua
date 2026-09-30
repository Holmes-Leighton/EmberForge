-- Manages season pass reward claiming and seasonal event progression.

local DataStoreService  = game:GetService("DataStoreService")
local SeasonData        = require(game.ReplicatedStorage.Shared.Data.SeasonData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SeasonPassService = {}

local SafeDataStore = require(script.Parent.SafeDataStore)
local communityStore = SafeDataStore.GetDataStore("EmberForge_Community_v1")

-- Returns which week of the current season the player is on
local function CurrentSeasonWeek()
    local season     = SeasonData.GetCurrentSeason()
    local seasonStart = season.startTimestamp or 0  -- set in live config
    local elapsed    = Utils.UnixTimestamp() - seasonStart
    local week       = math.floor(elapsed / (7 * 86400)) + 1
    return math.min(week, season.durationWeeks)
end

-- ── Claim a week's reward ─────────────────────────────────────────────────────
function SeasonPassService.ClaimWeekReward(player, seasonId, weekNumber, track)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end

    local season = SeasonData.Get(seasonId)
    if not season then return false, "Unknown season" end

    -- Verify week is available
    local currentWeek = CurrentSeasonWeek()
    if weekNumber > currentWeek then return false, "Week not yet available" end

    -- Check pass tier authorises this track
    local passTier = data.SeasonPassTier or 0
    if track == "premium" and passTier < SeasonData.PassTier.Premium then
        return false, "Premium pass required"
    end
    if track == "standard" and passTier < SeasonData.PassTier.Standard then
        return false, "Standard pass required"
    end

    -- Check if already claimed
    data.SeasonProgress = data.SeasonProgress or {}
    data.SeasonProgress[seasonId] = data.SeasonProgress[seasonId] or { claimedWeeks = {} }
    local progress = data.SeasonProgress[seasonId]

    local claimKey = track .. "_" .. weekNumber
    if progress.claimedWeeks[claimKey] then
        return false, "Already claimed"
    end

    -- Find and apply reward
    local rewardList
    if track == "premium" then
        rewardList = season.premiumTrackRewards
    elseif track == "standard" then
        rewardList = season.standardTrackRewards
    else
        rewardList = season.freeTrackRewards
    end

    local reward
    for _, entry in ipairs(rewardList) do
        if entry.week == weekNumber then
            reward = entry.reward
            break
        end
    end
    if not reward then return false, "No reward for this week" end

    -- Apply reward
    SeasonPassService._ApplyReward(player, data, reward)

    progress.claimedWeeks[claimKey] = true
    PlayerDataService.MarkDirty(player)

    return true, reward
end

function SeasonPassService._ApplyReward(player, data, reward)
    if reward.type == "material" then
        data.Inventory[reward.id] = (data.Inventory[reward.id] or 0) + (reward.qty or 1)

    elseif reward.type == "coins" then
        data.EmberCoins = (data.EmberCoins or 0) + reward.qty

    elseif reward.type == "speedup" then
        data.SpeedUps = (data.SpeedUps or 0) + (reward.qty or 1)

    elseif reward.type == "cosmetic" then
        data.OwnedCosmetics = data.OwnedCosmetics or {}
        if not Utils.TableContains(data.OwnedCosmetics, reward.id) then
            table.insert(data.OwnedCosmetics, reward.id)
        end

    elseif reward.type == "storageSlot" then
        data.StorageTier = math.min(2, (data.StorageTier or 0) + 1)
    end
end

-- ── Community milestone tracking ──────────────────────────────────────────────
-- In-memory cache; backed to DataStore via UpdateAsync so cross-server progress persists.
local communityProgress = {}

-- Load all season progress from DataStore on server start
task.spawn(function()
    for id in pairs(SeasonData.Seasons) do
        local ok, val = pcall(function()
            return communityStore:GetAsync("progress_" .. id)
        end)
        if ok and type(val) == "number" then
            communityProgress[id] = val
        end
    end
end)

function SeasonPassService.ContributeToCommunity(seasonId, amount)
    communityProgress[seasonId] = (communityProgress[seasonId] or 0) + amount
    -- Persist atomically so all servers converge on the same total
    task.spawn(function()
        local ok, newTotal = pcall(function()
            return communityStore:UpdateAsync("progress_" .. seasonId, function(existing)
                return (type(existing) == "number" and existing or 0) + amount
            end)
        end)
        if ok and type(newTotal) == "number" then
            communityProgress[seasonId] = newTotal
        end
    end)
end

function SeasonPassService.GetCommunityProgress(seasonId)
    local season = SeasonData.Get(seasonId)
    if not season then return 0, 0 end
    local current = communityProgress[seasonId] or 0
    local target  = (season.communityMilestone and season.communityMilestone.target) or 0
    return current, target
end

function SeasonPassService.IsCommunityMilestoneMet(seasonId)
    local current, target = SeasonPassService.GetCommunityProgress(seasonId)
    return target > 0 and current >= target
end

-- ── Event material drop rate multiplier ───────────────────────────────────────
function SeasonPassService.GetEventDropMultiplier(seasonId)
    seasonId = seasonId or (SeasonData.GetCurrentSeason() and SeasonData.GetCurrentSeason().id)
    if SeasonPassService.IsCommunityMilestoneMet(seasonId) then
        local season = SeasonData.Get(seasonId)
        if season and season.communityMilestone then
            return season.communityMilestone.reward.multiplier or 1.0
        end
    end
    return 1.0
end

-- ── Player season summary (for UI) ────────────────────────────────────────────
function SeasonPassService.GetPlayerSeasonStatus(player)
    local data   = PlayerDataService.Get(player)
    if not data then return nil end

    local season = SeasonData.GetCurrentSeason()
    local progress = (data.SeasonProgress or {})[season.id] or { claimedWeeks = {} }

    return {
        seasonId    = season.id,
        seasonName  = season.displayName,
        passTier    = data.SeasonPassTier or 0,
        currentWeek = CurrentSeasonWeek(),
        totalWeeks  = season.durationWeeks,
        claimedWeeks = progress.claimedWeeks,
        communityProgress = SeasonPassService.GetCommunityProgress(season.id),
    }
end

return SeasonPassService
