-- The seasonal ranked ladder (see LadderData). Points are everything you mine this ranked season.
--   PlayerData.Ladder = { season, points, claimed = <last season whose prize was claimed> }
-- Each season has its own OrderedDataStore of points by player, so the board is global and a new season starts clean.

local Players       = game:GetService("Players")
local LadderData    = require(game.ReplicatedStorage.Shared.Data.LadderData)
local Utils         = require(game.ReplicatedStorage.Shared.Modules.Utils)
local SafeDataStore = require(script.Parent.SafeDataStore)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LadderService = {}

local pending = {}          -- userId -> points not yet written to the global board

local function Board(season) return SafeDataStore.GetOrderedDataStore("EF_Ladder_v1_" .. season) end
local function Now() return Utils.UnixTimestamp() end

-- Brings a player's ladder record up to the current season. Last season's points stay in `prev` for the prize.
local function Sync(data)
    local season = LadderData.SeasonOf(Now())
    local l = data.Ladder
    if type(l) ~= "table" then l = { season = season, points = 0 } data.Ladder = l end
    if l.season ~= season then
        l.prev = (l.season == season - 1) and { season = l.season, points = l.points or 0 } or nil
        l.season, l.points = season, 0
    end
    return l
end

function LadderService.OnResourcesGained(player, amount)
    local data = PlayerDataService.Get(player)
    if not data or (amount or 0) <= 0 then return end
    local l = Sync(data)
    l.points += amount
    pending[player.UserId] = (pending[player.UserId] or 0) + amount
end

function LadderService.Flush(player)
    local amount = pending[player.UserId]
    local data = PlayerDataService.Get(player)
    if not amount or amount <= 0 or not data then return end
    pending[player.UserId] = nil
    local season = Sync(data).season
    local ok = pcall(function()
        Board(season):UpdateAsync(tostring(player.UserId), function(old) return (old or 0) + amount end)
    end)
    if not ok then pending[player.UserId] = (pending[player.UserId] or 0) + amount end
end

local function RankOf(season, userId)
    local ok, pages = pcall(function() return Board(season):GetSortedAsync(false, 100) end)
    if not ok or not pages then return nil end
    local okPage, page = pcall(function() return pages:GetCurrentPageAsync() end)
    if not okPage or not page then return nil end
    for rank, entry in ipairs(page) do
        if entry.key == tostring(userId) then return rank end
    end
    return nil
end

-- Everything the ladder menu shows
function LadderService.GetInfo(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    LadderService.Flush(player)
    local l = Sync(data)
    local tier = LadderData.TierOf(l.points)
    local nextTier, need = LadderData.NextTier(l.points)
    local info = {
        season = l.season, points = l.points, tier = tier.name, tierColor = tier.color,
        nextTier = nextTier and nextTier.name, pointsToNext = need, endsAt = LadderData.SeasonEnds(Now()),
        rank = RankOf(l.season, player.UserId), top = LadderService.Top(10),
    }
    if l.prev then
        local rank = RankOf(l.prev.season, player.UserId)
        local prize = LadderData.PrizeFor(rank, l.prev.points)
        info.prize = prize and { prize = prize, claimed = l.claimed == l.prev.season, season = l.prev.season, points = l.prev.points, rank = rank } or nil
    end
    return info
end

function LadderService.ClaimPrize(player)
    local data = PlayerDataService.Get(player)
    if not data then return false, "No player data" end
    local l = Sync(data)
    if not l.prev then return false, "There is no ranked prize to claim" end
    if l.claimed == l.prev.season then return false, "You already claimed last season's prize" end
    LadderService.Flush(player)
    local rank = RankOf(l.prev.season, player.UserId)
    local prize = LadderData.PrizeFor(rank, l.prev.points)
    if not prize then return false, "You didn't earn a ranked prize last season" end
    l.claimed = l.prev.season
    data.EmberCoins = (data.EmberCoins or 0) + prize.coins
    data.SpeedUps = (data.SpeedUps or 0) + (prize.speedUps or 0)
    if prize.title then
        data.Titles = data.Titles or {}
        if not Utils.TableContains(data.Titles, prize.title) then table.insert(data.Titles, prize.title) end
    end
    PlayerDataService.MarkDirty(player)
    return true, prize
end

-- The season's top players: { rank, userId, points, name }
function LadderService.Top(count)
    local out = {}
    local season = LadderData.SeasonOf(Now())
    local ok, pages = pcall(function() return Board(season):GetSortedAsync(false, math.min(count or 10, 50)) end)
    if not ok or not pages then return out end
    local okPage, page = pcall(function() return pages:GetCurrentPageAsync() end)
    if not okPage or not page then return out end
    for rank, entry in ipairs(page) do
        local name = "Player"
        local online = Players:GetPlayerByUserId(tonumber(entry.key))
        if online then name = online.DisplayName or online.Name
        else
            local ok3, n = pcall(function() return game:GetService("UserService"):GetUserInfosByUserIdsAsync({ tonumber(entry.key) })[1].DisplayName end)
            if ok3 and n then name = n end
        end
        local tier = LadderData.TierOf(entry.value)
        table.insert(out, { rank = rank, userId = entry.key, points = entry.value, name = name, tier = tier.name })
    end
    return out
end

function LadderService.StartFlushLoop()
    task.spawn(function()
        while true do
            task.wait(60)
            for _, p in ipairs(Players:GetPlayers()) do task.spawn(LadderService.Flush, p) end
        end
    end)
end

function LadderService.OnPlayerLeave(player)
    LadderService.Flush(player)
    pending[player.UserId] = nil
end

return LadderService
