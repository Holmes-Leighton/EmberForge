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

print("== node maturity")
local H = 3600
local function node(age) return { id = "StoneNode", x = 10, z = 10, rot = 0, born = 1000000 - age * H } end
local now = 1000000
local function stageOf(age) return (QD.NodeStageAt(node(age), now)).id end
expect(stageOf(0) == "Budding" and stageOf(23.9) == "Budding" and stageOf(24) == "Mature" and stageOf(71.9) == "Mature" and stageOf(72) == "Prime" and stageOf(500) == "Prime", "Budding, Mature after a day, Prime after three")
local _, idx, prog, left = QD.NodeStageAt(node(12), now)
expect(idx == 1 and math.abs(prog - 0.5) < 1e-9 and math.abs(left - 12) < 1e-9, "12 hours in is halfway to Mature")
local _, _, _, leftPrime = QD.NodeStageAt(node(100), now)
expect(leftPrime == nil, "a Prime node has nothing left to grow")
expect(QD.NodeStageAt({ id = "StoneNode" }, now).mult == 1.0, "a node with no birth time counts as plain")
local function rate(age) return QD.RatesPerHour({ node(age) }, { now = now }).GraniteShard end
expect(math.abs(rate(1) - 90) < 1e-6 and math.abs(rate(30) - 117) < 1e-6 and math.abs(rate(80) - 144) < 1e-6, "output is x1.0 / x1.3 / x1.6 (" .. rate(1) .. ", " .. rate(30) .. ", " .. rate(80) .. ")")
-- a long absence that crosses a stage is paid fairly: the average of what the node was doing
local n = node(0)
local avg = QD.NodeMultOver(n, now, now + 48 * H)             -- 24h Budding (x1.0) then 24h Mature (x1.3)
expect(math.abs(avg - 1.15) < 1e-9, "48 hours across a stage change averages x1.15 (" .. avg .. ")")
expect(math.abs(QD.NodeMultOver(n, now, now + 12 * H) - 1.0) < 1e-9, "a span inside one stage is that stage's multiplier")
-- the cap
local big = QD.RatesPerHour({ node(100), { id = "DrillRig", x = 14, z = 10, rot = 0 } }, { now = now, crew = 2.0 }).GraniteShard
expect(math.abs(big - 90 * QD.OUTPUT_CAP) < 1e-6, "Prime x drill x full crew is capped at x" .. QD.OUTPUT_CAP .. " (" .. big .. ")")
local nocrew = QD.RatesPerHour({ node(100), { id = "DrillRig", x = 14, z = 10, rot = 0 } }, { now = now }).GraniteShard
expect(math.abs(nocrew - 90 * 1.6 * 1.35) < 1e-6, "below the cap everything multiplies")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
