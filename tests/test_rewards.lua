QUIET = true
-- Login streak, codes, the ranked ladder, surge events and the Lucky Boost.
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local SS = load("SSS/EmberForge/Services/StreakService")
local CS = load("SSS/EmberForge/Services/CodeService")
local LS = load("SSS/EmberForge/Services/LadderService")
local LO = load("SSS/EmberForge/Services/LiveOpsService")
local ShopS = load("SSS/EmberForge/Services/ShopService")
local ST = load("game/ReplicatedStorage/Shared/Data/StreakData")
local CD = load("game/ReplicatedStorage/Shared/Data/CodeData")
local LD = load("game/ReplicatedStorage/Shared/Data/LadderData")
local ES = load("game/ReplicatedStorage/Shared/Data/EventScheduleData")
local PR = load("game/ReplicatedStorage/Shared/Data/ProductData")

local function mk(id, name, coins)
    local p = newPlayer(id, name)
    local d = PDS.Load(p)
    d.EmberCoins = coins or 0
    return p, d
end

CS.ThrottleSeconds = 0

print("== login streak")
local a, da = mk(1, "Ada", 0)
local r1 = SS.OnJoin(a)
expect(r1 and r1.streak == 1 and r1.day == 1 and da.EmberCoins == 100, "day 1 pays 100 coins")
expect(SS.OnJoin(a) == nil, "only one reward per day")
advance(86400)
local r2 = SS.OnJoin(a)
expect(r2 and r2.streak == 2 and da.EmberCoins == 250, "consecutive day: streak 2, +150")
advance(86400)
SS.OnJoin(a)
expect((da.SpeedUps or 0) == 1, "day 3 gives a Speed-Up")
for _ = 4, 6 do advance(86400) SS.OnJoin(a) end
advance(86400)
local before = da.EmberCoins
local r7 = SS.OnJoin(a)
expect(r7 and r7.day == 7 and da.EmberCoins == before + 600 and (da.LuckBoostExpiry or 0) > os.time(), "day 7 pays the big reward with a Lucky Boost")
advance(86400)
local r8 = SS.OnJoin(a)
expect(r8 and r8.streak == 8 and r8.day == 1, "the ladder repeats while the streak keeps counting")
advance(3 * 86400)
local r9 = SS.OnJoin(a)
expect(r9 and r9.streak == 1 and da.LoginStreak.best == 8, "missing days restarts the streak but keeps the best")
expect(ST.LadderDay(7) == 7 and ST.LadderDay(8) == 1 and ST.LadderDay(14) == 7, "ladder day maths")

print("== codes")
local b, db = mk(2, "Bo", 0)
local ok, msg = CS.Redeem(b, "emberforge")
expect(ok and db.EmberCoins == 500 and db.SpeedUps == 1, "a code works ignoring case (" .. tostring(msg) .. ")")
local ok2, msg2 = CS.Redeem(b, "  EMBERFORGE ")
expect(not ok2 and msg2:find("already"), "a code works once per player (" .. tostring(msg2) .. ")")
expect(not CS.Redeem(b, "NOPE123"), "unknown code refused")
expect(not CS.Redeem(b, "bad code!"), "malformed code refused")
expect(not CS.Redeem(b, 12345), "non-string refused")
local ok3 = CS.Redeem(b, "golems")
expect(ok3 and (db.LuckBoostExpiry or 0) > os.time(), "a code can give a Lucky Boost")
CD.Codes.OLD = { coins = 5, expires = os.time() - 10 }
local ok4, msg4 = CS.Redeem(b, "old")
expect(not ok4 and msg4:find("expired"), "expired code refused")
CS.ThrottleSeconds = 60
CS.Redeem(b, "x1x")
local ok5, msg5 = CS.Redeem(b, "x2x")
expect(not ok5 and msg5 == "Slow down a little", "rapid guessing is slowed")
CS.ThrottleSeconds = 0

print("== ranked ladder")
expect(LD.TierOf(0).name == "Bronze" and LD.TierOf(20000).name == "Silver" and LD.TierOf(5000000).name == "Champion", "tiers by points")
local nt, need = LD.NextTier(10000)
expect(nt.name == "Silver" and need == 10000, "points to the next tier")
expect(LD.NextTier(9e9) == nil, "no tier above Champion")
local c, dc = mk(3, "Cy", 0)
LS.OnResourcesGained(c, 150000)
LS.Flush(c)
local info = LS.GetInfo(c)
expect(info.points == 150000 and info.tier == "Gold" and info.rank == 1, "points place you in a tier and on the board (" .. tostring(info.tier) .. ", rank " .. tostring(info.rank) .. ")")
expect(info.prize == nil, "no prize in your first season")
local d2, dd2 = mk(4, "Di", 0)
LS.OnResourcesGained(d2, 5000)
LS.Flush(d2)
local top = LS.Top(10)
expect(top[1].name == "Cy" and top[2].name == "Di" and top[1].points > top[2].points, "the board is ordered")
advance(LD.SEASON_SECONDS)
local after = LS.GetInfo(c)
expect(after.points == 0 and after.tier == "Bronze", "a new season starts everyone at zero")
expect(after.prize and after.prize.prize.title == "Season Champion" and not after.prize.claimed, "last season's #1 can claim the champion prize")
local cBefore = dc.EmberCoins
local okC, prize = LS.ClaimPrize(c)
expect(okC and dc.EmberCoins == cBefore + 10000 and table.find(dc.Titles, "Season Champion"), "claiming pays coins and the title")
expect(LS.ClaimPrize(c) == false, "claimed once")
local dInfo = LS.GetInfo(d2)
expect(dInfo.prize and dInfo.prize.prize.title == "Season Elite", "rank 2 is Season Elite")
expect(LD.PrizeFor(nil, 0) == nil, "an unranked Bronze player has no prize")
expect(LD.PrizeFor(nil, 120000).coins == 800, "an unranked Gold player gets the tier prize")

print("== surge events")
local found, count = 0, 0
local t0 = 1800000000 - (1800000000 % 10800)
for w = 0, 400 do
    local s = ES.Surge(t0 + w * 10800 + 30)
    if s then found += 1 end
    expect(ES.Surge(t0 + w * 10800 + ES.SURGE_SECONDS + 5) == nil, "a surge is over after " .. ES.SURGE_SECONDS .. "s (window " .. w .. ")")
    if w > 3 then break end
end
for w = 0, 400 do if ES.Surge(t0 + w * 10800 + 30) then count += 1 end end
expect(count > 80 and count < 200, "about a third of windows have a surge (" .. count .. "/401)")
local s1 = ES.Surge((function() for w = 0, 400 do if ES.Surge(t0 + w * 10800 + 30) then return t0 + w * 10800 + 30 end end end)())
expect(s1 and s1.multiplier >= 3 and s1.endTime - s1.startTime == ES.SURGE_SECONDS, "a surge is a big multiplier for ten minutes")
expect(ES.NextSurgeStart(t0) ~= nil, "the next surge can be found")

print("== lucky boost")
expect(PR.Products.LuckBoost_1h ~= nil and PR.Products.LuckBoost_1h.id == 0, "the Lucky Boost product exists (id to be set)")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
