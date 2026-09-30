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

print("== Robux pad unlocks (game passes)")
do
    local PadData = load("game/ReplicatedStorage/Shared/Data/PadData")
    local PadService = load("SSS/EmberForge/Services/PadService")
    local MPS = game:GetService("MarketplaceService")
    local function pad(id) for _, def in ipairs(PadData.Pads) do if def.id == id then return def end end end
    d3.PlayerLevel = 1; d3.UnlockedPads = {}
    expect(PadService.CanUse(p3, pad("Copper"), d3) == false, "a level 1 player can't use the Copper pad")
    local k1 = Product.PassForPad("Copper")
    expect(k1 == "Pad_Copper" and Product.PassForPad("Starter") == nil and Product.PassForPad("Admin") == nil, "only Copper / Iron / Gold are for sale")
    expect(not Product.PassIsAvailable("Pad_Copper"), "unconfigured passes (id 0) are not for sale")

    Product.GamePasses.Pad_Copper.id = 777
    Product.GamePasses.Pad_Iron.id = 888
    expect(Product.PassIsAvailable("Pad_Copper"), "a pass with an id is for sale")

    -- buying in the prompt
    MPS.FireGamePassFinished(p3, 777, false)
    expect(not d3.UnlockedPads.Copper, "cancelling the prompt unlocks nothing")
    MPS.FireGamePassFinished(p3, 777, true)
    expect(d3.UnlockedPads.Copper == true, "buying the Copper pass unlocks the pad")
    expect(PadService.CanUse(p3, pad("Copper"), d3) == true, "the bought pad works below its level")
    expect(PadService.CanUse(p3, pad("Iron"), d3) == false, "buying Copper doesn't unlock Iron")

    -- owned on Roblox (bought on the game page / another server) is picked up on join
    MPS._owned[p3.UserId .. ":888"] = true
    local Shop2 = load("SSS/EmberForge/Services/ShopService")
    Shop2.OnPlayerAdded(p3)
    expect(d3.UnlockedPads.Iron == true, "passes already owned on Roblox unlock on join")
    expect(Shop2.RefreshPasses(p3) == false, "nothing new to unlock the second time")

    -- other permanent unlocks are passes too, and can't be granted twice
    Product.GamePasses.Storage24h.id = 901
    Product.GamePasses.Skin_Ember.id = 902
    d3.StorageTier = 0; d3.OwnedCosmetics = {}
    MPS.FireGamePassFinished(p3, 901, true)
    expect(d3.StorageTier == 2, "the Storage pass gives 24h storage")
    MPS.FireGamePassFinished(p3, 902, true)
    MPS.FireGamePassFinished(p3, 902, true)
    local skins = 0
    for _, id in ipairs(d3.OwnedCosmetics) do if id == "ForgeSkin_Ember" then skins += 1 end end
    expect(skins == 1, "a forge skin pass adds the skin exactly once")
    expect(Product.Products.StorageExpansion == nil and Product.Products.ForgeSkin_Ember == nil, "permanent items are no longer Developer Products")
    expect(Shop2.GrantPass(p3, "Storage24h", false) == false, "granting an owned pass does nothing")

    -- contextual offers
    local RE = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
    local offers = {}
    RE.ShopOffer = { FireClient = function(_, _, kind, key, reason) table.insert(offers, key) end }
    d3.StorageTier = 0
    expect(Shop2.Offer(p3, "pass", "Storage24h", "why") == true and offers[1] == "Storage24h", "an offer is sent when it is useful")
    expect(Shop2.Offer(p3, "pass", "Storage24h", "again") == false, "the same offer is not repeated straight away")
    expect(Shop2.Offer(p3, "product", "SpeedUp_x10", "x") == false, "offers are limited to one every few minutes")
    d3.StorageTier = 2
    expect(Shop2.Offer(p3, "pass", "Storage24h", "owned") == false, "never offers what they already own")
    Product.GamePasses.Storage24h.id = 0
    expect(Shop2.Offer(p3, "pass", "Storage24h", "unset") == false, "never offers something not on sale")

    d3.UnlockedPads = {}; d3.PlayerLevel = 10
    expect(PadService.CanUse(p3, pad("Iron"), d3) == true, "levelling up still unlocks pads for free")
    d3.PlayerLevel = 1; d3.UnlockedPads = {}
    MPS._owned = {}
end

print("== Stackable slot packs")
do
    local GC = load("game/ReplicatedStorage/Shared/Data/GameConfig")
    local MPS = game:GetService("MarketplaceService")
    Product.Products.SlotPack_5.id = 556
    d3.SeasonPassTier = 0; d3.GolemSlots = 3; d3.PurchasedSlots = 0; d3.TempSlotBoostExpiry = 0
    local before = Shop.GetEffectiveGolemSlots(p3)
    MPS.ProcessReceipt({ PlayerId = 12, ProductId = 556, PurchaseId = "sp1" })
    expect(d3.PurchasedSlots == 5 and Shop.GetEffectiveGolemSlots(p3) == before + 5, "one pack adds 5 slots")
    MPS.ProcessReceipt({ PlayerId = 12, ProductId = 556, PurchaseId = "sp2" })
    MPS.ProcessReceipt({ PlayerId = 12, ProductId = 556, PurchaseId = "sp2" })
    expect(d3.PurchasedSlots == 10 and Shop.GetEffectiveGolemSlots(p3) == before + 10, "a second pack stacks, and a repeated receipt is ignored")
    expect(GC.MAX_GOLEM_SLOTS >= 12 + 3 + 1 + GC.MAX_PURCHASED_SLOTS, "the slot ceiling leaves room for every pack")
    d3.PurchasedSlots = GC.MAX_PURCHASED_SLOTS
    local RE2 = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
    RE2.ShopOffer = { FireClient = function() end }
    expect(Shop.Offer(p3, "product", "SlotPack_5", "x") == false, "no slot-pack offer once the maximum is bought")
    d3.PurchasedSlots = 0
end

print("== Premium bonus")
do
    local CS = load("SSS/EmberForge/Services/ChallengeService")
    local pp = newPlayer(31, "Prem"); local dp = PDS.Load(pp)
    pp.MembershipType = Enum.MembershipType.Premium
    dp.LastDailyReset = 0; dp.EmberCoins = 0; dp.SpeedUps = 0
    local r = CS.CheckResets(pp)
    local pn = newPlayer(32, "Norm"); local dn = PDS.Load(pn)
    dn.LastDailyReset = 0; dn.EmberCoins = 0; dn.SpeedUps = 0
    CS.CheckResets(pn)
    expect(r.premium and dp.EmberCoins > dn.EmberCoins and dp.SpeedUps == 1 and dn.SpeedUps == 0, "Roblox Premium members get extra daily coins and a free Speed-Up")
end

print("== slots")
d3.SeasonPassTier = 1; d3.GolemSlots = 3
expect(Shop.GetEffectiveGolemSlots(p3) == 6, "pass gives +3 on top of earned slots")
d3.GolemSlots = 9
expect(Shop.GetEffectiveGolemSlots(p3) == 12, "capped at 12")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
