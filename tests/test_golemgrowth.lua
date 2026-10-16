QUIET = true
-- Golem growth: life stages, stat scaling, growth while working (online and offline), fusion, trading value and old saves.
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify", "LevelUp", "ForgeUpgraded" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local GS = load("SSS/EmberForge/Services/GolemService")
local IE = load("SSS/EmberForge/Services/IdleEngine")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")
local Names = load("game/ReplicatedStorage/Shared/Modules/GolemNames")
local Trading = load("SSS/EmberForge/Services/TradingService")
local LO = load("SSS/EmberForge/Services/LiveOpsService")
LO.HourlyEnabled = false

local H = 3600
local function mk(id)
    local p = newPlayer(id, "G" .. id)
    local d = PDS.Load(p)
    d.Inventory = { BasicOre = 1000, Coal = 1000 }
    return p, d
end

print("== stages")
local function stageAt(hours) return GD.StageOf({ grown = hours * H }) end
expect(stageAt(0).id == "Infant" and stageAt(0.9).id == "Infant" and stageAt(1).id == "Young", "Infant for the first hour, then Young")
expect(stageAt(7.9).id == "Young" and stageAt(8).id == "Adult" and stageAt(47.9).id == "Adult", "Young to 8h, Adult to 48h")
expect(stageAt(48).id == "Elder" and stageAt(239.9).id == "Elder" and stageAt(240).id == "Ancient" and stageAt(9999).id == "Ancient", "Elder from 48h, Ancient from 240h")
local _, idx, prog, left = stageAt(4.5)
expect(idx == 2 and math.abs(prog - 0.5) < 1e-9 and math.abs(left - 3.5) < 1e-9, "4.5 hours in is halfway from Young to Adult, 3.5 hours to go")
local _, _, pa, la = stageAt(500)
expect(pa == 1 and la == nil, "an Ancient has nothing left to grow")
expect(GD.StageOf({}).id == "Adult", "a Golem from before growth (no record) counts as Adult")
expect(GD.StageById("Elder").id == "Elder" and GD.StageById(nil).id == "Adult" and GD.StageById("Bogus").id == "Adult", "unknown stage names fall back to Adult")
for i = 2, #GD.Stages do
    local a, b = GD.Stages[i - 1], GD.Stages[i]
    expect(b.at > a.at and b.mult > a.mult and b.scale > a.scale, a.id .. " -> " .. b.id .. ": later, stronger and bigger")
end
expect(GD.Stages[GD.ADULT_INDEX].mult == 1 and GD.Stages[GD.ADULT_INDEX].scale == 1 and GD.Stages[GD.ADULT_INDEX].head == 1, "Adult is exactly the old look and stats")

print("== stats follow the stage")
local adult = GD.ComputeStats("Ember", 2, nil, 0, nil, "Adult")
expect(GD.ComputeStats("Ember", 2, nil, 0, nil) .miningRate == adult.miningRate, "no stage given = Adult, so old callers are unchanged")
local inf, anc = GD.ComputeStats("Ember", 2, nil, 0, nil, "Infant"), GD.ComputeStats("Ember", 2, nil, 0, nil, "Ancient")
expect(math.abs(inf.miningRate / adult.miningRate - 0.70) < 0.01 and math.abs(anc.miningRate / adult.miningRate - 1.30) < 0.01, "Infant 70% and Ancient 130% of Adult mining")
expect(inf.durabilityHours == adult.durabilityHours, "stage does not change durability")
expect(GD.ComputeStats("Ember", 2, nil, 0, nil, "Ancient").miningRate < GD.ComputeStats("Ember", 3, nil, 0, nil, "Adult").miningRate,
    "a fully grown Tier 2 still does not beat an Adult Tier 3 (tier keeps mattering)")
expect(GD.ComputeStats("Ember", 5, nil, 0, nil, "Infant").miningRate > GD.ComputeStats("Ember", 4, nil, 0, nil, "Adult").miningRate * 0.9,
    "and an Infant Tier 5 is still a powerhouse")
local both = GD.ComputeStats("Ember", 2, nil, 0, "Neon", "Elder")
expect(math.abs(both.miningRate / adult.miningRate - 1.25 * 1.15) < 0.01, "variant and stage multiply")

print("== tier 5 is renamed so Ancient can be a stage")
expect(GD.Tiers[5].name == "Primordial Golem", "tier 5 is the Primordial Golem")
for _, t in ipairs(GD.Tiers) do expect(not t.name:find("Ancient"), t.name .. " does not clash with the Ancient stage") end

print("== crafting starts an Infant")
local p, d = mk(1)
local g = GS.CraftGolem(p, "BP_Ember_T1", "default")
expect(g and g.grown == 0 and GD.StageOf(g).id == "Infant", "a new Golem is an Infant")
local desc = Names.Describe(g)
expect(desc.stage.id == "Infant" and desc.stageIndex == 1 and desc.stageProgress == 0 and desc.stageHoursLeft == 1, "Describe carries the stage and progress")
expect(Names.Describe({ element = "Ember", tier = 1 }).stage.id == "Adult", "an old Golem describes as Adult")

print("== growing while working (online)")
g.deployed, g.zoneId = true, "EmberDepths"
local gains, byEl, grew = IE.TickOnlineProduction(d, 60)
expect(g.grown == 60 and #grew == 0, "a minute of work adds 60 seconds")
gains, byEl, grew = IE.TickOnlineProduction(d, 1 * H)
expect(#grew == 1 and grew[1].golem == g and grew[1].stage.id == "Young", "crossing an hour reports the new stage")
expect(GD.StageOf(g).id == "Young", "and the Golem is now Young")
g.deployed = false
local before = g.grown
IE.TickOnlineProduction(d, 600)
expect(g.grown == before, "an idle Golem does not grow")
g.deployed = true
g._durabilitySeconds = 0
IE.TickOnlineProduction(d, 600)
expect(g.grown == before, "a worn-out Golem does not grow")
g._durabilitySeconds = 1e9
g._carriedResources = 1e9
IE.TickOnlineProduction(d, 100)
expect(g.grown == before + 100, "a Golem with a full bag still grows while it waits to be collected")

print("== growing while away")
local po, dof = mk(2)
local og = { id = "o1", element = "Ember", tier = 1, deployed = true, zoneId = "EmberDepths", grown = 0 }
dof.Golems = { og }
dof.LastOnline = os.time() - 2 * H
IE.CalculateOfflineProduction(dof)
expect(math.abs(og.grown - 2 * H * GD.GROW_OFFLINE_RATE) < 5, "two hours away is one hour of growth (" .. tostring(og.grown) .. "s)")
local legacy = { id = "o2", element = "Ember", tier = 1, deployed = true, zoneId = "EmberDepths" }
dof.Golems = { legacy }
dof.LastOnline = os.time() - H
IE.CalculateOfflineProduction(dof)
expect(legacy.grown and math.abs(legacy.grown - (8 * H + H * GD.GROW_OFFLINE_RATE)) < 5, "an old Golem starts from Adult and keeps growing (" .. tostring(legacy.grown) .. "s)")
expect(GD.StageOf(legacy).id == "Adult", "and is still Adult")

print("== the Growth Tonic")
local Product = load("game/ReplicatedStorage/Shared/Data/ProductData")
local Shop = load("SSS/EmberForge/Services/ShopService")
local realTonicId = Product.Products.GrowthTonic_1h and Product.Products.GrowthTonic_1h.id
expect(realTonicId ~= nil and realTonicId ~= 0 and Product.IsAvailable("GrowthTonic_1h"), "the Tonic is for sale (its Developer Product id is set)")
local pt1, dt1 = mk(20)
local tg = { id = "t1", element = "Ember", tier = 1, deployed = true, zoneId = "EmberDepths", grown = 0 }
dt1.Golems = { tg }
IE.TickOnlineProduction(dt1, 100)
expect(tg.grown == 100, "without a Tonic: 100 seconds of work is 100 seconds of growth")
Product.Products.GrowthTonic_1h.id = 777
game:GetService("MarketplaceService").ProcessReceipt({ PlayerId = 20, ProductId = 777, PurchaseId = "tonic1" })
expect((dt1.GrowthBoostExpiry or 0) > os.time() + 3500, "buying the Tonic gives an hour of boosted growth")
game:GetService("MarketplaceService").ProcessReceipt({ PlayerId = 20, ProductId = 777, PurchaseId = "tonic2" })
expect((dt1.GrowthBoostExpiry or 0) > os.time() + 7100, "buying another extends it")
IE.TickOnlineProduction(dt1, 100)
expect(tg.grown == 300, "with a Tonic, 100 seconds of work is 200 seconds of growth")
dt1.GrowthBoostExpiry = os.time() - 1
IE.TickOnlineProduction(dt1, 100)
expect(tg.grown == 400, "an expired Tonic does nothing")
Product.Products.GrowthTonic_1h.id = realTonicId
-- away: the Tonic doubles only the part of the absence it covered
local po1, do1 = mk(21)
local ag = { id = "t2", element = "Ember", tier = 1, deployed = true, zoneId = "EmberDepths", grown = 0 }
do1.Golems = { ag }
do1.LastOnline = os.time() - 4 * H
do1.GrowthBoostExpiry = os.time() - 2 * H                     -- covered the first two of the four hours
IE.CalculateOfflineProduction(do1)
expect(math.abs(ag.grown - (4 + 2) * H * GD.GROW_OFFLINE_RATE) < 5, "four hours away, two of them under a Tonic = 3 hours of growth (" .. tostring(ag.grown / H) .. "h)")

print("== growing up while away is reported")
local pa1, da1 = mk(22)
local up = { id = "t3", element = "Frost", tier = 1, deployed = true, zoneId = "EmberDepths", grown = 0 }
local stay = { id = "t4", element = "Frost", tier = 1, deployed = true, zoneId = "EmberDepths", grown = 20 * H }
da1.Golems = { up, stay }
da1.LastOnline = os.time() - 4 * H
local _, _, _, grewAway = IE.CalculateOfflineProduction(da1)
expect(#grewAway == 1 and grewAway[1].golem == up and grewAway[1].stage.id == "Young", "only the Golem that reached a new stage is reported")

print("== the Golem collection (index)")
local pc, dc = mk(30)
expect(next(GD.SeenSet(dc)) == nil and select(1, GD.CollectionTotals(dc)) == 0, "a new player has seen nothing")
expect(select(2, GD.CollectionTotals(dc)) == #GD.CollectionOrder * 5 and #GD.CollectionOrder >= 14, "the index covers every type at every stage (" .. select(2, GD.CollectionTotals(dc)) .. " forms)")
local cg = GS.CraftGolem(pc, "BP_Ember_T1", "default")
expect(dc.GolemsSeen["Ember:Infant"] and not dc.GolemsSeen["Ember:Young"], "crafting records the Infant form")
cg.deployed, cg.zoneId = true, "EmberDepths"
local _, _, grewNow = IE.TickOnlineProduction(dc, 2 * H)
for _, g in ipairs(grewNow) do GD.NoteSeen(dc, g.golem) end
expect(dc.GolemsSeen["Ember:Young"] and dc.GolemsSeen["Ember:Infant"], "growing up records the new stage")
cg.grown = 300 * H
GD.NoteSeen(dc, cg)
local allStages = true
for _, st in ipairs(GD.Stages) do allStages = allStages and dc.GolemsSeen["Ember:" .. st.id] == true end
expect(allStages, "an Ancient has been through every stage before it")
local legacyData = { Golems = { { element = "Frost", tier = 2 } } }
local legacySeen = GD.SeenSet(legacyData)
expect(legacySeen["Frost:Adult"] and not legacySeen["Frost:Infant"] and not legacySeen["Frost:Ancient"], "an old Golem counts as seen only as an Adult")
table.remove(dc.Golems, 1)
expect(GD.SeenSet(dc)["Ember:Ancient"] and select(1, GD.CollectionTotals(dc)) == 5, "trading it away does not remove it from the collection")
-- selling a Golem on the Market keeps it in the seller's index and starts the buyer's
local pg, dg = mk(31)
local gift = GS.CraftGolem(pg, "BP_Frost_T1", "default")
gift.grown = 60 * H
local pr, dr = mk(32)
dr.EmberCoins = 5000
local listing = Trading.ListOnMarket(pg, { type = "golem", id = gift.id }, 100)
expect(listing ~= nil and #dg.Golems == 0, "the Golem is listed")
expect(dg.GolemsSeen["Frost:Elder"] and dg.GolemsSeen["Frost:Young"] and dg.GolemsSeen["Frost:Infant"], "the seller keeps every stage it reached in their collection")
local bought = Trading.BuyFromMarket(pr, listing.id)
expect(bought and #dr.Golems == 1 and dr.Golems[1].grown == 60 * H, "the buyer gets it with its growth")
expect(dr.GolemsSeen and dr.GolemsSeen["Frost:Elder"] and dr.GolemsSeen["Frost:Young"], "and their collection gets every stage it has reached")

print("== a grown Golem mines more")
local pm, dm = mk(3)
local function haul(grown)
    local x = { id = "m" .. tostring(grown), element = "Ember", tier = 1, deployed = true, zoneId = "EmberDepths", grown = grown }
    dm.Golems = { x }
    dm.LastOnline = os.time() - 1800
    local sum = 0
    for k, v in pairs((IE.CalculateOfflineProduction(dm))) do if not k:find("^__") then sum += v end end
    return sum
end
local hInfant, hAdult, hAncient = haul(0), haul(8 * H), haul(300 * H)
expect(hInfant < hAdult and hAdult < hAncient, "Infant < Adult < Ancient haul (" .. hInfant .. " / " .. hAdult .. " / " .. hAncient .. ")")

print("== Elite fusion restarts young, with a head start")
local pf, df = mk(4)
for i = 1, 4 do
    local c = GS.CraftGolem(pf, "BP_Frost_T1", "default")
    c.grown = 100 * H                                  -- four Elders (the 4 together hold 400 hours)
end
local fused = GS.NeonFuse(pf, "Frost", 1, nil)
expect(fused and fused.variant == "Neon", "four fuse into an Elite")
expect(math.abs(fused.grown - 400 * H * GD.GROW_FUSE_KEEP) < 1 and GD.StageOf(fused).id == "Elder", "it keeps a quarter of the combined growth (100h = Elder)")
local pg, dg = mk(5)
for i = 1, 4 do GS.CraftGolem(pg, "BP_Frost_T1", "default") end
local freshFuse = GS.NeonFuse(pg, "Frost", 1, nil)
expect(GD.StageOf(freshFuse).id == "Infant", "four Infants fuse into an Infant Elite (no free growth)")

print("== trading")
local pt, dt = mk(6)
local seller = GS.CraftGolem(pt, "BP_Ember_T1", "default")
local oldGolem = GS.CraftGolem(pt, "BP_Ember_T1", "default")
oldGolem.grown = nil
local ancientGolem = GS.CraftGolem(pt, "BP_Ember_T1", "default")
ancientGolem.grown = 300 * H
local v = function(x) return Trading.ValueOf({ type = "golem", tier = x.tier, variant = x.variant, grown = x.grown }) end
expect(v(seller) < v(oldGolem) and v(oldGolem) < v(ancientGolem), "worth more as it grows: Infant < Adult < Ancient")
expect(v(oldGolem) == 30, "an old Golem's value is unchanged (30)")
local q = newPlayer(7, "Other")
PDS.Load(q)
local tid = Trading.InitiateTrade(pt, q)
local ok = Trading.AddToOffer(pt, tid, { type = "golem", id = ancientGolem.id })
local item = Trading.GetTradeView(pt, tid).yourItems[1]
expect(ok and item.grown == 300 * H and item.name:find("Ancient"), "the offer shows the stage and carries its growth (" .. tostring(item and item.name) .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
