QUIET = true
-- Quarry service: founding, building, mining over time, storage limits, collecting and upgrading.
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local QS = load("SSS/EmberForge/Services/QuarryService")
local QD = load("game/ReplicatedStorage/Shared/Data/QuarryData")

local function mk(id, coins, forge)
    local p = newPlayer(id, "Q" .. id)
    local d = PDS.Load(p)
    d.EmberCoins, d.ForgeLevel = coins or 1000000, forge or 6
    return p, d
end

print("== founding")
local a, da = mk(1)
local low = mk(2, 1000000, 3)
local okL, eL = QS.Found(low)
expect(not okL and eL:find("Level 6"), "needs Forge Level 6 (" .. tostring(eL) .. ")")
local poor = mk(3, 100, 6)
expect(not QS.Found(poor), "needs the coins")
expect(QS.Found(a) and da.EmberCoins == 1000000 - QD.CORE_COST and da.Quarry.level == 1, "founding costs " .. QD.CORE_COST .. " and starts at Core level 1")
expect(not QS.Found(a), "only one Quarry")
expect(not QS.Place(low, "EmberNode", 10, 10), "no building before founding")

print("== building")
local c0 = da.EmberCoins
expect(QS.Place(a, "EmberNode", 10, 10) and da.EmberCoins == c0 - 4000, "a node costs its price")
expect(not QS.Place(a, "EmberNode", 10, 10), "pieces can't overlap")
expect(not QS.Place(a, "EmberNode", 1, 1), "the Core's spot stays clear")
expect(not QS.Place(a, "EmberNode", 40, 0), "outside the Quarry is refused")
expect(not QS.Place(a, "Core", 15, 15) and not QS.Place(a, "Nope", 15, 15), "no second Core, no unknown pieces")
expect(not QS.Place(a, "EmberNode", 0 / 0, 5), "NaN refused")
for i = 1, 5 do QS.Place(a, "StoneNode", -20 + i * 6, -20) end
local okN, eN = QS.Place(a, "FrostNode", 20, 20)
expect(not okN and eN:find("supports 6 nodes"), "a level 1 Core supports 6 nodes (" .. tostring(eN) .. ")")
expect(QS.Place(a, "CoolingPool", 18, 10) and QS.Place(a, "Silo", -10, 15), "helpers are not limited by the node count")

print("== mining over time")
local b, db = mk(10)
QS.Found(b)
QS.Place(b, "EmberNode", 10, 10)
QS.Place(b, "CoolingPool", 14, 10)
advance(3600)
local snap = QS.Snapshot(b)
expect(snap.stored.TemperedEmber == QD.EXCLUSIVE_RATE, "an hour of Ember node + Cooling Pool = " .. QD.EXCLUSIVE_RATE .. " Tempered Ember (" .. tostring(snap.stored.TemperedEmber) .. ")")
advance(36 * 3600)
snap = QS.Snapshot(b)
expect(snap.stored.TemperedEmber <= QD.EXCLUSIVE_RATE * (QD.MAX_OFFLINE_HOURS + 1) + 1, "mining stops after " .. QD.MAX_OFFLINE_HOURS .. " hours unattended (" .. tostring(snap.stored.TemperedEmber) .. ")")
local got = QS.Collect(b)
expect(got and got.TemperedEmber and db.Inventory.TemperedEmber == got.TemperedEmber, "collecting moves it to your inventory")
local none, eNone = QS.Collect(b)
expect(none == nil and eNone == "The silo is empty", "an empty silo has nothing to collect")

print("== storage limit")
local c, dc = mk(20)
QS.Found(c)
for i = 1, 6 do QS.Place(c, "StoneNode", -22 + i * 7, -20) end
advance(12 * 3600)
local s2 = QS.Snapshot(c)
expect(s2.storedTotal <= QD.BASE_STORAGE, "the silo never holds more than its capacity (" .. s2.storedTotal .. "/" .. s2.capacity .. ")")
QS.Place(c, "Silo", 20, 20)
advance(12 * 3600)
local s3 = QS.Snapshot(c)
expect(s3.capacity == QD.BASE_STORAGE + QD.SILO_STORAGE and s3.storedTotal > s2.storedTotal, "a Silo raises the limit and lets it fill further")

print("== layout changes do not rewrite the past")
local e, de = mk(30)
QS.Found(e)
QS.Place(e, "StoneNode", 10, 10)
advance(3600)
QS.Place(e, "StoneNode", -10, 10)               -- added after the first hour
advance(3600)
local s4 = QS.Snapshot(e)
expect(s4.stored.GraniteShard == 90 + 180, "hour 1 at one node, hour 2 at two nodes (" .. tostring(s4.stored.GraniteShard) .. ")")
local before = de.EmberCoins
expect(QS.Remove(e, 3) and de.EmberCoins == before + 1500, "removing a piece refunds half")
expect(not QS.Remove(e, 1), "the Core can't be removed")

print("== core upgrades")
local f, df = mk(40)
QS.Found(f)
local okU, eU = QS.UpgradeCore(f)
expect(not okU and eU:find("Stormglass") or eU:find("Tempered Ember"), "upgrading needs Quarry materials (" .. tostring(eU) .. ")")
df.Inventory.TemperedEmber, df.Inventory.Stormglass = 50, 45
local okU2, lvl = QS.UpgradeCore(f)
expect(okU2 and lvl == 2 and df.Inventory.TemperedEmber == 10 and df.Inventory.Stormglass == 5, "level 2 costs 40 + 40 and is applied")
expect(QS.Snapshot(f).nodeLimit == 9, "level 2 supports 9 nodes")
df.Inventory = { TemperedEmber = 300, Stormglass = 300, FrostfireGem = 300, Voidstone = 300, PrismaticShard = 300 }
QS.UpgradeCore(f) QS.UpgradeCore(f)
local top, eTop = QS.UpgradeCore(f)
expect(not top and eTop:find("highest") and df.Quarry.level == 4, "the Core tops out at level 4")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
