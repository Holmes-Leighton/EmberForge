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

expect(Admin.Action(boss, "grantBlueprint", { target = "Kid", id = "BP_Storm_T3" }, LiveOps) and table.find(kd.Blueprints, "BP_Storm_T3"), "gift a blueprint")
expect(not Admin.Action(boss, "grantBlueprint", { target = "Kid", id = "BP_Storm_T3" }, LiveOps), "no duplicate blueprint gift")
expect(Admin.Action(boss, "grantCosmetic", { target = "Kid", id = "ForgeSkin_Molten" }, LiveOps) and table.find(kd.OwnedCosmetics, "ForgeSkin_Molten"), "gift a cosmetic")
expect(not Admin.Action(boss, "grantCosmetic", { target = "Kid", id = "Banana_Split" }, LiveOps), "bad cosmetic type refused")
local oki, info = Admin.Action(boss, "inspect", { target = "Kid" }, LiveOps)
expect(oki and info.summary:find("coins") and #info.lines >= 3, "inspect shows a player's summary")

print("== moderation")
local kicked
local rs0 = game:GetService("RunService"); local studio0 = rs0.IsStudio
rs0.IsStudio = function() return false end      -- outside Studio only listed admins are admins
GC.ADMIN_USER_IDS = { 1 }
local oldAge = GC.TRADE_MIN_ACCOUNT_AGE_DAYS; GC.TRADE_MIN_ACCOUNT_AGE_DAYS = 0
kid.Kick = function(_, why) kicked = why end
expect(not Admin.Action(boss, "mute", { target = "Boss", hours = 1 }, LiveOps), "can't mute yourself")
expect(Admin.Action(boss, "mute", { target = "Kid", hours = 1, reason = "spam" }, LiveOps) and Admin.IsMuted(kid), "mute applies")
expect(Trading.AgeGate(kid) ~= nil, "a muted player can't trade")
local Guild = load("SSS/EmberForge/Services/GuildService")
kd.GuildId = "g1"
local sent, why = Guild.SendChat(kid, "hello")
expect(not sent and why == "You are muted", "a muted player can't use guild chat")
Admin.Action(boss, "unmute", { target = "Kid" }, LiveOps)
expect(not Admin.IsMuted(kid), "unmute clears it")
expect(Admin.Action(boss, "ban", { target = "Kid", hours = 2, reason = "scam" }, LiveOps) and kicked and kicked:find("scam"), "ban kicks them with the reason")
kicked = nil
expect(Admin.CheckJoin(kid) == true and kicked ~= nil, "a banned player is kicked on join")
Admin.Action(boss, "unban", { target = "Kid" }, LiveOps)
kicked = nil
expect(Admin.CheckJoin(kid) == false and kicked == nil, "unbanned players can join")
expect(not Admin.Action(boss, "ban", { target = "Kid", hours = 99999 }, LiveOps), "silly ban length refused")
expect(not Admin.Action(kid, "kick", { target = "Boss" }, LiveOps), "a non-admin can do nothing")
rs0.IsStudio = studio0; GC.ADMIN_USER_IDS = {}; GC.TRADE_MIN_ACCOUNT_AGE_DAYS = oldAge

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
