QUIET = true
-- Offline gains: time scaling, storage caps, carry caps, broken Golems, skills, pets and events.
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local IE = load("SSS/EmberForge/Services/IdleEngine")
local GD = load("game/ReplicatedStorage/Shared/Data/GolemData")
local GC = load("game/ReplicatedStorage/Shared/Data/GameConfig")
local LO = load("SSS/EmberForge/Services/LiveOpsService")
LO.HourlyEnabled = false          -- the hourly event has its own tests

local function player(id, golems, storageTier)
    local p = newPlayer(id, "P" .. id)
    local d = PDS.Load(p)
    d.Golems = golems
    d.StorageTier = storageTier or 0
    d.LastOnline = os.time()
    return p, d
end

local function ember(variant, tier)
    return { id = "g" .. math.random(1e9), element = "Ember", tier = tier or 1, variant = variant, deployed = true, zoneId = "EmberDepths" }
end

local function total(gains)
    local n = 0
    for k, v in pairs(gains) do if not k:find("^__") then n += v end end
    return n
end

print("== time scaling")
local p1, d1 = player(1, { ember() })
local stats = GD.ComputeStats("Ember", 1)
d1.LastOnline = os.time() - 1800          -- 30 minutes away
local g30 = IE.CalculateOfflineProduction(d1)
local expect30 = math.floor(stats.miningRate * 0.5)
expect(math.abs(total(g30) - expect30) <= 2, "30 minutes away gives about half an hour of mining (" .. total(g30) .. " vs " .. expect30 .. ")")
d1.LastOnline = os.time()
expect(next((IE.CalculateOfflineProduction(d1))) == nil, "no time away gives nothing")
local noGolem = select(2, player(2, {}))
noGolem.LastOnline = os.time() - 7200
expect(next((IE.CalculateOfflineProduction(noGolem))) == nil, "no deployed Golems gives nothing")
local idle = ember() idle.deployed = false
local d3 = select(2, player(3, { idle }))
d3.LastOnline = os.time() - 7200
expect(next((IE.CalculateOfflineProduction(d3))) == nil, "an undeployed Golem gives nothing")

print("== caps")
-- how long does each Golem take to hit its carry capacity, against the offline storage hours?
for _, tier in ipairs({ 1, 2, 3, 4 }) do
    local s = GD.ComputeStats("Ember", tier)
    local hoursToFill = s.carryCapacity / s.miningRate
    print(string.format("  Ember tier %d: %d/hr, carry %d -> full after %.1f hours", tier, s.miningRate, s.carryCapacity, hoursToFill))
end
local cap = {}
for tier, hours in pairs({ [0] = GC.OFFLINE_STORAGE_BASE_HOURS, [1] = GC.OFFLINE_STORAGE_UPGRADED_HOURS, [2] = GC.OFFLINE_STORAGE_PREMIUM_HOURS }) do cap[tier] = hours end
expect(IE.StorageCapSeconds(0) == cap[0] * 3600 and IE.StorageCapSeconds(1) == cap[1] * 3600 and IE.StorageCapSeconds(2) == cap[2] * 3600, "storage tiers map to " .. cap[0] .. "h / " .. cap[1] .. "h / " .. cap[2] .. "h")
-- the storage upgrades must be worth buying: a longer cap has to produce more for a typical Golem
local gainByTier = {}
for tier = 0, 2 do
    local _, d = player(10 + tier, { ember(nil, 1) }, tier)
    d.LastOnline = os.time() - 40 * 3600          -- gone for far longer than any cap
    gainByTier[tier] = total((IE.CalculateOfflineProduction(d)))
end
print(string.format("  plain T1 Ember after 40h away: base %d, upgraded %d, premium %d", gainByTier[0], gainByTier[1], gainByTier[2]))
expect(gainByTier[1] > gainByTier[0], "the 8h storage upgrade gives more than the base storage")
expect(gainByTier[2] > gainByTier[1], "the 24h storage upgrade gives more than the 8h one")

print("== broken Golems and variants")
local broken = ember() broken._durabilitySeconds = 0
local db = select(2, player(20, { broken }))
db.LastOnline = os.time() - 3600
expect(next((IE.CalculateOfflineProduction(db))) == nil, "a broken Golem produces nothing")
local plain = select(2, player(21, { ember() }))
local sup = select(2, player(22, { ember("MegaNeon") }))
plain.LastOnline, sup.LastOnline = os.time() - 7200, os.time() - 7200
local gp, gs = total((IE.CalculateOfflineProduction(plain))), total((IE.CalculateOfflineProduction(sup)))
expect(gs > gp, "a Supreme Golem out-mines a plain one while you are away (" .. gs .. " vs " .. gp .. ")")

print("== pets and events")
local base = select(2, player(30, { ember() }))
base.LastOnline = os.time() - 7200
local gb = total((IE.CalculateOfflineProduction(base)))
LO.AddEvent("drops", 2, 1, "test")
local ev = select(2, player(31, { ember() }))
ev.LastOnline = os.time() - 7200
local ge = total((IE.CalculateOfflineProduction(ev)))
expect(ge >= gb * 1.9, "a x2 drops event doubles the haul (" .. ge .. " vs " .. gb .. ")")
LO.ClearEvents()

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
