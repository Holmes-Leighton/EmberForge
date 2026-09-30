QUIET = true
-- Special Golems (skills), pets (hatch / equip / merge / odds), Robux eggs and Elite/Supreme names.
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify", "LevelUp", "ForgeUpgraded", "PetHatched", "PetsMerged" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local GS = load("SSS/EmberForge/Services/GolemService")
local PS = load("SSS/EmberForge/Services/PetService")
local IE = load("SSS/EmberForge/Services/IdleEngine")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")
local RD = load("game/ReplicatedStorage/Shared/Data/RecipeData")
local PD = load("game/ReplicatedStorage/Shared/Data/PetData")
local PR = load("game/ReplicatedStorage/Shared/Data/ProductData")
local Names = load("game/ReplicatedStorage/Shared/Modules/GolemNames")

print("== special Golem types exist with skills and blueprints")
local n = 0
for _, id in ipairs(GD.SpecialOrder) do
    n += 1
    local def = GD.Specials[id]
    expect(GD.Elements[id] and GD.Elements[id].special and def.skill and def.skill.params, id .. " is an element-style entry with a skill")
    expect(GD.ElementMultipliers[id] ~= nil, id .. " has stat multipliers")
    local bp = RD.GetForElement(id, def.tier)
    expect(bp ~= nil and bp.element == id, id .. " has a blueprint at tier " .. def.tier)
end
expect(n == 8, "eight special types")
local d1 = Names.Describe({ element = "StormJar", tier = 4 })
expect(d1.name == "Storm in a Jar Golem" and d1.rarity == "Epic", "special Golems are named '<Name> Golem' with their tier's rarity (" .. d1.name .. ")")

print("== skills change mining")
local function mk(el, tier) return { id = el, element = el, tier = tier, deployed = true, zoneId = "EmberDepths", quality = 0,
    _durabilitySeconds = 1e9, _maxDurabilitySeconds = 1e9, _carriedResources = 0, _accumulatedResources = 0 } end
local function data(golems, pets, worn) return { Golems = golems, ForgeLevel = 1, MasteryLevels = {}, Blueprints = {}, Inventory = {},
    StorageTier = 0, OwnedPets = pets or {}, EquippedPets = worn or {} } end
local function produced(g, pd) IE.TickOnlineProduction(pd or data({ g }), 5) return g._carriedResources + g._accumulatedResources end
local function rate(el, tier)
    local s = GD.ComputeStats(el, tier, nil, 0)
    return s.miningRate * s.efficiency * (load("game/ReplicatedStorage/Shared/Data/GameConfig").ONLINE_PRODUCTION_SPEED or 1) * (5 / 3600)
end
local clock = mk("Clockwork", 3)
expect(math.abs(produced(clock) / rate("Clockwork", 3) - 1.25) < 0.01, "Clockwork Overclock: +25% mining speed")
local garg = mk("Gargoyle", 3)
expect(math.abs(produced(garg) / rate("Gargoyle", 3) - 0.9) < 0.01, "Gargoyle is 10% slower while you play")
local patch = mk("Patchwork", 2); patch._durabilitySeconds = 1e6
IE.TickOnlineProduction(data({ patch }), 1000)
expect(math.abs((1e6 - patch._durabilitySeconds) - 400) < 1, "Patchwork wears 60% slower (" .. (1e6 - patch._durabilitySeconds) .. "s for 1000s)")
local clk = mk("Clockwork", 3); clk._durabilitySeconds = 1e6
IE.TickOnlineProduction(data({ clk }), 1000)
expect(math.abs((1e6 - clk._durabilitySeconds) - 1250) < 1, "Clockwork wears 25% faster")
local ember = mk("Ember", 1); ember._durabilitySeconds = 1e6
IE.TickOnlineProduction(data({ ember, mk("StormJar", 4), mk("StormJar", 4) }), 1000)
expect(math.abs((1e6 - ember._durabilitySeconds) - 800) < 1, "two Storm in a Jar shelter others: 20% less wear")
local a = IE.CrewAuras(data({ mk("Coral", 3), mk("Coral", 3), mk("Coral", 3), mk("Coral", 3), mk("Coral", 3), mk("Dragonbone", 4) }))
expect(math.abs(a.luck - 0.20) < 1e-9 and math.abs(a.blueprint - 2.0) < 1e-9, "Coral luck aura caps at +20%; Dragonbone doubles blueprint finds")

print("== special Golems craft and Elite-fuse like any other")
local p = newPlayer(1, "Sam")
local d = PDS.Load(p)
d.ForgeLevel = 10; d.CraftedByTier = { [1] = 10, [2] = 10, [3] = 10 }
d.Blueprints = { "BP_Patchwork_T2" }
d.Inventory = { RefinedOre = 500, ElementalIngot = 500 }
local crafted
for i = 1, 4 do crafted = GS.CraftGolem(p, "BP_Patchwork_T2", "default") end
expect(crafted and crafted.element == "Patchwork" and crafted.rarity == "Uncommon", "Patchwork crafts as an Uncommon")
local elite, err = GS.NeonFuse(p, "Patchwork", 2, nil)
expect(elite and elite.variant == "Neon", "4 Patchwork fuse into a Neon (shown to players as Elite): " .. tostring(err))
expect(Names.Describe(elite).name:find("Elite") ~= nil, "the variant is shown as Elite (" .. Names.Describe(elite).name .. ")")
expect(GD.Variants.MegaNeon.label == "Supreme" and PD.Variants.MegaNeon.label == "Supreme", "Mega Neon is labelled Supreme for Golems and pets")

print("== pet egg odds")
for _, eggId in ipairs(PD.EggOrder) do
    local total = 0
    for _, o in ipairs(PD.Odds(eggId)) do total += o.chance end
    expect(math.abs(total - 1) < 1e-9, eggId .. " egg odds sum to 100%")
end
local crystal = {}
for _, o in ipairs(PD.Odds("Crystal")) do crystal[o.type] = o.chance end
expect(crystal.All < 0.00002 and crystal.All > 0.000005, "Legendary is ~0.001% in the Crystal egg (" .. PD.FormatOdds(crystal.All) .. ")")
expect(crystal.Dragonbone < 0.001 and crystal.Coral < 0.05 and crystal.Coral > crystal.Dragonbone * 10, "each rarity step is far rarer than the last")
local royal = PD.Odds("Royal")
local rareOrBetter = true
for _, o in ipairs(royal) do if PD.Pets[o.type].rarity == "Common" or PD.Pets[o.type].rarity == "Uncommon" then rareOrBetter = false end end
expect(rareOrBetter, "Royal Egg only contains Rare pets or better")
expect(PD.FormatOdds(0.00001) == "0.001% (1 in 100,000)" and PD.FormatOdds(0.26) == "26%", "odds text: " .. PD.FormatOdds(0.00001))

print("== hatching, wearing, merging pets")
d.EmberCoins = 1000
local pet, herr = PS.Hatch(p, "Basic")
expect(pet and d.EmberCoins == 850 and #d.OwnedPets == 1 and #d.EquippedPets == 1, "coin hatch costs 150 and equips the first pet")
local _, rerr = PS.Hatch(p, "Royal")
expect(rerr == "That egg is bought with Robux" and d.EmberCoins == 850, "coins can't hatch a Robux egg")
d.OwnedPets, d.EquippedPets = {}, {}
for i = 1, 5 do table.insert(d.OwnedPets, { id = "e" .. i, type = "Ember", hatchedAt = i }) end
table.insert(d.EquippedPets, "e1")
expect(PS.Equip(p, "e2", true) and #d.EquippedPets == 2, "wear a second pet")
local _, eqerr = PS.Equip(p, "e3", true)
expect(eqerr ~= nil and #d.EquippedPets == 2, "only 2 pets can be worn")
PS.Equip(p, "e2", false)
local m1 = PS.Merge(p, "Ember", nil)
expect(m1 and m1.variant == "Neon" and #d.OwnedPets == 2, "4 identical pets merge into a Neon pet (Elite), leaving the 5th")
local worn = {}
for _, id in ipairs(d.EquippedPets) do worn[id] = true end
local keptWorn = false
for _, pp in ipairs(d.OwnedPets) do if worn[pp.id] and pp.variant == nil then keptWorn = true end end
expect(keptWorn, "spare pets are used up before the worn one")
local _, merr = PS.Merge(p, "Coral", nil)
expect(merr ~= nil, "merging needs four")
for i = 1, 3 do table.insert(d.OwnedPets, { id = "n" .. i, type = "Ember", variant = "Neon", hatchedAt = 10 + i }) end
local m2 = PS.Merge(p, "Ember", "Neon")
expect(m2 and m2.variant == "MegaNeon", "4 Elite pets merge into a Supreme")
local _, m3err = PS.Merge(p, "Ember", "MegaNeon")
expect(m3err ~= nil, "a Supreme pet can't merge further")
local b = PD.Boosts({ OwnedPets = { { id = "x", type = "Clockwork", variant = "MegaNeon" } }, EquippedPets = { "x" } })
expect(math.abs(b.rate - 0.10) < 1e-9, "a Supreme Clockwork pet gives +10% mining (double the plain +5%)")
local many, ids = {}, {}
for i = 1, 6 do many[i] = { id = "m" .. i, type = "Clockwork" } ids[i] = "m" .. i end
expect(PD.Boosts({ OwnedPets = many, EquippedPets = ids }).rate == PD.STAT_CAP, "pet boosts cap at +20% per stat")

print("== pets boost mining")
local g1, g2 = mk("Stone", 1), mk("Stone", 1)
IE.TickOnlineProduction(data({ g1 }), 5)
IE.TickOnlineProduction(data({ g2 }, { { id = "a", type = "Clockwork" } }, { "a" }), 5)
local r1, r2 = g1._carriedResources + g1._accumulatedResources, g2._carriedResources + g2._accumulatedResources
expect(math.abs(r2 / r1 - 1.05) < 0.005, "a worn Clockwork pet adds +5% mining (" .. string.format("%.3f", r2 / r1) .. ")")

print("== Robux eggs")
local keys = {}
for key, prod in pairs(PR.Products) do if prod.eggId then keys[#keys + 1] = key end end
expect(#keys == 3, "three Royal Egg bundles are sold")
local paid = PS.HatchPaid(p, "Royal", 5)
expect(#paid == 5, "a 5-egg bundle hatches five pets")
local allRare = true
for _, pp in ipairs(paid) do if PD.Pets[pp.type].rarity == "Common" or PD.Pets[pp.type].rarity == "Uncommon" then allRare = false end end
expect(allRare, "every Royal pet is Rare or better")
d.OwnedPets = {}
for i = 1, PD.MAX_OWNED do d.OwnedPets[i] = { id = "f" .. i, type = "Ember" } end
expect(#PS.HatchPaid(p, "Royal", 1) == 1, "a paid hatch is never refused, even with a full pet box")
d.EmberCoins = 1000
local _, fullerr = PS.Hatch(p, "Basic")
expect(fullerr ~= nil, "a coin hatch is refused when the box is full")

print("== special Golems in the unique-body pack config")
local AD = load("game/ReplicatedStorage/Shared/Data/AssetData")
local entries = AD.PackEntries()
expect(entries.Dragonbone and entries.Dragonbone.height == 13 and entries.Patchwork.height == 7.5, "each type has its own height in the pack config")
expect(entries.Ember.elementTint == 0, "a type's own model is never element-tinted")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
