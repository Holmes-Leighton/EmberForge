-- Sky Tower rules added with the zones: round mutators in the runner, and the chest for clearing a zone.
QUIET = true
local TD     = load("game/ReplicatedStorage/Shared/Data/TowerData")
local TL     = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local MD     = load("game/ReplicatedStorage/Shared/Data/MaterialData")
local CD     = load("game/ReplicatedStorage/Shared/Data/CourierData")
local Runner = load("SSS/EmberForge/Services/TowerRunner")
local TR     = load("SSS/EmberForge/Services/TowerRewards")

local T = TL.Build({ levels = 30, seed = 21, base = TD.BASE })
local TODAY = 20000
local never = function() return 0.999 end
local function player(level) return { PlayerLevel = level or 10, EmberCoins = 0, Inventory = {} } end

print("== mutators in the runner")
local classic = Runner.New(T, {}, 0)
expect(classic.mutator.id == "classic" and Runner.Penalty(classic) == TD.RESPAWN_PENALTY, "no mutator means the classic rules")
local gold = Runner.New(T, {}, 0, TD.MutatorById.gold)
gold.respawns = 2
expect(Runner.Penalty(gold) == 6 and math.abs(Runner.Elapsed(gold, 100) - 112) < 1e-9, "Golden Hour: each fall costs 6 seconds (100 s + 2 falls = " .. Runner.Elapsed(gold, 100) .. ")")
classic.respawns = 2
expect(math.abs(Runner.Elapsed(classic, 100) - (100 + 2 * TD.RESPAWN_PENALTY)) < 1e-9, "classic falls cost the usual penalty")

local function lavaAt(run, level)
    run.highest = level
    Runner.StartLava(run, 0)
    return run.lava
end
expect(lavaAt(Runner.New(T, {}, 0), 4) == nil, "classic: no lava chases on level 4")
local tide = Runner.New(T, {}, 0, TD.MutatorById.tide)
expect(lavaAt(tide, 3) == nil, "Rising Tide: still none on level 3")
local l4 = lavaAt(tide, 4)
expect(l4 ~= nil and l4.rise >= 0.5, "Rising Tide: lava chases from level 4 even on an easy level (" .. tostring(l4 and l4.rise) .. " studs/s)")
local base = Runner.New(T, {}, 0)
local tier3 = 0
for i, lv in ipairs(T.levels) do if lv.tier == 3 and i > 10 then tier3 = i break end end
local classicRise, tideRise = lavaAt(base, tier3).rise, lavaAt(Runner.New(T, {}, 0, TD.MutatorById.tide), tier3).rise
expect(math.abs(tideRise - classicRise * 1.4) < 1e-9, "Rising Tide: lava on a hard level rises 40% faster (" .. classicRise .. " -> " .. tideRise .. ")")
local steady = 0.85 * 1.4
expect(tideRise <= steady + 1e-9 and tideRise < 1.4, "and still slower than a steady climber (" .. string.format("%.2f", tideRise) .. " studs/s)")

print("== clearing a zone pays a chest")
local d = player(10)
local r = TR.PayLevel(d, 7, 30, TODAY, { rng = never })
expect(r.zoneClear and r.zoneClear.zone == 1 and r.zoneClear.name == "Granite Steps", "reaching level 7 clears the first zone (" .. tostring(r.zoneClear and r.zoneClear.name) .. ")")
expect(d.Inventory.GraniteShard == 14, "it pays 14 Granite Shards (" .. tostring(d.Inventory.GraniteShard) .. ")")
local plain = player(10)
local rp = TR.PayLevel(plain, 8, 30, TODAY, { rng = never })
expect(rp.zoneClear == nil and r.coins > TD.LevelCoins(10, 7), "an ordinary level has no chest, and the chest level pays more than its coins alone (" .. r.coins .. " vs " .. TD.LevelCoins(10, 7) .. ")")
expect(d.EmberCoins == r.coins, "the coins reached the player (" .. d.EmberCoins .. ")")
for z = 1, 4 do
    local pd = player(10)
    local rz = TR.PayLevel(pd, z * 6 + 1, 30, TODAY, { rng = never })
    local mat = TD.ZONES[z].material
    expect(rz.zoneClear and rz.zoneClear.zone == z and pd.Inventory[mat.id] == mat.qty, "zone " .. z .. " pays " .. mat.qty .. " " .. mat.id)
end
for _, z in ipairs(TD.ZONES) do expect(MD.Get(z.material.id) ~= nil, "zone material " .. z.material.id .. " is a real material") end

print("== the chest is not a faucet")
local cap = player(10)
local paid = 0
for n = 1, TD.ZONE_CHESTS_PER_DAY + 3 do
    local rr = TR.PayLevel(cap, 7, 30, TODAY, { rng = never })
    if rr.zoneClear then paid += 1 end
end
expect(paid == TD.ZONE_CHESTS_PER_DAY, "at most " .. TD.ZONE_CHESTS_PER_DAY .. " zone chests a day (" .. paid .. ")")
local nextDay = TR.PayLevel(cap, 7, 30, TODAY + 1, { rng = never })
expect(nextDay.zoneClear ~= nil, "the count resets the next day")
local mult = player(10)
local rm = TR.PayLevel(mult, 7, 30, TODAY, { rng = never, coinMultiplier = 2 })
local base7 = TR.PayLevel(player(10), 7, 30, TODAY, { rng = never })
expect(rm.coins == base7.coins * 2, "event and mutator coin multipliers apply to the chest too (" .. rm.coins .. " vs " .. base7.coins .. ")")
local pro7 = TR.PayLevel(player(10), 7, 60, TODAY, { rng = never, pro = true })
local pro13 = TR.PayLevel(player(10), 13, 60, TODAY, { rng = never, pro = true })
expect(pro7.zoneClear == nil and pro13.zoneClear and pro13.zoneClear.zone == 1, "a 60-level Pro tower clears its first zone at level 13, not 7")
expect(pro13.zoneClear.material.qty == TD.ZONES[1].material.qty * TD.PRO_PAY_MULT, "and its chest is bigger (x" .. TD.PRO_PAY_MULT .. ")")

print("== mutators change how you move, within the anti-cheat's limits")
local w, jp, jh = TD.MovementFor(TD.MutatorById.turbo, 16, true, 50, 7.2)
expect(math.abs(w - 20.8) < 1e-9 and jp == 50, "Turbo: 16 -> 20.8 walk speed, jumps unchanged")
local w2 = TD.MovementFor(TD.MutatorById.turbo, 36, true, 50, 7.2)
expect(w2 <= TD.MAX_WALK and TD.MAX_WALK < CD.MIN_SPEED, "Turbo never pushes even a fully trained runner past the cheat check (" .. w2 .. " < " .. CD.MIN_SPEED .. ")")
local w3 = TD.MovementFor(TD.MutatorById.turbo, 40, true, 50, 7.2)
expect(w3 == 40, "a player already faster than the cap is not slowed down by it")
local _, power = TD.MovementFor(TD.MutatorById.moon, 16, true, 50, 7.2)
expect(math.abs(power - 50 * math.sqrt(1.35)) < 1e-9, "Moon Jump on a JumpPower humanoid scales power by sqrt(1.35) so the height is x1.35 (" .. string.format("%.1f", power) .. ")")
local _, _, height = TD.MovementFor(TD.MutatorById.moon, 16, false, 50, 7.2)
expect(math.abs(height - 7.2 * 1.35) < 1e-9, "Moon Jump on a JumpHeight humanoid scales the height (" .. height .. ")")
local cw, cp, ch = TD.MovementFor(TD.MutatorById.classic, 16, true, 50, 7.2)
expect(cw == 16 and cp == 50 and ch == 7.2, "the classic round changes nothing")
local nw = TD.MovementFor(nil, 16, true, 50, 7.2)
expect(nw == 16, "no mutator changes nothing")

print("== skipping a level")
local run = Runner.New(T, {}, 0)
expect(select(1, Runner.CanSkip(run, 0)), "a climber on level 1 can skip")
local lvl = Runner.SkipLevel(run, 100)
expect(lvl == 2 and run.highest == 2, "a skip puts them on the next level")
local cpNow = Runner.StartPoint(run)
expect(cpNow == T.checkpoints[T.levels[2].firstCheckpoint], "and their respawn point is that level's start")
expect(100 - run.levelAt > TD.LEVEL_MIN_MINIMUM, "the next climb is not mistaken for a too-fast one")
expect(run.lastPos == nil and run.strikes == 0, "the speed check starts fresh (a teleport is not a cheat)")
expect(not select(1, Runner.CanSkip(run, TD.SKIPS_PER_ROUND)), "no more than " .. TD.SKIPS_PER_ROUND .. " skips a round")
local ok2, why2 = Runner.CanSkip(run, TD.SKIPS_PER_ROUND)
expect(why2 == "limit", "(the reason is the limit)")
run.highest = #T.levels
local ok3, why3 = Runner.CanSkip(run, 0)
expect(not ok3 and why3 == "top", "never from the last level")
local done = Runner.New(T, {}, 0)
done.finished = true
expect(not select(1, Runner.CanSkip(done, 0)), "not once the climb is over")
local lavaRun = Runner.New(T, {}, 0)
lavaRun.highest = 10
Runner.SkipLevel(lavaRun, 50)
expect(lavaRun.lava ~= nil and lavaRun.lava.t0 == 50, "skipping into a level with lava starts that level's lava fresh")
local PD = load("game/ReplicatedStorage/Shared/Data/ProductData")
expect(PD.Products.TowerSkip ~= nil and PD.Products.TowerSkip.id == 0, "the skip product exists and is 'not for sale yet' until its id is pasted in")

print("== the summit pays the last zone's material")
local top = player(10)
local chest = TR.PayTop(top, 30, TODAY, {})
expect(chest.zoneMaterial and chest.zoneMaterial.id == "ShadowDust" and top.Inventory.ShadowDust == 6, "the summit chest includes the Hollow Crown's Shadow Dust (" .. tostring(top.Inventory.ShadowDust) .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
