QUIET = true
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local QS = load("SSS/EmberForge/Services/QuarryService")
local FZ = load("SSS/EmberForge/Services/ForgeZoneService")

print("== quarry visitor summary")
local owner = newPlayer(1, "Owner"); local od = PDS.Load(owner)
od.EmberCoins, od.ForgeLevel = 1000000, 6
local visitor = newPlayer(2, "Visitor"); PDS.Load(visitor)
expect(FZ.QuarrySummary(1, visitor) == nil, "no summary before the Quarry is founded")
QS.Found(owner)
QS.Place(owner, "EmberNode", 10, 10)
QS.Place(owner, "FrostNode", -10, 10)
QS.Place(owner, "DrillRig", 0, -10)
local s = FZ.QuarrySummary(1, visitor)
expect(s and s.name == "Owner" and s.level == 1 and s.nodes == 2 and s.helpers == 1, "summary counts nodes and helpers")
expect(s.byElement.Ember == 1 and s.byElement.Frost == 1, "and nodes by element")
expect(s.maxNodes == 6 and s.crew == 0, "plus the Core's node limit and crew size")
expect(s.coins == nil and s.inventory == nil, "nothing private is included")
od.Settings = { ForgeFriendsOnly = true }
expect(FZ.QuarrySummary(1, visitor) == nil, "a friends-only owner shows strangers nothing (the mock has no friends)")
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
