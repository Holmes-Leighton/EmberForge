QUIET = true
local TD    = load("game/ReplicatedStorage/Shared/Data/TowerData")
local MD    = load("game/ReplicatedStorage/Shared/Data/MaterialData")
local TR    = load("SSS/EmberForge/Services/TowerRewards")
local Round = load("SSS/EmberForge/Services/TowerRound")

local TODAY = 20000
local never, always = function() return 0.999 end, function() return 0 end
local function player(level) return { PlayerLevel = level or 10, EmberCoins = 0, Inventory = {} } end

print("== the coin curve rises with height")
local prev = 0
local rising = true
for n = 1, 30 do
    local c = TD.LevelCoins(10, n)
    if c <= prev then rising = false end
    prev = c
end
expect(rising, "every level pays more than the one below")
local c1, c30 = TD.LevelCoins(10, 1), TD.LevelCoins(10, 30)
expect(c30 / c1 > 60 and c30 / c1 < 160, "level 30 pays about 100x level 1 (" .. c1 .. " -> " .. c30 .. ", " .. string.format("%.0f", c30 / c1) .. "x)")
expect(TD.LevelCoins(30, 10) > TD.LevelCoins(5, 10), "higher player levels earn more")

print("== paying a level")
local d = player(10)
local r = TR.PayLevel(d, 1, 30, TODAY, { rng = never })
expect(r.coins == TD.LevelCoins(10, 1) and d.EmberCoins == r.coins, "level 1 pays its coins (" .. r.coins .. ")")
expect(r.materials == nil, "and no bundle (only every 5th level pays one)")
d = player(10)
r = TR.PayLevel(d, 5, 30, TODAY, { rng = never })
expect(r.materials and d.Inventory.BasicOre == 20 and d.Inventory.Coal == 10, "level 5 pays a Basic Ore and Coal bundle")
d = player(10)
r = TR.PayLevel(d, 15, 30, TODAY, { rng = never })
expect(d.Inventory.RefinedOre == 8 and d.Inventory.EmberDust == 5, "level 15 pays refined materials")
d = player(10)
r = TR.PayLevel(d, 25, 30, TODAY, { rng = never })
expect(d.Inventory.ElementalIngot == 3 and d.Inventory.CrystalFragment == 2, "level 25 pays Elemental Ingots and Crystal Fragments")
local allExist = true
for _, b in ipairs(TD.Bundles) do for _, it in ipairs(b.items) do if not MD.Get(it.id) then allExist = false end end end
for _, rd in ipairs(TD.RareDrops) do if not MD.Get(rd.id) then allExist = false end end
expect(allExist, "every material the tower pays exists")
d = player(10)
r = TR.PayLevel(d, 20, 30, TODAY, { rng = always })
expect(r.rare ~= nil and (d.Inventory.ElementalIngot or 0) >= 2 or (d.Inventory.RefinedOre or 0) >= 4, "a lucky level drops something rare")
d = player(10)
r = TR.PayLevel(d, 3, 30, TODAY, { rng = never })
expect(r.rare == nil, "an unlucky one does not")
expect(TD.RareChanceBase + TD.RareChancePerLevel * 30 > TD.RareChanceBase + TD.RareChancePerLevel * 3, "rare drops get likelier with height")
d = player(10)
r = TR.PayLevel(d, 10, 30, TODAY, { rng = never, coinMultiplier = 1.5 })
expect(r.coins == math.floor(TD.LevelCoins(10, 10) * 1.5), "a coin event multiplies the payout")
d = player(10)
r = TR.PayLevel(d, 10, 60, TODAY, { rng = never, pro = true })
expect(r.coins == math.floor(TD.LevelCoins(10, 10) * 2.5), "a Pro tower pays 2.5x")

print("== Courier XP and best level")
d = player(10)
local before = TR.State(d, TODAY).xp
TR.PayLevel(d, 1, 30, TODAY, { rng = never })
local s = TR.State(d, TODAY)
expect(s.xp - before == TD.LevelXp(1, 30) or s.level > 1, "each level gives Courier XP")
expect(TD.LevelXp(25, 30) > TD.LevelXp(1, 30), "higher levels give more XP")
TR.PayLevel(d, 12, 30, TODAY, { rng = never })
TR.PayLevel(d, 7, 30, TODAY, { rng = never })
expect(TR.State(d, TODAY).towerBest == 12, "the best level ever reached is remembered (" .. TR.State(d, TODAY).towerBest .. ")")

print("== the daily allowance")
d = player(1)
local cap = TR.DailyCap(d)
local total = 0
for climb = 1, 40 do
    for n = 1, 30 do total += TR.PayLevel(d, n, 30, TODAY, { rng = never }).coins end
end
expect(total <= cap and total >= cap - TD.LevelCoins(1, 30), "coins stop at the allowance (" .. total .. " of " .. cap .. ")")
local last = TR.PayLevel(d, 30, 30, TODAY, { rng = never })
expect(last.coins == 0 and last.capped and last.xp > 0, "past it a level pays no coins but still gives XP")
local fresh = TR.PayLevel(d, 30, 30, TODAY + 1, { rng = never })
expect(fresh.coins > 0, "it resets the next day")
d = player(10)
local climbCoins = TR.FullClimbCoins(10, 30, false)
expect(climbCoins < TR.DailyCap(d) * 3 and climbCoins > TR.DailyCap(d) / 10, "a perfect climb is worth " .. climbCoins .. " coins against a daily allowance of " .. TR.DailyCap(d) .. " (to tune with the balance model)")

print("== the chest at the top")
d = player(10)
local chest = TR.PayTop(d, 30, TODAY, { rng = never })
local base = TD.LevelCoins(10, 30) * TD.TOP_CHEST_MULT
expect(chest.firstToday and chest.coins == base * TD.FIRST_SUMMIT_MULT, "the first summit of the day pays double (" .. chest.coins .. ")")
expect(chest.rare.qty == TD.RareFor(30).qty * 3, "and a triple rare drop")
local second = TR.PayTop(d, 30, TODAY, { rng = never })
expect(not second.firstToday and second.coins == base and second.rare.qty == TD.RareFor(30).qty, "later summits pay the normal chest")
local next = TR.PayTop(d, 30, TODAY + 1, { rng = never })
expect(next.firstToday, "the first-summit bonus is back the next day")

print("== the round clock")
local T0 = 1000 * (TD.ROUND_SECONDS + TD.INTERMISSION)      -- the start of round 1000
local rd = Round.New(T0 + 10)
expect(rd.index == 1000 and rd.startedAt == T0, "a round is found from the wall clock")
expect(Round.Remaining(rd, T0 + 10) == TD.ROUND_SECONDS - 10, "it has the rest of its 8 minutes left")
expect(Round.Running(rd, T0 + 100) and not Round.Running(rd, T0 + TD.ROUND_SECONDS + 1), "it is running until the time is up, then it is the intermission")
expect(Round.UntilNext(rd, T0 + 10) == TD.ROUND_SECONDS + TD.INTERMISSION - 10, "and it knows when the next one starts")
local events, same = Round.Step(rd, T0 + 100)
expect(#events == 0 and same == rd, "nothing happens mid-round")
events, rd = Round.Step(rd, T0 + TD.ROUND_SECONDS + TD.INTERMISSION + 1)
expect(#events == 1 and events[1].kind == "new" and rd.index == 1001, "the next round starts after the intermission")
expect(rd.seed ~= TD.SeedForRound(1000), "with a new tower")
local a, b = Round.New(T0 + 5), Round.New(T0 + 400)
expect(a.index == b.index and a.seed == b.seed, "every server in the same round builds the same tower")

print("== a summit speeds the round up")
rd = Round.New(T0)
local sped = Round.Summit(rd, 111, T0 + 120, 120)
expect(sped and Round.Remaining(rd, T0 + 120) == TD.SUMMIT_SPEEDUP, "the first summit drops the time left to " .. TD.SUMMIT_SPEEDUP .. " seconds")
expect(not Round.Summit(rd, 222, T0 + 130, 130), "a second summit does not speed it up again")
expect(#rd.summits == 2, "both summits are recorded")
rd = Round.New(T0)
local late = Round.Summit(rd, 333, T0 + TD.ROUND_SECONDS - 20, 400)
expect(not late and Round.Remaining(rd, T0 + TD.ROUND_SECONDS - 20) == 20, "a summit near the end does not give extra time")
rd = Round.New(T0)
expect(not Round.Summit(rd, 444, T0 + TD.ROUND_SECONDS + 5, 500), "a summit after the time is up counts for nothing")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
