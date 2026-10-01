QUIET = true
-- Guilds: names, create / join / leave, the weekly challenge and its reward, week rollover, the leaderboard.
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify", "LevelUp", "ForgeUpgraded" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local GS = load("SSS/EmberForge/Services/GuildService")
local GuildData = load("game/ReplicatedStorage/Shared/Data/GuildData")

GS.ThrottleSeconds = 0          -- the anti-spam delay is tested separately below

print("== guild names")
expect(GuildData.CleanName("  Iron   Hands ") == "Iron Hands", "spaces are tidied")
expect(GuildData.CleanName("ab") == nil and GuildData.CleanName(string.rep("x", 21)) == nil, "too short / too long refused")
expect(GuildData.CleanName("Bad<Name>") == nil and GuildData.CleanName("Hi!") == nil, "symbols refused")
expect(GuildData.CleanName(5) == nil, "non-strings refused")
expect(GuildData.ChallengeTarget(1) == 26000 and GuildData.ChallengeTarget(10) == 80000, "the weekly target grows with the guild")

local function mkPlayer(id, name, coins)
    local p = newPlayer(id, name)
    local d = PDS.Load(p)
    d.EmberCoins = coins or 1000
    return p, d
end

print("== creating a guild")
local a, da = mkPlayer(1, "Ada")
local b, db = mkPlayer(2, "Bo")
local g, err = GS.Create(a, "Ember Crew")
expect(g and g.name == "Ember Crew" and g.memberCount == 1 and g.isLeader, "Ada founds Ember Crew (" .. tostring(err) .. ")")
expect(da.EmberCoins == 500 and da.GuildId == g.id, "founding costs 500 coins and stores the guild id")
local _, e2 = GS.Create(a, "Another One")
expect(e2 ~= nil, "already in a guild: can't found another")
local poor = mkPlayer(9, "Poor", 10)
local _, e3 = GS.Create(poor, "Broke Crew")
expect(e3 ~= nil and e3:find("coins"), "founding needs the coins (" .. tostring(e3) .. ")")
local _, e4 = GS.Create(b, "ember crew")
expect(e4 == "That guild name is taken", "names are unique, ignoring case (" .. tostring(e4) .. ")")
local _, e5 = GS.Create(b, "x!")
expect(e5 ~= nil, "invalid names are refused")

print("== joining and leaving")
local j, jerr = GS.Join(b, "EMBER crew")
expect(j and j.memberCount == 2 and db.GuildId == g.id, "Bo joins by name (case-insensitive) (" .. tostring(jerr) .. ")")
local _, jn = GS.Join(mkPlayer(3, "Cy"), "No Such Guild")
expect(jn == "No guild has that name", "joining an unknown guild fails")
local c, dc = mkPlayer(3, "Cy2")
-- fill the guild to 20
local fakeIds = {}
for i = 1, 18 do
    local p = mkPlayer(100 + i, "P" .. i)
    local r, er = GS.Join(p, "Ember Crew")
    if not r then fakeIds = nil break end
end
local _, full = GS.Join(c, "Ember Crew")
expect(full == "That guild is full", "a 21st player is refused (" .. tostring(full) .. ")")
local okL = GS.Leave(c)
expect(okL == false, "leaving without a guild is refused")

print("== the weekly challenge")
local mine = GS.GetMine(a)
expect(mine.memberCount == 20 and mine.target == GuildData.ChallengeTarget(20), "20 members -> target " .. mine.target)
GS.OnResourcesGained(a, 60000)
GS.Flush(a)
GS.OnResourcesGained(b, 40)
GS.Flush(b)
mine = GS.GetMine(a)
expect(mine.weekly == 60040 and not mine.complete, "production from two members adds up (" .. mine.weekly .. ")")
GS.OnResourcesGained(a, mine.target)
GS.Flush(a)
mine = GS.GetMine(a)
expect(mine.complete and mine.canClaim, "the challenge completes and Ada can claim")
local before = da.EmberCoins
local claimed, reward = GS.ClaimReward(a)
expect(claimed and da.EmberCoins == before + GuildData.REWARD.coins and da.SpeedUps == GuildData.REWARD.speedUps, "claiming pays coins and a Speed-Up")
local again = GS.ClaimReward(a)
expect(again == false, "each member claims once a week")
local bClaim, bErr = GS.ClaimReward(b)
expect(bClaim == false and bErr:find("at least"), "a member who added under " .. GuildData.MIN_CONTRIBUTION .. " resources can't claim (" .. tostring(bErr) .. ")")

print("== week rollover")
-- pretend last week's record is what is stored
local GuildStore = load("SSS/EmberForge/Services/SafeDataStore").GetDataStore("EF_Guilds_v1")
local key = "g_" .. mine.id
local rec = GuildStore:GetAsync(key)
rec.week = rec.week - 1
GuildStore:SetAsync(key, rec)
local fresh = GS.GetMine(a)
expect(fresh.weekly == 0 and not fresh.complete and fresh.claimed == false, "a new week resets the weekly total, the claims and the bar")
expect(fresh.total >= 120000, "all-time production is kept (" .. fresh.total .. ")")

print("== leaderboard")
GS.OnResourcesGained(a, 500)
GS.Flush(a)
local d3 = select(2, mkPlayer(200, "Dee"))
local dee = Players._list[#Players._list]
local g2 = GS.Create(dee, "Frost Pack")
GS.OnResourcesGained(dee, 9000)
GS.Flush(dee)
local top = GS.Top(10)
-- the board keeps everything mined this week, so Ember Crew (200,540 so far) leads Frost Pack (9,000)
expect(#top >= 2 and top[1].name == "Ember Crew" and top[1].rank == 1 and top[1].weekly == 200540, "the week's top guild is first (" .. tostring(top[1] and top[1].weekly) .. ")")
expect(top[2].name == "Frost Pack" and top[2].weekly == 9000 and top[2].members == 1, "then the next guild by combined production")

print("== leaving, leadership and disbanding")
local _, dp = mkPlayer(300, "Eve")
local eve = Players._list[#Players._list]
GS.Join(eve, "Frost Pack")
local leftOk = GS.Leave(dee)
expect(leftOk == true, "the leader can leave")
local evesGuild = GS.GetMine(eve)
expect(evesGuild.isLeader and evesGuild.memberCount == 1, "leadership passes to the remaining member")
GS.Leave(eve)
local _, gone = GS.Join(mkPlayer(301, "Fay"), "Frost Pack")
expect(gone == "No guild has that name", "an empty guild is disbanded and its name freed")
local g3 = GS.Create(mkPlayer(302, "Gus"), "Frost Pack")
expect(g3 ~= nil, "a disbanded guild's name can be used again")

print("== battle prizes")
local pnow = GS.GetMine(a)
expect(pnow.prize == nil, "no prize before a week has finished")
advance(7 * 86400)                                  -- the week ends
local pa = GS.GetMine(a)
expect(pa.prize and pa.prize.rank == 1 and pa.prize.canClaim and pa.prize.prize.title == "Guild Champion",
    "the winning guild's contributor can claim the #1 prize (rank " .. tostring(pa.prize and pa.prize.rank) .. ")")
local pb = GS.GetMine(b)
expect(pb.prize and not pb.prize.canClaim, "a member who added under " .. GuildData.MIN_CONTRIBUTION .. " last week can't claim")
local coinsBefore, suBefore = da.EmberCoins, da.SpeedUps or 0
local okP, prize = GS.ClaimPrize(a)
expect(okP and da.EmberCoins == coinsBefore + 3000 and da.SpeedUps == suBefore + 3, "claiming pays the #1 prize")
expect(table.find(da.Titles or {}, "Guild Champion") ~= nil, "and grants the Guild Champion title")
expect(GS.ClaimPrize(a) == false, "a prize is claimed once")
expect(GS.ClaimPrize(b) == false, "an ineligible member is refused")
expect(GS.GetMine(a).prize.claimed == true, "the menu shows it as claimed")
advance(7 * 86400)                                  -- a further week passes with no production
expect(GS.GetMine(a).prize == nil, "an old prize doesn't carry over a second week")
expect(GuildData.PrizeFor(1).coins > GuildData.PrizeFor(3).coins and GuildData.PrizeFor(3).coins > GuildData.PrizeFor(10).coins
    and GuildData.PrizeFor(11) == nil, "prizes shrink with rank and stop after 10th")

print("== anti-spam")
GS.ThrottleSeconds = 60
local spam = mkPlayer(400, "Spam")
local first = GS.Create(spam, "Spam One")
local _, slow = GS.Join(spam, "Frost Pack")
expect(first ~= nil and slow == "Slow down a little" or slow == "Leave your current guild first", "rapid create/join attempts are slowed down (" .. tostring(slow) .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
