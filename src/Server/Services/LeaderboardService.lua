-- Global leaderboards using OrderedDataStore.
-- Tracks: total resources mined, Golems crafted, forge level, trade count.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local GameConfig       = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local Utils            = require(game.ReplicatedStorage.Shared.Modules.Utils)

local LeaderboardService = {}

local SafeDataStore = require(script.Parent.SafeDataStore)

-- One OrderedDataStore per category
local stores = {
    ResourcesMined = SafeDataStore.GetOrderedDataStore("EF_LB_Resources_v1"),
    GolemsCrafted  = SafeDataStore.GetOrderedDataStore("EF_LB_Golems_v1"),
    ForgeLevel     = SafeDataStore.GetOrderedDataStore("EF_LB_ForgeLevel_v1"),
    TradeCount     = SafeDataStore.GetOrderedDataStore("EF_LB_Trades_v1"),
}

-- In-memory session counters — flushed to DataStore on leave and periodically
local sessionStats = {}   -- userId → { resourcesMined, golemsCrafted, tradeCount }

local function GetOrCreate(userId)
    if not sessionStats[userId] then
        sessionStats[userId] = { resourcesMined = 0, golemsCrafted = 0, tradeCount = 0 }
    end
    return sessionStats[userId]
end

-- ── Increment helpers called by other services ─────────────────────────────────
function LeaderboardService.OnResourcesGained(player, amount)
    local s = GetOrCreate(tostring(player.UserId))
    s.resourcesMined = s.resourcesMined + amount
end

function LeaderboardService.OnGolemCrafted(player)
    local s = GetOrCreate(tostring(player.UserId))
    s.golemsCrafted = s.golemsCrafted + 1
end

function LeaderboardService.OnTradeComplete(player)
    local s = GetOrCreate(tostring(player.UserId))
    s.tradeCount = s.tradeCount + 1
end

-- ── Flush a player's stats to OrderedDataStore ────────────────────────────────
function LeaderboardService.Flush(player)
    local userId = tostring(player.UserId)
    local s      = sessionStats[userId]
    if not s then return end

    local PlayerDataService = require(script.Parent.PlayerDataService)
    local data = PlayerDataService.Get(player)
    if not data then return end

    -- Atomic increment using UpdateAsync so concurrent servers don't overwrite each other
    local function safeUpdate(store, increment)
        if increment <= 0 then return end
        local ok, err = pcall(function()
            store:UpdateAsync(userId, function(old)
                return (old or 0) + increment
            end)
        end)
        if not ok then
            warn("[LeaderboardService] UpdateAsync failed: " .. tostring(err))
        end
    end

    safeUpdate(stores.ResourcesMined, s.resourcesMined)
    safeUpdate(stores.GolemsCrafted,  s.golemsCrafted)
    safeUpdate(stores.TradeCount,     s.tradeCount)

    -- Forge level is absolute — just set it
    pcall(function()
        stores.ForgeLevel:SetAsync(userId, data.ForgeLevel or 1)
    end)

    sessionStats[userId] = nil
end

-- ── Get top N entries for a category ──────────────────────────────────────────
-- Returns array of { rank, userId, value, displayName }
function LeaderboardService.GetTopEntries(category, count)
    local store = stores[category]
    if not store then return {} end

    count = math.min(count or 10, 100)
    local entries = {}

    local ok, pages = pcall(function()
        return store:GetSortedAsync(false, count)  -- descending
    end)

    if not ok or not pages then return {} end

    local ok2, data = pcall(function()
        return pages:GetCurrentPageAsync()
    end)
    if not ok2 or not data then return {} end

    for rank, entry in ipairs(data) do
        -- Resolve display name (best-effort; may not be online)
        local displayName = "Player"
        local player = Players:GetPlayerByUserId(tonumber(entry.key))
        if player then
            displayName = player.DisplayName or player.Name
        else
            -- Attempt a UserService lookup (async, may fail)
            local ok3, name = pcall(function()
                return game:GetService("UserService"):GetUserInfosByUserIdsAsync({ tonumber(entry.key) })[1].DisplayName
            end)
            if ok3 and name then displayName = name end
        end

        table.insert(entries, {
            rank        = rank,
            userId      = entry.key,
            value       = entry.value,
            displayName = displayName,
        })
    end

    return entries
end

-- ── Periodic background flush ──────────────────────────────────────────────────
function LeaderboardService.StartFlushLoop()
    task.spawn(function()
        while true do
            task.wait(120)  -- flush every 2 minutes
            for _, player in ipairs(Players:GetPlayers()) do
                LeaderboardService.Flush(player)
            end
        end
    end)
end

function LeaderboardService.OnPlayerLeave(player)
    LeaderboardService.Flush(player)
end

return LeaderboardService
