QUIET = true
-- Quarry rules: what each layout produces.
local QD = load("game/ReplicatedStorage/Shared/Data/QuarryData")
local MD = load("game/ReplicatedStorage/Shared/Data/MaterialData")

local function at(id, x, z) return { id = id, x = x, z = z, rot = 0 } end
local function mats(placed) local r = {} for _, p in ipairs(QD.Production(placed)) do r[#r + 1] = p.material end table.sort(r) return table.concat(r, ",") end

print("== plain nodes")
expect(mats({ at("EmberNode", 10, 10) }) == "IgniteOre", "an Ember node alone mines Ignite Ore")
expect(QD.RatesPerHour({ at("StoneNode", 10, 10) }).GraniteShard == 90, "a Granite Vein makes 90 Granite Shards per hour")

print("== exclusive recipes")
expect(mats({ at("EmberNode", 10, 10), at("CoolingPool", 14, 10) }) == "TemperedEmber", "Ember node + Cooling Pool = Tempered Ember")
expect(mats({ at("EmberNode", 10, 10), at("CoolingPool", 60, 10) }) == "IgniteOre", "a Cooling Pool that is too far away does nothing")
expect(mats({ at("StormNode", 0, 10), at("SkySpire", 8, 10) }) == "Stormglass", "Storm node + Sky Spire = Stormglass")
expect(mats({ at("FrostNode", 0, 10), at("EmberNode", 6, 10) }) == "FrostfireGem,FrostfireGem", "Frost + Ember nodes together both make Frostfire Gems")
expect(mats({ at("VoidNode", 0, 10), at("StoneNode", 6, 10) }) == "Voidstone,Voidstone", "Void + Stone nodes together both make Voidstone")
local prism = { at("EmberNode", 5, 5), at("FrostNode", 15, 5), at("StormNode", 5, 15), at("PrismCluster", 10, 10) }
local r = QD.RatesPerHour(prism)
expect(r.PrismaticShard == 3 * QD.EXCLUSIVE_RATE, "three different nodes around a Prism Cluster make Prismatic Shards (" .. tostring(r.PrismaticShard) .. ")")
expect(mats({ at("EmberNode", 5, 5), at("EmberNode", 15, 5), at("EmberNode", 5, 15), at("PrismCluster", 10, 10) }):find("Prismatic") == nil, "three of the SAME node do not")

print("== boosts and storage")
local base = QD.RatesPerHour({ at("EmberNode", 10, 10) }).IgniteOre
local drilled = QD.RatesPerHour({ at("EmberNode", 10, 10), at("DrillRig", 14, 10) }).IgniteOre
expect(math.abs(drilled / base - 1.35) < 1e-9, "a Drill Rig makes nearby nodes 35% faster")
local twoDrills = QD.RatesPerHour({ at("EmberNode", 10, 10), at("DrillRig", 14, 10), at("DrillRig", 6, 10) }).IgniteOre
expect(twoDrills == drilled, "Drill Rigs do not stack")
expect(QD.Capacity({}, 1) == 600 and QD.Capacity({ at("Silo", 0, 0), at("Silo", 9, 0) }, 1) == 1400 and QD.Capacity({}, 2) == 900, "storage grows with Silos and Core level")

print("== it is all reachable")
local maxNodes = QD.CoreLevels[#QD.CoreLevels].nodes
expect(maxNodes >= 12, "the top Core allows " .. maxNodes .. " nodes")
for id, def in pairs(QD.Pieces) do
    expect(def.height > 0 and (def.kind == "core" or def.price > 0), id .. " has a size and a price")
end
local reachable = {}
for _, r2 in ipairs({ "TemperedEmber", "Stormglass", "FrostfireGem", "Voidstone", "PrismaticShard" }) do reachable[r2] = false end
for _, layout in ipairs({
    { at("EmberNode", 10, 10), at("CoolingPool", 14, 10) }, { at("StormNode", 0, 10), at("SkySpire", 8, 10) },
    { at("FrostNode", 0, 10), at("EmberNode", 6, 10) }, { at("VoidNode", 0, 10), at("StoneNode", 6, 10) }, prism }) do
    for m in pairs(QD.RatesPerHour(layout)) do if reachable[m] ~= nil then reachable[m] = true end end
end
for m, ok in pairs(reachable) do expect(ok and MD.Get(m) ~= nil and MD.Get(m).tradeable, m .. " can be made and traded") end
for _, lv in ipairs(QD.CoreLevels) do
    for m in pairs(lv.cost or {}) do expect(reachable[m] ~= nil, "Core level " .. lv.level .. " only needs Quarry materials (" .. m .. ")") end
end

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
