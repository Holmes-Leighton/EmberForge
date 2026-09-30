QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify", "LevelUp", "ForgeUpgraded", "AchievementUnlocked", "ChallengeCompleted" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local Golem = load("SSS/EmberForge/Services/GolemService")
local Forge = load("SSS/EmberForge/Services/ForgeService")
local Idle = load("SSS/EmberForge/Services/IdleEngine")
local Prog = load("SSS/EmberForge/Services/ProgressionService")
local Season = load("SSS/EmberForge/Services/SeasonPassService")
local SD = load("game/ReplicatedStorage/Shared/Data/SeasonData")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")
local Rules = load("game/ReplicatedStorage/Shared/Modules/CraftRules")
local RD = load("game/ReplicatedStorage/Shared/Data/RecipeData")
local MZ = load("game/ReplicatedStorage/Shared/Data/MiningZoneData")

local p = newPlayer(1, "Tester")
local d = PDS.Load(p)
d.Inventory = { BasicOre = 500, Coal = 500, ShadowDust = 100, RefinedOre = 500, EmberDust = 100 }

print("== tier progression (spec 3.2 / 4.1)")
local g, err = Golem.CraftGolem(p, "BP_Ember_T2", "default")
expect(g == nil, "T2 blocked at start (" .. tostring(err) .. ")")
expect(Golem.CraftGolem(p, "BP_Void_T1", "default") == nil, "Void T1 blocked until a Tier 2 exists")
for i = 1, 3 do g = Golem.CraftGolem(p, "BP_Ember_T1", "default") end
expect(d.CraftedByTier[1] == 3, "crafted counter tracks tiers")
d.Blueprints = d.Blueprints
g, err = Golem.CraftGolem(p, "BP_Ember_T2", "default")
expect(g == nil, "T2 still needs forge level 3 (" .. tostring(err) .. ")")
d.ForgeLevel = 3
Forge.GrantMilestoneBlueprints(p)
local has = {}
for _, id in ipairs(d.Blueprints) do has[id] = true end
expect(has.BP_Ember_T2 and has.BP_Stone_T2, "forge level 3 unlocks the Ember + Stone Tier 2 blueprints")
expect(not has.BP_Ember_T3, "Tier 3 blueprint not yet")
g, err = Golem.CraftGolem(p, "BP_Ember_T2", "default")
expect(g ~= nil, "Tier 2 craft works after 3x T1 + forge 3 (" .. tostring(err) .. ")")
expect(g and g.quality == 0.02, "quality bonus from Uncommon materials (" .. tostring(g and g.quality) .. ")")
expect(Golem.CraftGolem(p, "BP_Void_T1", "default") ~= nil, "Void T1 unlocked once a Tier 2 exists")

print("== material slots / max tier")
d.ForgeLevel = 1
expect(Rules.GetLockReason(d, RD.Get("BP_Ember_T2")) ~= nil, "forge 1 can't craft Tier 2")
expect((Rules.GetLockReason(d, RD.Get("BP_Ember_T2")) or ""):find("Forge Level 3"), "reason names the level")

print("== event golems only in their window")
d.ForgeLevel = 10
local bpEvent = RD.Get("BP_Season3_ThunderColossus")
expect(Rules.GetLockReason(d, bpEvent, {}) ~= nil, "event golem locked with no live event")
local avail = Season.GetAvailableEventBlueprints()
advance(SD.Seasons.Season3.startTimestamp + 10 * 86400 - os.time())   -- week 2 of Season3
avail = Season.GetAvailableEventBlueprints()
expect(avail.BP_Season3_ThunderColossus == true, "Season 3 event golem is on offer in week 2")
advance(-10 * 86400 + 2 * 86400)                                       -- back to week 1
avail = Season.GetAvailableEventBlueprints()
expect(next(avail) == nil, "not available in week 1")

print("== event golem stats (element All) don't crash")
local st = GD.ComputeStats("All", 5)
expect(st and st.miningRate > 0, "Primordial golem has stats")

print("== smelting time & XP")
d.ForgeLevel = 1
d.Inventory.BasicOre = 100
local job = Forge.StartSmelt(p, "BasicOre", 100)
expect(job and job.duration == 300 * 10, "100 ore = 10 batches of 5 min = 50 min (" .. tostring(job and job.duration) .. ")")
expect((d.Inventory.BasicOre or 0) == 0, "ore consumed")
local xpBefore = d.PlayerXP
advance(job.duration + 5)
Forge.TickSmeltJobs(p)
expect(d.PlayerXP > xpBefore, "smelting gives Player XP too")
expect((d.Inventory.RefinedOre or 0) >= 100, "refined ore delivered")

print("== queue size (spec 4.2: 5 at base)")
d.Inventory.BasicOre = 500
local made = 0
for i = 1, 8 do if Forge.StartSmelt(p, "BasicOre", 1) then made += 1 end end
expect(made == 5, "5 simultaneous smelts at forge level 1 (" .. made .. ")")

print("== Storm boosts the crew")
local d2 = { Golems = {
    { deployed = true, element = "Ember", tier = 1, zoneId = "EmberDepths", _durabilitySeconds = 1e9 },
}, ForgeLevel = 1, MasteryLevels = {}, Inventory = {}, Blueprints = {}, StorageTier = 0 }
local totalBefore = 0
d2.Golems[1]._accumulatedResources = 0; d2.Golems[1]._carriedResources = 0
local gains1 = Idle.TickOnlineProduction(d2, 60)
for _, v in pairs(gains1) do if type(v) == "number" then totalBefore += v end end
table.insert(d2.Golems, { deployed = true, element = "Storm", tier = 2, zoneId = "StormriftCliffs", _durabilitySeconds = 1e9 })
d2.Golems[1]._accumulatedResources = 0; d2.Golems[1]._carriedResources = 0
local gains2, byEl = Idle.TickOnlineProduction(d2, 60)
expect((byEl.Ember or 0) > totalBefore, "Ember Golem mines more with a Storm Golem deployed (" .. totalBefore .. " -> " .. tostring(byEl.Ember) .. ")")

print("== full carry waits instead of undeploying")
local cap = GD.ComputeStats("Ember", 1).carryCapacity
d2.Golems[1]._carriedResources = cap
Idle.TickOnlineProduction(d2, 60)
expect(d2.Golems[1].deployed == true and d2.Golems[1]._carriedResources == cap, "full golem stays deployed and stops")

print("== rare blueprint drops")
local d3 = { Blueprints = { "BP_Ember_T1" }, ForgeLevel = 10 }
local realMath = math
math = setmetatable({ random = function() return 0 end }, { __index = realMath })   -- force the roll to succeed
local found = Idle.RollBlueprintDrop(d3, 1000, 0.1)
math = realMath
expect(found ~= nil and not found:find("Season") , "a non-event blueprint is discovered: " .. tostring(found))
expect(#d3.Blueprints == 2, "it is added to the player's blueprints")

print("== Shadow Dust reachable outside the Hollow")
local seen = false
for _, id in ipairs({ "GraniteCaverns", "GlacialPeaks", "StormriftCliffs" }) do
    for _, e in ipairs(MZ.Zones[id].dropTable) do if e.materialId == "ShadowDust" then seen = true end end
end
expect(seen, "Shadow Dust drops in the starter zones")

print("== level rewards")
local p2 = newPlayer(2, "Leveler"); local dl = PDS.Load(p2)
local leveled, lvl = Prog.AddPlayerXP(p2, 100000)
expect(leveled and lvl >= 20, "big XP grant levels up (" .. tostring(lvl) .. ")")
local owned = {}
for _, id in ipairs(dl.OwnedCosmetics) do owned[id] = true end
expect(owned.TitleBadge_Apprentice and owned.ForgeSkin_Bronze and owned.GolemAccessory_MinerHelm, "cosmetic rewards for every level passed")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
