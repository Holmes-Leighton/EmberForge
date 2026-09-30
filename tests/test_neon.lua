QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify", "LevelUp", "ForgeUpgraded" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local Golem = load("SSS/EmberForge/Services/GolemService")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")
local Names = load("game/ReplicatedStorage/Shared/Modules/GolemNames")
local Trading = load("SSS/EmberForge/Services/TradingService")

local p = newPlayer(1, "Neo")
local d = PDS.Load(p)
d.Inventory = { BasicOre = 1000, Coal = 1000 }

print("== rarity by tier")
expect(GD.RarityForTier(1) == "Common" and GD.RarityForTier(3) == "Rare" and GD.RarityForTier(5) == "Legendary", "tier -> rarity")
for i = 1, 5 do Golem.CraftGolem(p, "BP_Frost_T1", "default") end
expect(#d.Golems == 5 and d.Golems[1].rarity == "Common", "crafted golems carry their rarity")
local desc = Names.Describe(d.Golems[1])
expect(desc.name == "Frost Pebble Golem" and desc.rarity == "Common", "description: " .. desc.name)

print("== neon fusion")
local base = GD.ComputeStats("Frost", 1, nil, 0, nil)
local neonStats = GD.ComputeStats("Frost", 1, nil, 0, "Neon")
expect(neonStats.miningRate > base.miningRate and math.abs(neonStats.miningRate / base.miningRate - 1.25) < 0.05, "Neon is ~25% stronger")
local deployedGolem = d.Golems[1]
deployedGolem.deployed = true
local g, err = Golem.NeonFuse(p, "Frost", 1, nil)
expect(g and g.variant == "Neon" and g ~= deployedGolem, "a deployed golem is never consumed; the 4 idle ones fuse into a Neon")
expect(#d.Golems == 2 and d.Golems[1] == deployedGolem and deployedGolem.variant == nil, "deployed golem untouched, 3 idle removed")
deployedGolem.deployed = false
g, err = Golem.NeonFuse(p, "Frost", 1, nil)
expect(g == nil, "only 1 plain golem left: refused (" .. tostring(err) .. ")")
g, err = Golem.NeonFuse(p, "Ember", 1, nil)
expect(g == nil, "no Ember golems: refused")
g, err = Golem.NeonFuse(p, "Frost", 1, "Neon")
expect(g == nil, "needs 4 Neons for Mega: refused")

print("== mega neon")
for i = 1, 3 do
    for j = 1, 4 do Golem.CraftGolem(p, "BP_Frost_T1", "default") end
    local n = Golem.NeonFuse(p, "Frost", 1, nil)
    expect(n ~= nil, "extra neon #" .. i)
end
local neons = 0
for _, x in ipairs(d.Golems) do if x.variant == "Neon" then neons += 1 end end
expect(neons == 4, "four Neon golems (" .. neons .. ")")
g, err = Golem.NeonFuse(p, "Frost", 1, "Neon")
expect(g and g.variant == "MegaNeon", "4 Neons -> Mega Neon")
expect(Golem.NeonFuse(p, "Frost", 1, "MegaNeon") == nil, "Mega Neon can't be fused further")
local mega = GD.ComputeStats("Frost", 1, nil, 0, "MegaNeon")
expect(mega.miningRate > neonStats.miningRate, "Mega stronger than Neon")

print("== hostile input")
expect(Golem.NeonFuse(p, 5, "x", nil) == nil, "bad types refused")
expect(Golem.NeonFuse(p, "Frost", 1, "Bogus") == nil, "bogus variant refused")

print("== trade/market names show rarity + variant")
local q = newPlayer(2, "Other")
PDS.Load(q)
local tid = Trading.InitiateTrade(p, q)
local mega_g
for _, x in ipairs(d.Golems) do if x.variant == "MegaNeon" then mega_g = x end end
local ok = Trading.AddToOffer(p, tid, { type = "golem", id = mega_g.id })
local view = Trading.GetTradeView(p, tid)
expect(ok and view.yourItems[1].name:find("Supreme") and view.yourItems[1].name:find("Common"), "offer shows: " .. tostring(view.yourItems[1] and view.yourItems[1].name))

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
