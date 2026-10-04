QUIET = true
local CD = load("game/ReplicatedStorage/Shared/Data/CourierData")
local R  = load("SSS/EmberForge/Services/CourierRewards")

local function player(level)
    return { PlayerLevel = level or 1, EmberCoins = 100, Inventory = {} }
end
local rookie, cavern, deep = CD.Resolve("RookieRun"), CD.Resolve("CavernCourier"), CD.Resolve("DeepCourier")
local TODAY = 20000
local never = function() return 0.999 end        -- no rare drop
local always = function() return 0 end           -- always a rare drop

print("== who may start")
local d = player(1)
local ok, why = R.CanStart(d, rookie.def, TODAY)
expect(not ok and why:find("level 3"), "Rookie Run needs player level 3 (" .. tostring(why) .. ")")
d.PlayerLevel = 3
expect(R.CanStart(d, rookie.def, TODAY), "a level 3 player may start Rookie Run")
ok, why = R.CanStart(d, cavern.def, TODAY)
expect(not ok and why:find("level 8"), "Cavern Courier needs player level 8")
d.PlayerLevel = 20
ok, why = R.CanStart(d, cavern.def, TODAY)
expect(not ok and why:find("Courier Level 3"), "Cavern Courier also needs Courier Level 3 (" .. tostring(why) .. ")")
R.State(d, TODAY).level = 3
expect(R.CanStart(d, cavern.def, TODAY), "with both it opens")
ok, why = R.CanStart(d, deep.def, TODAY)
expect(not ok and why:find("Courier Level 8"), "Deep Courier needs Courier Level 8")

print("== coins")
d = player(10)
local r = R.Settle(d, rookie, rookie.par - 1, 0, TODAY, never)
local base = R.BaseReward(d, rookie.def)
expect(r.medal == "Gold" and r.coins == math.floor(base * 1.5), "a run under par is Gold and pays 1.5x (" .. r.coins .. " coins, base " .. base .. ")")
expect(d.EmberCoins == 100 + r.coins, "the coins are added to the player")
d = player(10)
r = R.Settle(d, rookie, rookie.par * 1.2, 0, TODAY, never)
expect(r.medal == "Silver" and r.coins == math.floor(base * 1.2), "a run under 1.35x par is Silver (1.2x)")
d = player(10)
r = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never)
expect(r.medal == nil and r.coins == base, "a slow run pays the base reward and no medal")
expect(R.BaseReward(player(10), deep.def) > R.BaseReward(player(10), cavern.def) and R.BaseReward(player(10), cavern.def) > base, "harder courses pay more")
expect(R.BaseReward(player(20), rookie.def) > R.BaseReward(player(10), rookie.def), "higher levels earn more")
d = player(10)
r = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never, 1.5)
expect(r.coins == math.floor(base * 1.5), "a coin event multiplies what is paid")

print("== the daily allowance")
d = player(1)
local cap = R.DailyCap(d)
local total, runs = 0, 0
while runs < 200 do
    local res = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never)
    total += res.coins
    runs += 1
    if res.cappedCoins then break end
end
expect(total <= cap and total >= cap - R.BaseReward(d, rookie.def), "coins stop at the allowance (" .. total .. " of " .. cap .. " after " .. runs .. " runs)")
local after = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never)
expect(after.coins == 0 and after.cappedCoins, "past the allowance a run pays no coins")
expect(after.xp > 0, "but still pays XP")
local fresh = R.Settle(d, rookie, rookie.par * 2, 0, TODAY + 1, never)
expect(fresh.coins > 0 and not fresh.cappedCoins, "the allowance resets the next day")

print("== materials")
d = player(10)
r = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never)
expect(r.materials and #r.materials == 2 and d.Inventory.BasicOre == 30 and d.Inventory.Coal == 15, "a Rookie run pays 30 Basic Ore and 15 Coal")
d = player(10)
r = R.Settle(d, rookie, rookie.par - 1, 0, TODAY, never)
expect(d.Inventory.BasicOre == 45, "a Gold run pays a larger bundle (" .. tostring(d.Inventory.BasicOre) .. ")")
d = player(10)
r = R.Settle(d, deep, deep.par * 2, 0, TODAY, never)
expect(d.Inventory.ElementalIngot == 4 and d.Inventory.CrystalFragment == 3, "a Deep run pays Elemental Ingots and Crystal Fragments")
d = player(10)
r = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, always)
expect(r.rare ~= nil and (d.Inventory.RefinedOre or 0) >= 5, "a lucky run also drops something rare")
d = player(10)
r = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never)
expect(r.rare == nil and (d.Inventory.RefinedOre or 0) == 0, "an ordinary run does not")
d = player(10)
for _ = 1, R.BUNDLE_RUNS_PER_DAY do R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never) end
local oreBefore = d.Inventory.BasicOre
r = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never)
expect(r.bundleSkipped and r.materials == nil and d.Inventory.BasicOre == oreBefore, "after " .. R.BUNDLE_RUNS_PER_DAY .. " runs a day the materials stop (coins and XP continue)")

print("== Courier Level")
d = player(10)
r = R.Settle(d, rookie, rookie.par * 2, 0, TODAY, never)
expect(r.xp == CD.RunXp(rookie.def, nil) and R.State(d, TODAY).xp == r.xp, "a run gives its XP (" .. r.xp .. ")")
d = player(10)
local levelled = 0
for _ = 1, 30 do
    local res = R.Settle(d, rookie, rookie.par - 1, 0, TODAY + _, never)
    levelled += res.levelUps
end
expect(R.State(d, TODAY).level > 3 and levelled == R.State(d, TODAY).level - 1, "repeat runs raise the Courier Level (now " .. R.State(d, TODAY).level .. ")")
local lvlBonus = player(10)
R.State(lvlBonus, TODAY).level = 10
local a = R.Settle(player(10), rookie, rookie.par * 2, 0, TODAY, never).coins
local b = R.Settle(lvlBonus, rookie, rookie.par * 2, 0, TODAY, never).coins
expect(b > a, "a higher Courier Level pays more coins (" .. a .. " vs " .. b .. ")")

print("== personal best")
d = player(10)
r = R.Settle(d, rookie, 80, 0, TODAY, never)
expect(r.personalBest and r.previousBest == nil and R.State(d, TODAY).best.RookieRun == 80, "the first run is a personal best")
r = R.Settle(d, rookie, 90, 0, TODAY, never)
expect(not r.personalBest and R.State(d, TODAY).best.RookieRun == 80, "a slower run is not")
r = R.Settle(d, rookie, 70.26, 0, TODAY, never)
expect(r.personalBest and r.previousBest == 80 and R.State(d, TODAY).best.RookieRun == 70.3, "a faster run is, and it is kept to one decimal")

print("== daily challenge")
local ch = CD.DailyChallenge(TODAY)
local course = CD.Resolve(ch.courseId)
d = player(30)
R.State(d, TODAY).level = 20
r = R.Settle(d, course, course.par * 2, 0, TODAY, never)
expect(r.daily == nil, "a slow run on the challenge course earns no bonus")
r = R.Settle(d, course, course.par - 1, 0, TODAY, never)
expect(r.daily ~= nil and r.daily.coins > 0 and r.daily.rare ~= nil, "Gold on today's course earns the bonus chest")
r = R.Settle(d, course, course.par - 1, 0, TODAY, never)
expect(r.daily == nil, "only once a day")
r = R.Settle(d, course, course.par - 1, 0, TODAY + 3, never)
expect(CD.DailyChallenge(TODAY + 3).courseId == ch.courseId and r.daily ~= nil, "it is available again the next time that course comes round")
local other = CD.Resolve(CD.Courses[((TODAY + 1) % 3) + 1].id)
d = player(30)
R.State(d, TODAY).level = 20
r = R.Settle(d, other, other.par - 1, 0, TODAY, never)
expect(r.daily == nil, "Gold on a different course does not count")

print("== saved data is repaired")
d = { PlayerLevel = 5, EmberCoins = 0, Courier = { level = 999, best = "junk" } }
local s = R.State(d, TODAY)
expect(s.level == CD.MAX_LEVEL and type(s.best) == "table", "a damaged table is tidied")
d = { PlayerLevel = 5, EmberCoins = 0 }
expect(R.State(d, TODAY).level == 1 and d.Courier ~= nil, "a player with no Courier data gets a fresh one")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
