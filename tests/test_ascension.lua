QUIET = true
-- Ascension: requirements, cost curve, permanent bonuses and their effect on mining.
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local AS = load("SSS/EmberForge/Services/AscensionService")
local AD = load("game/ReplicatedStorage/Shared/Data/AscensionData")
local FD = load("game/ReplicatedStorage/Shared/Data/ForgeData")

local function mk(id, name, coins, level)
    local p = newPlayer(id, name)
    local d = PDS.Load(p)
    d.EmberCoins = coins
    d.ForgeLevel = level
    return p, d
end

print("== the curve")
expect(AD.Cost(1) == 25000 and AD.Cost(2) == 100000 and AD.Cost(10) == 2500000, "costs grow with the square of the Ascension")
local b10 = AD.Bonus(10)
expect(math.abs(b10.mining - 0.20) < 1e-9 and math.abs(b10.luck - 0.10) < 1e-9 and math.abs(b10.coins - 0.30) < 1e-9, "ten Ascensions are +20% mining, +10% luck, +30% coins")
expect(AD.Bonus(99).mining == b10.mining and AD.Bonus(-3).mining == 0, "bonuses are clamped to 0..10")
expect(AD.Roman(4) == "IV" and AD.Title(3) == "Ascended III", "titles use roman numerals")

print("== requirements")
local a, da = mk(1, "Ada", 1000000, 9)
local n, why = AS.Ascend(a)
expect(n == nil and why:find("Forge Level 10"), "needs Forge Level 10 (" .. tostring(why) .. ")")
local b, db = mk(2, "Bo", 100, 10)
local n2, why2 = AS.Ascend(b)
expect(n2 == nil and why2:find("coins"), "needs the coins (" .. tostring(why2) .. ")")
expect(db.EmberCoins == 100 and (db.Ascensions or 0) == 0, "a refused Ascension costs nothing")

print("== ascending")
da.ForgeLevel = 10
local first = AS.Ascend(a)
expect(first == 1 and da.EmberCoins == 1000000 - 25000 and da.Ascensions == 1, "first Ascension costs 25,000")
expect(table.find(da.Titles, "Ascended I") ~= nil, "and grants the title")
local second = AS.Ascend(a)
expect(second == 2 and da.EmberCoins == 1000000 - 25000 - 100000, "second costs 100,000")
da.EmberCoins = 1e9
for i = 3, 10 do AS.Ascend(a) end
expect(da.Ascensions == 10, "up to ten")
local over, owhy = AS.Ascend(a)
expect(over == nil and owhy:find("highest"), "no more than ten (" .. tostring(owhy) .. ")")
local info = AS.Info(a)
expect(info.maxed and info.nextCost == nil and info.count == 10, "the menu knows it is maxed")

print("== the bonus applies")
local base = FD.TotalPerks(10)
local asc = FD.TotalPerks(10, 10)
expect(math.abs(asc.mining - base.mining - 0.20) < 1e-9 and math.abs(asc.coins - base.coins - 0.30) < 1e-9, "Forge perks include Ascensions")
expect(FD.TotalPerks(10, 0).mining == base.mining and FD.TotalPerks(10).mining == base.mining, "no Ascensions, no change")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
