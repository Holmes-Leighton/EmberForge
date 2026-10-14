QUIET = true
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local GS = load("SSS/EmberForge/Services/GolemService")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")

print("== repairing Golems")
local p = newPlayer(1, "Smith"); local d = PDS.Load(p)
local tier1 = GD.Tiers[1]
local max = tier1.durabilityHours * 3600
local g = { id = "g1", blueprintId = "BP_Ember_T1", element = "Ember", tier = 1, deployed = true, zoneId = "EmberDepths",
    _durabilitySeconds = 0, _maxDurabilitySeconds = max }
table.insert(d.Golems, g)

local cost = GS.RepairCost(g)
expect(cost and #cost == #tier1.materialsRequired, "a repair costs some of each craft material")
local ok = true
for i, req in ipairs(cost) do if req.qty ~= math.max(1, math.ceil(tier1.materialsRequired[i].qty * 0.2)) then ok = false end end
expect(ok, "20% of the craft cost, rounded up")

d.Inventory = {}
local r, why = GS.RepairGolem(p, "g1")
expect(r == false and why:find("^Insufficient materials") ~= nil and why:find("Repair needs") ~= nil and why:find("you have 0") ~= nil, "can't repair without the materials, and it says what is missing (" .. tostring(why) .. ")")
expect(g._durabilitySeconds == 0, "and nothing changes")

for _, req in ipairs(cost) do d.Inventory[req.id] = req.qty end
local r2 = GS.RepairGolem(p, "g1")
expect(r2 == true and g._durabilitySeconds == max, "a deployed, broken Golem is repaired where it stands")
expect(g.deployed == true, "and stays deployed (it carries on working)")
for _, req in ipairs(cost) do expect((d.Inventory[req.id] or 0) == 0, req.id .. " was spent") end

local r3, why3 = GS.RepairGolem(p, "g1")
expect(r3 == false and why3:find("doesn't need"), "a fresh Golem can't be 'repaired' (no wasted materials): " .. tostring(why3))
expect(GS.RepairGolem(p, "nope") == false, "an unknown Golem is refused")

-- a resting (recalled) Golem is repaired the same way
g.deployed, g._durabilitySeconds = false, max * 0.1
for _, req in ipairs(cost) do d.Inventory[req.id] = req.qty end
expect(GS.RepairGolem(p, "g1") == true and g._durabilitySeconds == max, "a Golem resting in the Forge can still be repaired")
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
