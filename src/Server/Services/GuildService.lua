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
local chatStore  = SafeDataStore.GetDataStore("EF_GuildChat_v1")

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
        -- keep last week's numbers for the battle prize, but only if it really was last week
        local wasLast = guild.week == week - 1
        guild.last = wasLast and { week = guild.week, weekly = guild.weekly or 0 } or nil
        guild.week = week
        guild.weekly = 0
        guild.claimed = {}
        for _, m in pairs(guild.members) do
            m.lastWeekly = wasLast and (m.weekly or 0) or 0
            m.weekly = 0
        end
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
        level = GuildData.LevelOf(guild.total or 0), levelBonus = GuildData.LevelBonus(GuildData.LevelOf(guild.total or 0)),
        nextLevelTotal = select(2, GuildData.NextLevel(guild.total or 0)),
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
    data.GuildLevel = 0
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
    data.GuildLevel = GuildData.LevelOf(result.total or 0)
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
            pcall(function() chatStore:RemoveAsync("c_" .. id) end)
        end
    end)
    data.GuildLevel = 0
    data.GuildId = nil
    PlayerDataService.MarkDirty(player)
    return true
end

-- ── Leader tools ──────────────────────────────────────────────────────────────
-- Only the leader may use these. The removed player finds out the next time their guild is read (GetMine/Flush
-- notice they are no longer a member and clear their GuildId), so this works even if they are on another server.
function GuildService.Kick(leader, targetUserId)
    local data = PlayerDataService.Get(leader)
    if not data or not data.GuildId then return false, "You are not in a guild" end
    local target = tostring(targetUserId)
    if target == tostring(leader.UserId) then return false, "Use Leave to leave your own guild" end
    local err, kicked
    local ok = pcall(function()
        guildStore:UpdateAsync(GuildKey(data.GuildId), function(guild)
            if type(guild) ~= "table" then err = "Your guild no longer exists" return nil end
            if tostring(guild.leader) ~= tostring(leader.UserId) then err = "Only the guild leader can do that" return nil end
            if not guild.members[target] then err = "That player isn't in your guild" return nil end
            guild.members[target] = nil
            kicked = true
            return guild
        end)
    end)
    if not ok then return false, "Guilds are unavailable right now. Try again in a minute." end
    if not kicked then return false, err or "Couldn't remove that player" end
    local online = Players:GetPlayerByUserId(tonumber(target))
    local od = online and PlayerDataService.Get(online)
    if od then
        od.GuildId = nil
        od.GuildLevel = 0
        pending[online.UserId] = nil
        PlayerDataService.MarkDirty(online)
        local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
        if RemoteEvents.Notify then RemoteEvents.Notify:FireClient(online, "Guild", "You were removed from your guild.") end
    end
    return true
end

function GuildService.Promote(leader, targetUserId)
    local data = PlayerDataService.Get(leader)
    if not data or not data.GuildId then return false, "You are not in a guild" end
    local target = tostring(targetUserId)
    if target == tostring(leader.UserId) then return false, "You already lead this guild" end
    local err, done
    local ok = pcall(function()
        guildStore:UpdateAsync(GuildKey(data.GuildId), function(guild)
            if type(guild) ~= "table" then err = "Your guild no longer exists" return nil end
            if tostring(guild.leader) ~= tostring(leader.UserId) then err = "Only the guild leader can do that" return nil end
            if not guild.members[target] then err = "That player isn't in your guild" return nil end
            guild.leader = tonumber(target) or target
            done = true
            return guild
        end)
    end)
    if not ok then return false, "Guilds are unavailable right now. Try again in a minute." end
    if not done then return false, err or "Couldn't change the leader" end
    return true
end

-- ── Invites ───────────────────────────────────────────────────────────────────
-- A member invites a player who is on the same server. The invite lives in memory for INVITE_SECONDS.
local invites = {}               -- target userId -> { guildName, fromName, fromId, expires }
local lastInvite = {}            -- inviter userId -> os.clock()

local function FindOnline(name)
    if type(name) ~= "string" then return nil end
    local lower = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == lower or (p.DisplayName or ""):lower() == lower then return p end
    end
    return nil
end

-- Returns true, or false + a reason
function GuildService.Invite(inviter, targetName)
    local data = PlayerDataService.Get(inviter)
    if not data or not data.GuildId then return false, "Join or found a guild first" end
    if os.clock() - (lastInvite[inviter.UserId] or -1e9) < GuildData.INVITE_GAP then return false, "Slow down a little" end
    local target = FindOnline(targetName)
    if not target then return false, "No player with that name is on this server" end
    if target == inviter then return false, "You can't invite yourself" end
    local td = PlayerDataService.Get(target)
    if not td then return false, "That player isn't ready yet" end
    if td.GuildId then return false, target.DisplayName .. " is already in a guild" end
    local guild = LoadGuild(data.GuildId)
    if not guild or not guild.members[tostring(inviter.UserId)] then return false, "Your guild no longer exists" end
    if CountMembers(guild) >= GuildData.MAX_MEMBERS then return false, "Your guild is full" end
    local existing = invites[target.UserId]
    if existing and existing.expires > os.clock() then return false, target.DisplayName .. " already has an invite waiting" end

    lastInvite[inviter.UserId] = os.clock()
    invites[target.UserId] = { guildName = guild.name, fromName = inviter.DisplayName or inviter.Name, fromId = inviter.UserId,
        expires = os.clock() + GuildData.INVITE_SECONDS }
    local RemoteEvents = require(game.ReplicatedStorage.Shared.Modules.RemoteEvents)
    if RemoteEvents.GuildInvite then RemoteEvents.GuildInvite:FireClient(target, guild.name, inviter.DisplayName or inviter.Name, inviter.UserId) end
    return true
end

-- The player answers their invite. Returns the guild snapshot on accept, true on decline, or nil + a reason.
function GuildService.RespondInvite(player, accept)
    local inv = invites[player.UserId]
    invites[player.UserId] = nil
    if not inv or inv.expires < os.clock() then return nil, "That invite has expired" end
    if not accept then return true end
    local saved = GuildService.ThrottleSeconds
    GuildService.ThrottleSeconds = 0            -- accepting is not a spammy join attempt
    local guild, err = GuildService.Join(player, inv.guildName)
    GuildService.ThrottleSeconds = saved
    return guild, err
end

-- ── Chat ──────────────────────────────────────────────────────────────────────
-- Messages are filtered for everyone who can read them, then kept (the last CHAT_KEEP) in their own record.
local lastChat = {}              -- userId -> os.clock()

local function FilterText(player, text)
    local ok, result = pcall(function()
        local filtered = TextService:FilterStringAsync(text, player.UserId)
        return filtered:GetNonChatStringForBroadcastAsync()
    end)
    if ok and type(result) == "string" then return result end
    if ok == false and TextService.FilterStringAsync then return nil end
    return text
end

-- Returns true, or false + a reason
function GuildService.SendChat(player, raw)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId then return false, "You are not in a guild" end
    if type(raw) ~= "string" then return false, "Say something first" end
    local text = raw:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #text == 0 then return false, "Say something first" end
    if #text > GuildData.CHAT_MAX_LEN then text = text:sub(1, GuildData.CHAT_MAX_LEN) end
    if os.clock() - (lastChat[player.UserId] or -1e9) < GuildData.CHAT_GAP then return false, "Slow down a little" end
    lastChat[player.UserId] = os.clock()
    local clean = FilterText(player, text)
    if not clean then return false, "That message couldn't be sent" end
    local id = data.GuildId
    local ok = pcall(function()
        chatStore:UpdateAsync("c_" .. id, function(old)
            local list = type(old) == "table" and old or {}
            table.insert(list, { name = player.DisplayName or player.Name, userId = player.UserId, text = clean, t = Now() })
            while #list > GuildData.CHAT_KEEP do table.remove(list, 1) end
            return list
        end)
    end)
    if not ok then return false, "Chat is unavailable right now" end
    return true
end

function GuildService.GetChat(player)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId then return {} end
    local ok, list = pcall(function() return chatStore:GetAsync("c_" .. data.GuildId) end)
    return ok and type(list) == "table" and list or {}
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
    local week, credited, total
    local ok = pcall(function()
        guildStore:UpdateAsync(GuildKey(id), function(guild)
            if type(guild) ~= "table" then return nil end
            local m = guild.members[tostring(player.UserId)]
            if not m then return nil end
            Rollover(guild)
            m.weekly = (m.weekly or 0) + amount
            guild.weekly = (guild.weekly or 0) + amount
            guild.total = (guild.total or 0) + amount
            week, credited, total = guild.week, true, guild.total
            return guild
        end)
    end)
    if not ok then pending[player.UserId] = (pending[player.UserId] or 0) + amount return end   -- try again next flush
    if credited then
        data.GuildLevel = GuildData.LevelOf(total or 0)
        pcall(function() WeeklyBoard(week):UpdateAsync(id, function(old) return (old or 0) + amount end) end)
    else
        data.GuildLevel = 0
        data.GuildId = nil                                  -- the guild is gone or we were removed from it
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

-- ── Battle prizes ─────────────────────────────────────────────────────────────
-- Where a guild finished on last week's leaderboard (nil if it wasn't in the top 50)
local function LastWeekRank(guildId)
    local lastWeek = GuildData.WeekId(Now()) - 1
    local ok, pages = pcall(function() return WeeklyBoard(lastWeek):GetSortedAsync(false, 50) end)
    if not ok or not pages then return nil end
    local okPage, page = pcall(function() return pages:GetCurrentPageAsync() end)
    if not okPage or not page then return nil end
    for rank, entry in ipairs(page) do
        if entry.key == guildId then return rank end
    end
    return nil
end

-- What this member may claim for last week: { rank, prize, canClaim, claimed } or nil when there is nothing
local function PrizeStatus(guild, userId)
    Rollover(guild)
    local lastWeek = GuildData.WeekId(Now()) - 1
    local m = guild.members[tostring(userId)]
    if not m or not guild.last or guild.last.week ~= lastWeek then return nil end
    local rank = LastWeekRank(guild.id)
    local prize = GuildData.PrizeFor(rank)
    if not prize then return nil end
    local claimed = m.prizeWeek == lastWeek
    return {
        rank = rank, prize = prize, claimed = claimed,
        canClaim = not claimed and (m.lastWeekly or 0) >= GuildData.MIN_CONTRIBUTION,
        contributed = m.lastWeekly or 0,
    }
end

function GuildService.ClaimPrize(player)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId then return false, "You are not in a guild" end
    GuildService.Flush(player)
    local guild = LoadGuild(data.GuildId)
    if not guild then return false, "Your guild no longer exists" end
    local status = PrizeStatus(guild, player.UserId)
    if not status then return false, "Your guild didn't place in last week's top 10" end
    if status.claimed then return false, "You already claimed last week's prize" end
    if not status.canClaim then
        return false, string.format("You needed at least %d resources last week to share in the prize", GuildData.MIN_CONTRIBUTION)
    end

    local lastWeek = GuildData.WeekId(Now()) - 1
    local granted, err = false, nil
    local pok = pcall(function()
        guildStore:UpdateAsync(GuildKey(data.GuildId), function(g)
            if type(g) ~= "table" then err = "Your guild no longer exists" return nil end
            Rollover(g)
            local m = g.members[tostring(player.UserId)]
            if not m or m.prizeWeek == lastWeek then err = "You already claimed last week's prize" return nil end
            m.prizeWeek = lastWeek
            granted = true
            return g
        end)
    end)
    if not pok then return false, "Guilds are unavailable right now. Try again in a minute." end
    if not granted then return false, err or "Nothing to claim" end

    local prize = status.prize
    data.EmberCoins = (data.EmberCoins or 0) + prize.coins
    data.SpeedUps = (data.SpeedUps or 0) + prize.speedUps
    if prize.title then
        data.Titles = data.Titles or {}
        if not Utils.TableContains(data.Titles, prize.title) then table.insert(data.Titles, prize.title) end
    end
    PlayerDataService.MarkDirty(player)
    return true, prize, status.rank
end

-- ── Reading ───────────────────────────────────────────────────────────────────
function GuildService.GetMine(player)
    local data = PlayerDataService.Get(player)
    if not data or not data.GuildId then return nil end
    GuildService.Flush(player)
    local guild = LoadGuild(data.GuildId)
    if not guild or not guild.members[tostring(player.UserId)] then
        data.GuildId = nil                                   -- disbanded, or removed
        data.GuildLevel = 0
        PlayerDataService.MarkDirty(player)
        return nil
    end
    local snap = Snapshot(guild, player.UserId)
    data.GuildLevel = snap.level
    snap.prize = PrizeStatus(guild, player.UserId)
    return snap
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
    lastChat[player.UserId] = nil
    lastInvite[player.UserId] = nil
    invites[player.UserId] = nil
end

return GuildService
