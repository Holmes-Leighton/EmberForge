QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
RemoteEvents.Notify = fireCounter()
RemoteEvents.AchievementUnlocked = fireCounter()
RemoteEvents.ChallengeCompleted = fireCounter()
RemoteEvents.LevelUp = fireCounter()
local Safe = load("SSS/EmberForge/Services/SafeDataStore")
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local Utils = load("game/ReplicatedStorage/Shared/Modules/Utils")

print("== session locking")
local store = Safe.GetDataStore("EmberForge_v1")
local p1 = newPlayer(10, "Locked")
store:SetAsync("EF_v1_10", { PlayerLevel = 7, ForgeLevel = 1, Golems = {}, Inventory = {}, Blueprints = {}, LastOnline = 1,
    _lock = { jobId = "OTHER-SERVER", time = os.time() } })
local d, why = PDS.Load(p1)
expect(d == nil, "record held by a live server is not loaded (" .. tostring(why) .. ")")
advance(2000)   -- the other server's lock is now stale (crashed)
d = PDS.Load(p1)
expect(d ~= nil and d.PlayerLevel == 7, "stale lock is taken over and the real record is loaded (level " .. tostring(d and d.PlayerLevel) .. ")")
d.EmberCoins = 999
expect(PDS.Save(p1, true), "save succeeds while we hold the lock")
-- another server steals it meanwhile
local rec = store:GetAsync("EF_v1_10")
rec._lock = { jobId = "OTHER-SERVER", time = os.time() }
store:SetAsync("EF_v1_10", rec)
expect(PDS.Save(p1, true) == false, "save refuses to overwrite a record locked by another server")
expect(store:GetAsync("EF_v1_10")._lock.jobId == "OTHER-SERVER", "other server's record untouched")

print("== new player is never given someone else's data")
local p2 = newPlayer(11, "Fresh")
local d2 = PDS.Load(p2)
expect(d2 and d2.PlayerLevel == 1 and next(d2.Inventory) == nil, "brand-new player gets defaults")
PDS.OnPlayerLeave(p2)
expect(store:GetAsync("EF_v1_11")._lock == nil, "leaving releases the lock")

print("== offline credits")
PDS.CreditOfflineCoins(12, 250)
local p3 = newPlayer(12, "Seller")
local d3 = PDS.Load(p3)
expect(d3.EmberCoins == 200 + 250, "coins earned while away are applied on join (" .. tostring(d3.EmberCoins) .. ")")

print("== ChallengeService")
local Chal = load("SSS/EmberForge/Services/ChallengeService")
local ChalData = load("game/ReplicatedStorage/Shared/Data/ChallengeData")
d3.Achievements = { "ach_first_golem" }
local ok, rewards, lvl = Chal.ClaimReward(p3, "ach_first_golem")
expect(ok, "first lifetime claim works")
local xpAfterFirst = d3.PlayerXP
local ok2 = Chal.ClaimReward(p3, "ach_first_golem")
expect(not ok2, "second lifetime claim refused")
expect(d3.PlayerXP == xpAfterFirst, "XP not granted twice")
expect(d3.PlayerXP == 500, "XP granted exactly once inside ClaimReward (" .. d3.PlayerXP .. ")")

d3.DailyChallenges = { daily_deploy_golem = { progress = 0, claimed = false } }
local c1 = Chal.TrackEvent(p3, "GolemDeploy", { count = 1 })
local c2 = Chal.TrackEvent(p3, "GolemDeploy", { count = 1 })
expect(#c1 == 1 and #c2 == 0, "completion reported once, not on every later event")
expect(RemoteEvents.ChallengeCompleted.n == 1, "client told once about the completed challenge")

print("== lifetime achievements auto-pay when they unlock")
local p4 = newPlayer(20, "Achiever"); local d4 = PDS.Load(p4)
d4.Inventory = { BasicOre = 50, Coal = 50 }
local GolemS = load("SSS/EmberForge/Services/GolemService")
local xp0 = d4.PlayerXP
Chal.TrackEvent(p4, "GolemCrafted", { tier = 1, count = 1 })
expect(Utils.TableContains(d4.Achievements, "ach_first_golem"), "achievement unlocked")
expect(d4.ClaimedAchievements.ach_first_golem == true and d4.PlayerXP > xp0, "and its reward was paid immediately")
expect(Utils.TableContains(d4.Titles, "Forge Initiate"), "title granted")
-- older save with an unclaimed achievement
d4.Achievements = { "ach_first_golem", "ach_first_tier2" }
d4.ClaimedAchievements = { ach_first_golem = true }
Chal.ClaimPendingLifetime(p4)
expect(d4.ClaimedAchievements.ach_first_tier2 == true, "unclaimed achievements are paid on join")

print("== Season claims")
local Season = load("SSS/EmberForge/Services/SeasonPassService")
local SD = load("game/ReplicatedStorage/Shared/Data/SeasonData")
local cur = SD.GetCurrentSeason()
print("  current season:", cur.id)
expect(cur.id == "Season1", "before any season starts, Season1 is returned")
-- set the clock to inside Season3's third week
clock_set = SD.Seasons.Season3.startTimestamp + 14 * 86400 + 10
advance(clock_set - os.time())
cur = SD.GetCurrentSeason()
expect(cur.id == "Season3", "season 3 active at 2026-09-08")
local okS, r = Season.ClaimWeekReward(p3, "Season5", 1, "free")
expect(not okS, "cannot claim a different season's reward (" .. tostring(r) .. ")")
okS, r = Season.ClaimWeekReward(p3, "Season3", 1, "free")
expect(okS, "current season week 1 free claim works")
okS, r = Season.ClaimWeekReward(p3, "Season3", 1, "free")
expect(not okS, "no double claim")
okS, r = Season.ClaimWeekReward(p3, "Season3", 6, "free")
expect(not okS, "future week refused")
okS, r = Season.ClaimWeekReward(p3, "Season3", 1.5, "free")
expect(not okS, "fractional week refused")
okS, r = Season.ClaimWeekReward(p3, "Season3", 2, "premium")
expect(not okS, "premium track needs the pass")

print("== Shop receipts")
local Shop = load("SSS/EmberForge/Services/ShopService")
local Product = load("game/ReplicatedStorage/Shared/Data/ProductData")
Product.Products.SpeedUp_x10.id = 555
local decision = game:GetService("MarketplaceService").ProcessReceipt({ PlayerId = 12, ProductId = 555, PurchaseId = "abc" })
expect(d3.SpeedUps == 10, "numeric product id 555 grants 10 speed-ups (" .. tostring(d3.SpeedUps) .. ")")
local dec2 = game:GetService("MarketplaceService").ProcessReceipt({ PlayerId = 12, ProductId = 555, PurchaseId = "abc" })
expect(d3.SpeedUps == 10, "same receipt is not granted twice")
local dec3 = game:GetService("MarketplaceService").ProcessReceipt({ PlayerId = 12, ProductId = 999, PurchaseId = "zzz" })
expect(tostring(dec3):find("NotProcessedYet"), "unknown product is not confirmed")

print("== slots")
d3.SeasonPassTier = 1; d3.GolemSlots = 3
expect(Shop.GetEffectiveGolemSlots(p3) == 6, "pass gives +3 on top of earned slots")
d3.GolemSlots = 9
expect(Shop.GetEffectiveGolemSlots(p3) == 12, "capped at 12")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
