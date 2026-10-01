QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify" }) do RemoteEvents[n] = fireCounter() end
RemoteEvents.PetHatched = fireCounter()
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local LiveOps = load("SSS/EmberForge/Services/LiveOpsService")
local Admin = load("SSS/EmberForge/Services/AdminService")
local Trading = load("SSS/EmberForge/Services/TradingService")
local GC = load("game/ReplicatedStorage/Shared/Data/GameConfig")

local boss = newPlayer(1, "Boss"); local bd = PDS.Load(boss)
local kid = newPlayer(2, "Kid"); local kd = PDS.Load(kid)

print("== admin actions")
local coins = kd.EmberCoins
local ok = Admin.Action(boss, "grantCoins", { target = "kid", amount = "500" }, LiveOps)
expect(ok and kd.EmberCoins == coins + 500, "gift coins by name (any case)")
expect(not Admin.Action(boss, "grantCoins", { target = "Kid", amount = 99999999 }, LiveOps), "gift is capped")
expect(not Admin.Action(boss, "grantCoins", { target = "Nobody", amount = 5 }, LiveOps), "unknown player refused")
expect(not Admin.Action(boss, "grantMaterial", { target = "Kid", id = "NotAThing", qty = 1 }, LiveOps), "unknown material refused")
expect(not Admin.Action(boss, "nonsense", {}, LiveOps), "unknown action refused")
LiveOps.HourlyEnabled = false
local pets0, golems0 = #(kd.OwnedPets or {}), #kd.Golems
expect(Admin.Action(boss, "grantEgg", { target = "Kid", id = "Basic", qty = 3 }, LiveOps) and #kd.OwnedPets == pets0 + 3, "gift 3 eggs hatches 3 pets")
expect(not Admin.Action(boss, "grantEgg", { target = "Kid", id = "Basic", qty = 50 }, LiveOps), "egg gift is capped")
expect(not Admin.Action(boss, "grantEgg", { target = "Kid", id = "Nope", qty = 1 }, LiveOps), "unknown egg refused")
expect(Admin.Action(boss, "grantPet", { target = "Kid", id = "Ember", variant = "Neon" }, LiveOps) and kd.OwnedPets[#kd.OwnedPets].variant == "Neon", "gift an Elite pet")
expect(not Admin.Action(boss, "grantPet", { target = "Kid", id = "Ember", variant = "Godly" }, LiveOps), "bad variant refused")
expect(Admin.Action(boss, "grantGolem", { target = "Kid", id = "BP_Ember_T1" }, LiveOps) and #kd.Golems == golems0 + 1, "gift a Golem")
expect(kd.Golems[#kd.Golems].quality < 0.5, "gifted Golem has a normal quality bonus")
expect(not Admin.Action(boss, "grantGolem", { target = "Kid", id = "BP_Nope" }, LiveOps), "unknown blueprint refused")
expect(Admin.Action(boss, "event", { kind = "xp", multiplier = 2, hours = 2 }, LiveOps) and LiveOps.GetMultiplier("xp") == 2, "event starts")
expect(not Admin.Action(boss, "event", { kind = "xp", multiplier = 50, hours = 2 }, LiveOps), "silly multiplier refused")
Admin.Action(boss, "clearEvents", {}, LiveOps)
expect(LiveOps.GetMultiplier("xp") == 1, "events cleared")
local okL, r = Admin.Action(boss, "lookup", { target = 2 }, LiveOps)
expect(okL and r.userId == 2 and type(r.log) == "table" and type(r.reports) == "table", "lookup returns log and reports")

print("== account age gate")
local rs = game:GetService("RunService")
local oldStudio = rs.IsStudio
rs.IsStudio = function() return false end
kid.AccountAge = 2
boss.AccountAge = 400
expect(Trading.AgeGate(kid) ~= nil, "2-day-old account is gated")
expect(Trading.AgeGate(boss) == nil, "old account passes")
expect(Trading.InitiateTrade(boss, kid) == nil, "can't start a trade with a new account")
expect(Trading.InitiateTrade(kid, boss) == nil, "a new account can't start one")
GC.TRADE_MIN_ACCOUNT_AGE_DAYS = 0
expect(Trading.AgeGate(kid) == nil, "0 turns the limit off")
rs.IsStudio = oldStudio

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
