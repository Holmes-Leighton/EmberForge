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
print("== auto-repair")
local GM = load("game/ReplicatedStorage/Shared/Modules/GolemMotion")
local p2 = newPlayer(2, "Mender"); local d2 = PDS.Load(p2)
local function worn(id, fraction, deployed)
    local gg = { id = id, blueprintId = "BP_Ember_T1", element = "Ember", tier = 1, deployed = deployed ~= false, zoneId = "EmberDepths",
        _durabilitySeconds = max * fraction, _maxDurabilitySeconds = max }
    table.insert(d2.Golems, gg)
    return gg
end
local function stock(n)
    for _, req in ipairs(cost) do d2.Inventory[req.id] = (d2.Inventory[req.id] or 0) + req.qty * n end
end
expect(GS.AutoRepairOn(d2), "auto-repair is on for a new player")
local tired = worn("a1", 0.2)
local fresh = worn("a2", 0.9)
local resting = worn("a3", 0.1, false)
d2.Inventory = {}
expect(#GS.AutoRepair(p2) == 0 and tired._durabilitySeconds == max * 0.2, "without the materials nothing is repaired (it falls back to the old way)")
stock(1)
local done = GS.AutoRepair(p2)
expect(#done == 1 and done[1].golem == tired, "a tired deployed Golem is repaired (" .. #done .. ")")
expect(tired._durabilitySeconds == max, "back to full")
expect(fresh._durabilitySeconds == max * 0.9, "a Golem that is not tired is left alone")
expect(resting._durabilitySeconds == max * 0.1, "and so is one resting in the forge")
local spent = true
for _, req in ipairs(cost) do if (d2.Inventory[req.id] or 0) ~= 0 then spent = false end end
expect(spent, "it cost exactly what a manual repair costs")
expect(#GS.AutoRepair(p2) == 0, "and does nothing again until the Golem is worn once more")
local t2, t3 = worn("a4", 0.05), worn("a5", 0.0)
stock(2)
expect(#GS.AutoRepair(p2) == 2 and t2._durabilitySeconds == max and t3._durabilitySeconds == max, "several tired Golems are all repaired, one after another")
local t4, t5 = worn("a6", 0.1), worn("a7", 0.1)
stock(1)
local partial = GS.AutoRepair(p2)
expect(#partial == 1, "with materials for only one, one is repaired and the other waits (" .. #partial .. ")")
expect(GS.SetAutoRepair(p2, false) == true and not GS.AutoRepairOn(d2), "it can be turned off")
local t6 = worn("a8", 0.1)
stock(1)
expect(#GS.AutoRepair(p2) == 0 and t6._durabilitySeconds == max * 0.1, "off means nothing is repaired for you")
expect(GS.SetAutoRepair(p2, "yes") == false and not GS.AutoRepairOn(d2), "only true or false is accepted")
GS.SetAutoRepair(p2, true)
expect(#GS.AutoRepair(p2) == 1, "and back on it repairs again")
local atLow = worn("a9", GM.LOW)
stock(3)                                                    -- (the one left waiting earlier is repaired too)
GS.AutoRepair(p2)
expect(atLow._durabilitySeconds == max, "the tired mark itself counts (" .. GM.LOW .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
