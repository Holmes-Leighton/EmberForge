-- Guilds: create, join, leave, the weekly Guild Challenge and the weekly Guild Leaderboard (spec 7.3).
-- A guild is one DataStore record changed only through UpdateAsync, so several servers can add to it at once.
-- Production is gathered in memory and flushed to the guild every minute and when a player leaves.

local Players     = game:GetService("Players")
local TextService = game:GetService("TextService")

local GuildData         = require(game.ReplicatedStorage.Shared.Data.GuildData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local SafeDataStore     = require(script.Parent.SafeDataStore)
local PlayerDataService = require(script.Parent.PlayerDataService)

local GuildService = {}

local guildStore = SafeDataStore.GetDataStore("EF_Guilds_v1")
local nameStore  = SafeDataStore.GetDataStore("EF_GuildNames_v1")

local pending = {}          -- userId -> resources mined since the last flush
local lastJoinTry = {}      -- userId -> os.clock() of the last create/join attempt (spam guard)

local function GuildKey(id) return "g_" .. id end
local function WeeklyBoard(week) return SafeDataStore.GetOrderedDataStore("EF_GuildWeekly_v1_" .. week) end

local function Now() return Utils.UnixTimestamp() end

-- Roblox requires text that players write to be filtered before anyone else sees it
local function FilterName(player, name)
    local ok, result = pcall(function()
        local filtered = TextService:FilterStringAsync(name, player.UserId)
        return filtered:GetNonChatStringForBroadcastAsync()
    end)
    if ok and type(result) == "string" then return result end
    if ok == false and TextService.FilterStringAsync then return nil end      -- the filter exists but failed: refuse
    return name                                                                -- no filter service (tests / Studio mock)
end

-- Brings a guild up to the current week (weekly numbers and claims reset every week)
local function Rollover(guild)
    local week = GuildData.WeekId(Now())
    if guild.week ~= week then
        guild.week = week
        guild.weekly = 0
        guild.claimed = {}
        for _, m in pairs(guild.members) do m.weekly = 0 end
    end
    return guild
end

local function CountMembers(guild)
    local n = 0
    for _ in pairs(guild.members) do n += 1 end
    return n
end

local function LoadGuild(id)
    local ok, guild = pcall(function() return guildStore:GetAsync(GuildKey(id)) end)
    return ok and guild or nil
end

-- Publishes what a client may see about a guild
local function Snapshot(guild, userId)
    if not guild then return nil end
    Rollover(guild)
    local members = {}
    for uid, m in pairs(guild.members) do
        table.insert(members, { userId = uid, name = m.name, weekly = m.weekly or 0, leader = tostring(guild.leader) == uid })
    end
    table.sort(members, function(a, b) return a.weekly > b.weekly end)
    local count = #members
    local target = GuildData.ChallengeTarget(count)
    local mine = guild.members[tostring(userId)]
    return {
        id = guild.id, name = guild.name, members = members, memberCount = count, maxMembers = GuildData.MAX_MEMBERS,
        weekly = guild.weekly or 0, total = guild.total or 0, target = target,
        complete = (guild.weekly or 0) >= target,
        canClaim = mine ~= nil and (guild.weekly or 0) >= target and (mine.weekly or 0) >= GuildData.MIN_CONTRIBUTION
            and guild.claimed[tostring(userId)] ~= true,
        claimed = guild.claimed[tostring(userId)] == true,
        isLeader = tostring(guild.leader) == tostring(userId),
        reward = GuildData.REWARD, minContribution = GuildData.MIN_CONTRIBUTION,
    }
end

-- ── Create / join / leave ─────────────────────────────────────────────────────
GuildService.ThrottleSeconds = 2          -- minimum gap between create/join attempts per player (tests set it to 0)

local function Throttled(player)
    local now = os.clock()
    if now - (lastJoinTry[player.UserId] or -1e9) < GuildService.ThrottleSeconds then return true end
    lastJoinTry[player.UserId] = now
    return false
end

function GuildService.Create(player, rawName)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end
    if Throttled(player) then return nil, "Slow down a little" end
    if data.GuildId then return nil, "Leave your current guild first" end
    local name, why = GuildData.CleanName(rawName)
    if not name then return nil, why end
    if (data.EmberCoins or 0) < GuildData.CREATE_COST then
        return nil, string.format("Founding a guild costs %d coins (you have %d)", GuildData.CREATE_COST, data.EmberCoins or 0)
    end
    local filtered = FilterName(player, name)
    if not filtered or filtered ~= name then return nil, "That name isn't allowed. Try another." end

    -- claim the name first, atomically, so two servers can't both create it
    local id = Utils.GenerateId()
    local claimed = false
    local ok = pcall(function()
        nameStore:UpdateAsync(GuildData.NameKey(name), function(old)
            if old ~= nil then return nil end
            claimed = true
            return id
        end)
    end)
    if not ok then return nil, "Guilds are unavailable right now. Try again in a minute." end
    if not claimed then return nil, "That guild name is taken" end

    local guild = {
        id = id, name = name, leader = player.UserId, created = Now(), week = GuildData.WeekId(Now()), weekly = 0, total = 0,
        claimed = {}, members = { [tostring(player.UserId)] = { name = player.DisplayName or player.Name, joinedAt = Now(), weekly = 0 } },
    }
    local saved = pcall(function() guildStore:SetAsync(GuildKey(id), guild) end)
    if not saved then
        pcall(function() nameStore:RemoveAsync(GuildData.NameKey(name)) end)
        return nil, "Couldn't save the guild. Try again."
    end
    data.EmberCoins -= GuildData.CREATE_COST
    data.GuildId = id
    PlayerDataService.MarkDirty(player)
    return Snapshot(guild, player.UserId)
end

function GuildService.Join(player, rawName)
    local data = PlayerDataService.Get(player)
    if not data then return nil, "No player data" end
    if Throttled(player) then return nil, "Slow down a little" end
    if data.GuildId then return nil, "Leave your current guild first" end
    local name, why = GuildData.CleanName(rawName)
    if not name then return nil, why end

    local okGet, id = pcall(function() return nameStore:GetAsync(GuildData.NameKey(name)) end)
    if not okGet or not id then return nil, "No guild has that name" end

    local result
    local ok = pcall(function()
        guildStore:UpdateAsync(GuildKey(id), function(guild)
            if type(guild) ~= "table" then result = "That guild no longer exists" return nil end
            Rollover(guild)
            if CountMembers(guild) >= GuildData.MAX_MEMBERS then result = "That guild is full" return nil end
            guild.members[tostring(player.UserId)] = { name = player.DisplayName or player.Name, joinedAt = Now(), weekly = 0 }
            result = guild
            return guild
        end)
    end)
    if not ok then return nil, "Guilds are unavailable right now. Try again in a minute." end
    if type(result) ~= "table" then return nil, result or "Couldn't join that guild" end
    data.GuildId = id
    PlayerDataService.MarkDirty(player)
    return Snapshot(result, player.UserId)
end

function GuildService.Leave(player)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId then return false, "You are not in a guild" end
    GuildService.Flush(player)
    local id = data.GuildId
    local disbandName
    pcall(function()
        guildStore:UpdateAsync(GuildKey(id), function(guild)
            if type(guild) ~= "table" then return nil end
            guild.members[tostring(player.UserId)] = nil
            if next(guild.members) == nil then
                disbandName = guild.name
                return nil                                   -- (the record is removed below)
            end
            if tostring(guild.leader) == tostring(player.UserId) then       -- hand leadership to the longest-standing member
                local bestId, bestAt
                for uid, m in pairs(guild.members) do
                    if not bestAt or (m.joinedAt or 0) < bestAt then bestId, bestAt = uid, m.joinedAt or 0 end
                end
                guild.leader = tonumber(bestId) or bestId
            end
            return guild
        end)
        if disbandName then
            guildStore:RemoveAsync(GuildKey(id))
            nameStore:RemoveAsync(GuildData.NameKey(disbandName))
        end
    end)
    data.GuildId = nil
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Production and the weekly challenge ───────────────────────────────────────
function GuildService.OnResourcesGained(player, amount)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId or (amount or 0) <= 0 then return end
    pending[player.UserId] = (pending[player.UserId] or 0) + amount
end

function GuildService.Flush(player)
    local amount = pending[player.UserId]
    local data = PlayerDataService.Get(player)
    if not amount or amount <= 0 or not data or not data.GuildId then return end
    pending[player.UserId] = nil
    local id = data.GuildId
    local week, credited
    local ok = pcall(function()
        guildStore:UpdateAsync(GuildKey(id), function(guild)
            if type(guild) ~= "table" then return nil end
            local m = guild.members[tostring(player.UserId)]
            if not m then return nil end
            Rollover(guild)
            m.weekly = (m.weekly or 0) + amount
            guild.weekly = (guild.weekly or 0) + amount
            guild.total = (guild.total or 0) + amount
            week, credited = guild.week, true
            return guild
        end)
    end)
    if not ok then pending[player.UserId] = (pending[player.UserId] or 0) + amount return end   -- try again next flush
    if credited then
        pcall(function() WeeklyBoard(week):UpdateAsync(id, function(old) return (old or 0) + amount end) end)
    else
        data.GuildId = nil                                   -- the guild is gone or we were removed from it
        PlayerDataService.MarkDirty(player)
    end
end

function GuildService.ClaimReward(player)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId then return false, "You are not in a guild" end
    GuildService.Flush(player)
    local ok, err
    local granted = false
    local pok = pcall(function()
        guildStore:UpdateAsync(GuildKey(data.GuildId), function(guild)
            if type(guild) ~= "table" then err = "Your guild no longer exists" return nil end
            Rollover(guild)
            local snap = Snapshot(guild, player.UserId)
            if not snap.complete then err = "The challenge isn't complete yet" return nil end
            if snap.claimed then err = "You already claimed this week's reward" return nil end
            if not snap.canClaim then err = string.format("Add at least %d resources to share in the reward", GuildData.MIN_CONTRIBUTION) return nil end
            guild.claimed[tostring(player.UserId)] = true
            granted = true
            return guild
        end)
    end)
    if not pok then return false, "Guilds are unavailable right now. Try again in a minute." end
    if not granted then return false, err or "Nothing to claim" end
    data.EmberCoins = (data.EmberCoins or 0) + GuildData.REWARD.coins
    data.SpeedUps = (data.SpeedUps or 0) + GuildData.REWARD.speedUps
    PlayerDataService.MarkDirty(player)
    return true, GuildData.REWARD
end

-- ── Reading ───────────────────────────────────────────────────────────────────
function GuildService.GetMine(player)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId then return nil end
    GuildService.Flush(player)
    local guild = LoadGuild(data.GuildId)
    if not guild or not guild.members[tostring(player.UserId)] then
        data.GuildId = nil                                   -- disbanded, or removed
        PlayerDataService.MarkDirty(player)
        return nil
    end
    return Snapshot(guild, player.UserId)
end

-- The week's top guilds by combined production: { rank, name, weekly, members }
function GuildService.Top(count)
    local week = GuildData.WeekId(Now())
    local out = {}
    local ok, pages = pcall(function() return WeeklyBoard(week):GetSortedAsync(false, math.min(count or 10, 50)) end)
    if not ok or not pages then return out end
    local okPage, page = pcall(function() return pages:GetCurrentPageAsync() end)
    if not okPage or not page then return out end
    for rank, entry in ipairs(page) do
        local guild = LoadGuild(entry.key)
        if guild then
            table.insert(out, { rank = rank, name = guild.name, weekly = entry.value, members = CountMembers(guild) })
        end
    end
    return out
end

function GuildService.StartFlushLoop()
    task.spawn(function()
        while true do
            task.wait(60)
            for _, player in ipairs(Players:GetPlayers()) do task.spawn(GuildService.Flush, player) end
        end
    end)
end

function GuildService.OnPlayerLeave(player)
    GuildService.Flush(player)
    pending[player.UserId] = nil
    lastJoinTry[player.UserId] = nil
end

return GuildService
