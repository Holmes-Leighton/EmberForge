QUIET = true
-- The Hollow Maze: the layout from a seed (every cell reachable, doorways line up, loops, same seed = same maze), then the Zombie Golem's brain, the round clock
-- and the rewards (added as each is built).
local MD = load("game/ReplicatedStorage/Shared/Data/MazeData")
local ML = load("game/ReplicatedStorage/Shared/Modules/MazeLayout")
local MZ = load("game/ReplicatedStorage/Shared/Modules/MazeZombie")
local MR = load("SSS/EmberForge/Services/MazeRound")
local MW = load("SSS/EmberForge/Services/MazeRewards")
local MAT = load("game/ReplicatedStorage/Shared/Data/MaterialData")

local BASE = { x = 0, y = 100, z = 0 }
local function build(seed) return ML.Build({ seed = seed, base = BASE }) end

print("== shape")
local M = build(7)
expect(M.width == 40 and M.height == 10 and M.sections == 5, "40 x 10 cells in 5 sections")
expect(#MD.SECTIONS == 5 and MD.SECTIONS[1] == "Stone" and MD.SECTIONS[5] == "Void", "Stone first, Void last")
expect(M.start.x == 1 and M.exit.x == 40, "it starts at the west end and ends at the east end")
expect(M.cells[1][M.start.y].W == false and M.cells[40][M.exit.y].E == false, "the entrance and the exit are open")
local sealed = true
for x = 1, M.width do
    if not M.cells[x][1].N or not M.cells[x][M.height].S then sealed = false end
end
for y = 1, M.height do
    if y ~= M.start.y and not M.cells[1][y].W then sealed = false end
    if y ~= M.exit.y and not M.cells[40][y].E then sealed = false end
end
expect(sealed, "the outside of the maze is closed except for the entrance and the exit")
local consistent = true
for x = 1, M.width do
    for y = 1, M.height do
        if x < M.width and M.cells[x][y].E ~= M.cells[x + 1][y].W then consistent = false end
        if y < M.height and M.cells[x][y].S ~= M.cells[x][y + 1].N then consistent = false end
    end
end
expect(consistent, "a wall between two cells is the same wall from both sides")
expect(M.cells[1][1].section == 1 and M.cells[9][1].section == 2 and M.cells[40][1].section == 5, "cells know their section")

print("== every maze can be finished (300 seeds)")
local worstPath, bestPath, notReachable, gateBroken, noLoops, tooEasy = 0, 1e9, 0, 0, 0, 0
for seed = 1, 300 do
    local T = build(seed * 37 + 5)
    local dist = ML.Distances(T, T.start.x, T.start.y)
    local all = true
    for x = 1, T.width do for y = 1, T.height do if dist[x][y] == nil then all = false end end end
    if not all or dist[T.exit.x][T.exit.y] == nil then notReachable += 1 end
    local len = dist[T.exit.x] and dist[T.exit.x][T.exit.y] or 0
    worstPath, bestPath = math.max(worstPath, len), math.min(bestPath, len)
    for s = 1, T.sections - 1 do
        local row = T.gates[s]
        if T.cells[s * T.cols][row].E ~= false or T.cells[s * T.cols + 1][row].W ~= false then gateBroken += 1 end
    end
    local cellsN = T.width * T.height
    if ML.Passages(T) <= cellsN - T.sections then noLoops += 1 end       -- a perfect maze of 5 sections has cells - 5 passages inside them plus 4 doorways
    if len < 70 then tooEasy += 1 end
end
expect(notReachable == 0, "from the entrance every cell and the exit can be reached on all 300 seeds")
expect(gateBroken == 0, "the doorways between sections line up on all 300 seeds")
expect(noLoops == 0, "every maze has loops to run round")
expect(bestPath >= 70, "the shortest route is never trivial (the shortest of 300 is " .. bestPath .. " cells)")
expect(worstPath < 400, "and never absurdly long (the longest is " .. worstPath .. " cells)")

print("== the same seed is the same maze; a different seed is a different one")
local A, B, C = build(11), build(11), build(12)
local same, differs = true, false
for x = 1, A.width do
    for y = 1, A.height do
        for _, d in ipairs({ "N", "E", "S", "W" }) do
            if A.cells[x][y][d] ~= B.cells[x][y][d] then same = false end
            if A.cells[x][y][d] ~= C.cells[x][y][d] then differs = true end
        end
    end
end
expect(same, "the same seed builds the same maze")
expect(differs, "a different seed builds a different one")
expect(A.start.y == B.start.y and A.exit.y == B.exit.y and A.gates[1] == B.gates[1], "with the same doors")

print("== positions")
local cx, cy = 13, 4
local wx, wy, wz = ML.CellCenter(M, cx, cy)
local rx, ry = ML.CellOf(M, wx, wz)
expect(rx == cx and ry == cy and wy == BASE.y, "a cell's centre is inside that cell")
expect(ML.CellOf(M, BASE.x - 5, 0) == nil and ML.CellOf(M, BASE.x + 40 * 14 + 5, 0) == nil, "outside the maze there is no cell")
expect(ML.SectionOf(M, 1) == 1 and ML.SectionOf(M, 8) == 1 and ML.SectionOf(M, 9) == 2 and ML.SectionOf(M, 40) == 5, "the section of a column")
local x1 = ML.CellCenter(M, 1, 1)
local x40 = ML.CellCenter(M, 40, 1)
expect(math.abs((x40 - x1) - 39 * 14) < 1e-9, "cells are 14 studs apart")

print("== finding the way")
local T = build(21)
local d = ML.Distances(T, T.exit.x, T.exit.y)
local walk, x, y, steps = true, T.start.x, T.start.y, 0
while not (x == T.exit.x and y == T.exit.y) and steps < 2000 do
    local nx, ny = ML.NextStep(T, x, y, T.exit.x, T.exit.y, d)
    if not nx then walk = false break end
    if d[nx][ny] ~= d[x][y] - 1 then walk = false break end
    x, y, steps = nx, ny, steps + 1
end
expect(walk and steps == d[T.start.x][T.start.y], "following NextStep walks the shortest way to the exit (" .. steps .. " steps)")
expect(ML.NextStep(T, 5, 5, 5, 5) == nil, "no next step when you are already there")
local nb = ML.Neighbours(T, T.start.x, T.start.y)
local crossesWall = false
for _, n in ipairs(nb) do if T.cells[T.start.x][T.start.y][n.dir] then crossesWall = true end end
expect(not crossesWall and #nb >= 1, "neighbours never cross a wall")

print("== walls for the builder")
local W = ML.Walls(T)
local total = 0
for _, w in ipairs(W) do total += w.length end
local edges = 0
for gx = 1, T.width do
    for gy = 1, T.height do
        local c = T.cells[gx][gy]
        if gy == 1 and c.N then edges += 1 end
        if c.S then edges += 1 end
        if gx == 1 and c.W then edges += 1 end
        if c.E then edges += 1 end
    end
end
expect(math.abs(total - edges * T.cell) < 1e-6, "the wall segments add up to exactly the walls in the maze (" .. #W .. " segments for " .. edges .. " wall edges)")
expect(#W < edges, "straight runs are joined into single segments")
local badSection = false
for _, w in ipairs(W) do if w.section < 1 or w.section > T.sections then badSection = true end end
expect(not badSection, "every segment belongs to a section")
local perimeterOk = true
local minX, maxX = 1e9, -1e9
for _, w in ipairs(W) do minX, maxX = math.min(minX, w.x - (w.along == "x" and w.length / 2 or 0)), math.max(maxX, w.x + (w.along == "x" and w.length / 2 or 0)) end
expect(math.abs(minX - BASE.x) < 1e-6 and math.abs(maxX - (BASE.x + 40 * 14)) < 1e-6, "the walls span exactly the maze's width")

print("== dead ends and loops")
local dead = ML.DeadEnds(T)
expect(#dead > 10 and #dead < 160, "there are dead ends to get lost in (" .. #dead .. ")")
local stone, void = 0, 0
for _, e in ipairs(dead) do if e.x <= 8 then stone += 1 elseif e.x > 32 then void += 1 end end
local totalStone, totalVoid = 0, 0
for seed = 1, 100 do
    local Q = build(seed)
    for _, e in ipairs(ML.DeadEnds(Q)) do if e.x <= 8 then totalStone += 1 elseif e.x > 32 then totalVoid += 1 end end
end
expect(totalVoid > totalStone, "the last section has more dead ends than the first (Void " .. totalVoid .. ", Stone " .. totalStone .. " over 100 mazes)")


print("== the Zombie Golem hunts along the corridors")
expect(math.abs(MD.ZombieSpeed(0) - 16 * 0.70) < 1e-9 and math.abs(MD.ZombieSpeed(300) - 16 * 1.05) < 1e-9, "it starts at 70% of a player's speed and ends at 105%")
local monotone = true
for t = 1, 300 do if MD.ZombieSpeed(t) < MD.ZombieSpeed(t - 1) then monotone = false end end
expect(monotone and MD.ZombieSpeed(1000) == MD.ZombieSpeed(300), "it only ever speeds up, and stops at the top speed")

local function cellTargetPos(Q, cx, cy) local x, _, z = ML.CellCenter(Q, cx, cy) return x, z end

local Q = build(31)
local zsleep = MZ.New(Q)
local x0, z0 = zsleep.x, zsleep.z
local cG, info0 = MZ.Step(Q, zsleep, { { id = 1, x = x0 + 1, z = z0 } }, 5, 0)
expect(#cG == 0 and zsleep.x == x0 and info0 == nil, "while it sleeps it does not move and catches nobody")
expect(MZ.Zone(Q, zsleep.x, zsleep.z) == "lobby", "it sleeps in the lobby by the entrance")

-- a player who stands still deep in the maze is always caught, and the zombie never walks through a wall getting there
local allCaught, wallsOk, worstRatio = true, true, 0
for seed = 1, 25 do
    local R = build(seed * 13 + 3)
    local z = MZ.New(R)
    z.awake = true
    local tx, tz = cellTargetPos(R, R.exit.x, R.exit.y)
    local prevX, prevY, t, caughtAt = nil, nil, 0, nil
    while t < 400 and not caughtAt do
        local caught = MZ.Step(R, z, { { id = 7, x = tx, z = tz } }, 0.1, t)
        t += 0.1
        local cx, cy = ML.CellOf(R, z.x, z.z)
        if cx and prevX and (cx ~= prevX or cy ~= prevY) then
            local adjacent = false
            for _, n in ipairs(ML.Neighbours(R, prevX, prevY)) do if n.x == cx and n.y == cy then adjacent = true end end
            if not adjacent then wallsOk = false end
        end
        if cx then prevX, prevY = cx, cy end
        if #caught > 0 then caughtAt = t end
    end
    if not caughtAt then allCaught = false else
        local d = ML.Distances(R, R.start.x, R.start.y)[R.exit.x][R.exit.y]
        worstRatio = math.max(worstRatio, caughtAt / (d * R.cell / (16 * 0.70) + 3))
    end
end
expect(allCaught, "a player who stands still at the exit is caught on all 25 mazes")
expect(wallsOk, "the zombie only ever steps between neighbouring cells: never through a wall")
expect(worstRatio < 1.1, "and it arrives in about the time its path and speed say (worst " .. string.format("%.2f", worstRatio) .. " of the estimate)")

-- it picks the nearest player by the corridors, not by a straight line
local rightPick = true
for seed = 1, 60 do
    local R = build(seed * 5 + 1)
    local z = MZ.New(R)
    z.awake = true
    z.x, z.z = cellTargetPos(R, 12, 5)
    local a = { id = "a", x = 0, z = 0 }
    local b = { id = "b", x = 0, z = 0 }
    a.x, a.z = cellTargetPos(R, 12 + 1 + (seed % 3), 5 - 2 + (seed % 4))
    b.x, b.z = cellTargetPos(R, 25, 2 + (seed % 7))
    local _, info = MZ.Step(R, z, { a, b }, 0.01, 0)
    local da = ML.Distances(R, 12, 5)
    local ax, ay = ML.CellOf(R, a.x, a.z)
    local bx, by = ML.CellOf(R, b.x, b.z)
    local nearest = da[ax][ay] <= da[bx][by] and "a" or "b"
    if info and info.target ~= nearest then rightPick = false end
end
expect(rightPick, "it hunts whichever player is nearest along the corridors")

-- a perfect runner outruns it; a player who hides in the lobby is caught
local function runnerSurvives(R)
    local z = MZ.New(R)
    local path = {}
    local d = ML.Distances(R, R.exit.x, R.exit.y)
    local cx, cy = R.start.x, R.start.y
    path[1] = { cx, cy }
    while not (cx == R.exit.x and cy == R.exit.y) do cx, cy = ML.NextStep(R, cx, cy, R.exit.x, R.exit.y, d) path[#path + 1] = { cx, cy } end
    local rx, rz = R.base.x - 8, select(3, ML.CellCenter(R, 1, R.start.y))
    local idx, t = 1, 0
    local wake = MD.HEADSTART_SECONDS
    while t < 400 do
        t += 0.1
        if t >= wake then z.awake = true end
        local step = 16 * 0.1
        while step > 0 and idx <= #path do
            local gx, _, gz = ML.CellCenter(R, path[idx][1], path[idx][2])
            local dx, dz = gx - rx, gz - rz
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist <= step then rx, rz, step, idx = gx, gz, step - dist, idx + 1 else rx, rz, step = rx + dx / dist * step, rz + dz / dist * step, 0 end
        end
        if idx > #path then return true, t end
        local caught = MZ.Step(R, z, { { id = 1, x = rx, z = rz } }, 0.1, math.max(0, t - wake))
        if #caught > 0 then return false, t end
    end
    return false, t
end
local survived, slowest = 0, 0
for seed = 1, 40 do
    local ok, t = runnerSurvives(build(seed * 17 + 9))
    if ok then survived += 1 slowest = math.max(slowest, t) end
end
expect(survived == 40, "a runner who never stops and never takes a wrong turn escapes on all 40 mazes (slowest " .. string.format("%.0f", slowest) .. " s)")
local lobbyZ = MZ.New(Q)
lobbyZ.awake = true
local lx, lz = Q.base.x - 6, select(3, ML.CellCenter(Q, 1, Q.start.y))
local gotHim, tt = false, 0
while tt < 60 and not gotHim do
    local c = MZ.Step(Q, lobbyZ, { { id = 3, x = lx, z = lz } }, 0.1, tt)
    tt += 0.1
    gotHim = #c > 0
end
expect(gotHim, "a player who stays in the lobby is caught too")
local nobody = MZ.Step(Q, lobbyZ, {}, 1, 0)
expect(#nobody == 0, "with nobody to hunt it stands still")
local escapedZ = MZ.New(Q)
escapedZ.awake = true
local ex, ez = Q.base.x + 40 * 14 + 30, select(3, ML.CellCenter(Q, 40, Q.exit.y))
local cEsc, infoEsc = MZ.Step(Q, escapedZ, { { id = 4, x = ex, z = ez } }, 1, 0)
expect(#cEsc == 0 and infoEsc == nil, "a player who has escaped is not hunted")


print("== the round clock")
local round = MR.New(1000000)
expect(MR.CYCLE == 20 + 25 + 300 + 25, "a round is gather, head start, hunt and intermission (" .. MR.CYCLE .. " s)")
local idx, into = MR.Locate(1000000)
expect(round.index == idx and round.startedAt == 1000000 - into, "a round is numbered from the clock")
expect(MR.Phase(round, round.startedAt + 5) == "gather" and MR.Phase(round, round.opensAt + 5) == "headstart"
    and MR.Phase(round, round.wakesAt + 5) == "hunt" and MR.Phase(round, round.endsAt + 5) == "intermission", "the phases follow in order")
expect(MR.CanEnter(round, round.startedAt + 1) and MR.CanEnter(round, round.opensAt + 10) and MR.CanEnter(round, round.wakesAt + 100), "you can walk in while gathering, in the head start and well into the hunt")
expect(not MR.CanEnter(round, round.endsAt - MD.LATE_ENTRY_CUTOFF + 1) and not MR.CanEnter(round, round.endsAt + 5), "but not in the last minute of the hunt, or in the intermission")
local sped = MR.New(2000000)
MR.Escape(sped, 1, sped.wakesAt + 20, 80)
expect(not MR.CanEnter(sped, sped.wakesAt + 21), "once someone escapes and the hunt is cut short, the door closes")
expect(not MR.GateOpen(round, round.opensAt - 1) and MR.GateOpen(round, round.opensAt), "the gate opens after the gathering time")
expect(MR.HuntElapsed(round, round.wakesAt - 5) == 0 and MR.HuntElapsed(round, round.wakesAt + 12) == 12, "the hunt clock starts when the zombie wakes")
expect(MR.RunElapsed(round, round.opensAt + 50) == 50, "your run is timed from the gate opening")
expect(not MR.Running(round, round.opensAt - 1) and MR.Running(round, round.wakesAt + 1) and not MR.Running(round, round.endsAt), "the run is on between the gate opening and the hunt ending")
local same1, same2 = MR.New(1000000), MR.New(1000000 + 7)
expect(same1.seed == same2.seed and same1.index == same2.index, "every server at the same moment is in the same round with the same maze")
expect(MR.New(1000000 + MR.CYCLE).seed ~= round.seed, "the next round has a new maze")
local events, nextRound = MR.Step(round, round.startedAt + 100)
expect(#events == 0 and nextRound == round, "nothing happens mid-round")
events, nextRound = MR.Step(round, round.nextStart + 1)
expect(#events == 1 and events[1].kind == "new" and nextRound.index == round.index + 1, "when the intermission ends a new round starts")
local r2 = MR.New(2000000)
local at = r2.wakesAt + 30
expect(MR.Escape(r2, 1, at, 80) == true and r2.endsAt == at + MD.ESCAPE_SPEEDUP, "the first escape shortens the hunt for everyone else")
expect(MR.Escape(r2, 2, at + 5, 90) == false and r2.endsAt == at + MD.ESCAPE_SPEEDUP and #r2.escapes == 2, "a second escape does not shorten it again")
local r3 = MR.New(3000000)
local originalEnd = r3.endsAt
expect(MR.Escape(r3, 1, originalEnd - 10, 100) == false and r3.endsAt == originalEnd, "an escape with less than the speed-up left changes nothing")

print("== the coin curve")
local TODAY = 20000
local never, always = function() return 0.999 end, function() return 0 end
local function player(level) return { PlayerLevel = level or 10, EmberCoins = 0, Inventory = {} } end
local prev, rising = 0, true
for n = 1, 5 do
    local c = MD.SectionCoins(10, n)
    if c <= prev then rising = false end
    prev = c
end
expect(rising, "every section pays more than the one before")
local s1, s5 = MD.SectionCoins(10, 1), MD.SectionCoins(10, 5)
expect(s5 / s1 > 7 and s5 / s1 < 14, "section 5 pays about 11x section 1 (" .. s1 .. " -> " .. s5 .. ")")
expect(MD.SectionCoins(30, 3) > MD.SectionCoins(5, 3), "higher player levels earn more")

print("== paying a section")
local d = player(10)
local r = MW.PaySection(d, 1, TODAY, { rng = never })
expect(r.coins == MD.SectionCoins(10, 1) and d.EmberCoins == r.coins, "section 1 pays its coins (" .. r.coins .. ")")
expect(r.material and r.material.id == "GraniteShard" and d.Inventory.GraniteShard == 12, "Stone pays Granite Shards")
local GDATA = load("game/ReplicatedStorage/Shared/Data/GolemData")
local matches = true
for _, name in ipairs(MD.SECTIONS) do
    local b = MD.Bundles[name]
    if not b or GDATA.Elements[name].primaryMaterial ~= b.id then matches = false end
end
expect(matches, "each section pays its own element's material")
local allExist = true
for _, b in pairs(MD.Bundles) do if not MAT.Get(b.id) then allExist = false end end
for _, rd in ipairs(MD.RareDrops) do if not MAT.Get(rd.id) then allExist = false end end
expect(allExist, "every material the maze pays exists")
d = player(10)
for i = 1, 5 do MW.PaySection(d, i, TODAY, { rng = never }) end
expect(d.Inventory.GraniteShard == 12 and d.Inventory.IgniteOre == 10 and d.Inventory.GlacialCrystal == 8 and d.Inventory.ChargedFlint == 6 and d.Inventory.ShadowDust == 5, "five sections pay five different materials")
d = player(10)
r = MW.PaySection(d, 4, TODAY, { rng = always })
expect(r.rare ~= nil and d.Inventory.ElementalIngot == 2, "a lucky section drops something rare")
d = player(10)
local bundles = 0
for i = 1, 40 do
    local pr = MW.PaySection(d, 1 + (i % 5), TODAY, { rng = never })
    if pr.material then bundles += 1 end
end
expect(bundles == MD.BUNDLES_PER_DAY, "only " .. MD.BUNDLES_PER_DAY .. " bundles are paid a day (" .. bundles .. ")")
d = player(10)
local state = MW.State(d, TODAY)
state.mazeEarned = MW.DailyCap(d) - 3
r = MW.PaySection(d, 5, TODAY, { rng = never })
expect(r.coins == 3 and r.capped and d.EmberCoins == 3, "coins stop at the daily allowance")
expect(r.xp > 0 and r.material ~= nil, "but XP and the material bundle still come")
d = player(10)
r = MW.PaySection(d, 2, TODAY, { rng = never, coinMultiplier = 2 })
expect(r.coins == MD.SectionCoins(10, 2) * 2, "a coin event doubles it")
d = player(10)
MW.PaySection(d, 3, TODAY, { rng = never })
MW.PaySection(d, 5, TODAY, { rng = never })
expect(MW.State(d, TODAY).mazeBest == 5, "the deepest section is remembered")
expect(MD.PlayerXp(5) > MD.PlayerXp(1), "player XP is worth more deeper in")

print("== the escape chest and the daily challenge")
d = player(10)
r = MW.PayEscape(d, 5, TODAY, { rng = never })
expect(r.firstToday and r.coins == MD.SectionCoins(10, 5) * MD.ESCAPE_CHEST_MULT * MD.FIRST_ESCAPE_MULT, "the first escape of the day pays double (" .. r.coins .. ")")
local r2b = MW.PayEscape(d, 5, TODAY, { rng = never })
expect(not r2b.firstToday and r2b.coins == MD.SectionCoins(10, 5) * MD.ESCAPE_CHEST_MULT, "later escapes pay the normal chest")
expect(r.rare.qty == 3 * MD.RareFor(5).qty and r2b.rare.qty == MD.RareFor(5).qty, "and the first one's rare drop is tripled")
local nextDay = MW.PayEscape(d, 5, TODAY + 1, { rng = never })
expect(nextDay.firstToday, "the next day is a first again")
d = player(10)
local target = MD.DailyTarget(TODAY)
expect(MW.PayDaily(d, target - 1, TODAY) == nil, "short of the daily target pays nothing")
local dd = MW.PayDaily(d, target, TODAY)
expect(dd and dd.target == target and dd.coins == MD.SectionCoins(10, target) * MD.DAILY_COIN_MULT, "reaching the daily target pays a chest (" .. (dd and dd.coins or 0) .. ")")
expect(MW.PayDaily(d, 5, TODAY) == nil and MW.DailyDone(d, TODAY), "once a day")
expect(MW.PayDaily(d, 5, TODAY + 1) ~= nil, "and again tomorrow")
local varied = {}
for day = 0, 6 do varied[MD.DailyTarget(day)] = true end
expect(varied[2] and varied[5], "the target changes through the week: easy days and a hard one")

print("== medals and balance")
expect(MD.Medal(100) == "Gold" and MD.Medal(150) == "Silver" and MD.Medal(200) == "Bronze" and MD.Medal(400) == nil, "faster is better: Gold, Silver, Bronze, then nothing")
local cap10 = MW.DailyCap(player(10))
local run10 = MW.FullRunCoins(10, true)
expect(run10 > 350 and run10 < 520 and cap10 / run10 > 5, "a full first run pays " .. run10 .. " coins: about six reach the daily allowance (" .. cap10 .. ")")
expect(MW.FullRunCoins(10, false) < run10, "later runs pay less than the first of the day")

print("== the Maze Golem pieces: a long goal")
local always, never2 = function() return 0 end, function() return 0.999 end
expect(#MD.PIECES == 5 and MD.PIECES[1].section == "Stone" and MD.PIECES[5].section == "Void", "five pieces, one per section")
local allMaterials = true
for _, pc in ipairs(MD.PIECES) do local m = MAT.Get(pc.id) if not (m and m.tradeable == false) then allMaterials = false end end
expect(allMaterials, "every piece is a real material and bound to the account")
local RDm = load("game/ReplicatedStorage/Shared/Data/RecipeData")
local bpM = RDm.Blueprints[MD.PIECE_BLUEPRINT]
local needs = 0
for _, m in ipairs(bpM.materialsRequired) do if MD.PieceIndex(m.id) then needs += m.qty expect(m.qty == MD.PIECE_NEED, m.id .. " x" .. m.qty) end end
expect(bpM.tier == 5 and needs == 5 * MD.PIECE_NEED, "the Maze Golem is a Tier 5 craft of " .. needs .. " pieces")

d = player(10)
local pc, why = MW.RollPiece(d, 3, false, TODAY, { rng = never2 })
expect(pc == nil and why == nil, "a bad roll gives nothing")
pc = MW.RollPiece(d, 3, false, TODAY, { rng = always })
expect(pc and pc.id == "MazePick" and d.Inventory.MazePick == 1, "clearing Frost with a good roll gives the Frost piece")
expect(table.find(d.Blueprints, MD.PIECE_BLUEPRINT) and pc.firstBlueprint, "the first piece finds the Maze Golem blueprint")
pc = MW.RollPiece(d, 5, false, TODAY, { rng = always })
expect(pc and not pc.firstBlueprint, "only the first piece gives the blueprint")
local capReached, capWhy = MW.RollPiece(d, 1, false, TODAY, { rng = always })
expect(capReached == nil and capWhy == "capped", "no more than " .. MD.PIECE_CAP_PER_DAY .. " pieces a day")
expect(MW.RollPiece(d, 1, false, TODAY + 1, { rng = always }) ~= nil, "and the allowance returns tomorrow")

d = player(10)
d.Inventory.MazeFoot = MD.PIECE_NEED
pc = MW.RollPiece(d, 1, false, TODAY, { rng = always })
expect(pc and pc.id ~= "MazeFoot", "a piece you have enough of is replaced by one you still need")
d = player(10)
for _, p2 in ipairs(MD.PIECES) do d.Inventory[p2.id] = MD.PIECE_NEED end
local full, fullWhy = MW.RollPiece(d, 2, false, TODAY, { rng = always })
expect(full == nil and fullWhy == "full", "with a full set nothing drops until you craft")
d = player(10)
pc = MW.RollPiece(d, 1, true, TODAY, { rng = function() return 0 end })
expect(pc ~= nil, "the escape chest can drop a piece too")

d = player(10)
local clears = 0
local got
repeat
    clears += 1
    got = MW.RollPiece(d, 1, false, TODAY + clears, { rng = never2 })
until got or clears > MD.PIECE_PITY + 2
expect(got and clears == MD.PIECE_PITY, "bad luck is capped: a guaranteed piece after " .. MD.PIECE_PITY .. " section clears (took " .. clears .. ")")

-- how long does a keen player take? 6 full escapes a day, a fixed seed of luck
local rngState = 12345
local function lcg() rngState = (rngState * 1103515245 + 12345) % 2147483648 return rngState / 2147483648 end
local function daysToSet(runsPerDay)
    local pd = player(10)
    for day = 1, 400 do
        for _ = 1, runsPerDay do
            for section = 1, 5 do MW.RollPiece(pd, section, false, TODAY + day, { rng = lcg }) end
            MW.RollPiece(pd, 5, true, TODAY + day, { rng = lcg })
        end
        local done = true
        for _, p2 in ipairs(MD.PIECES) do if (pd.Inventory[p2.id] or 0) < MD.PIECE_NEED then done = false end end
        if done then return day end
    end
    return 400
end
local keen, casual = daysToSet(6), daysToSet(2)
print("   days to a full set: 6 escapes a day = " .. keen .. ", 2 a day = " .. casual)
expect(keen >= 35 and keen <= 70, "even a keen player needs 5-10 weeks (" .. keen .. " days)")
expect(casual >= keen and casual <= 220, "a casual player still gets there (" .. casual .. " days)")

local GDm = load("game/ReplicatedStorage/Shared/Data/GolemData")
expect(math.abs(MW.GolemBonus(1) - 0.10) < 1e-9 and math.abs(MW.GolemBonus(9) - 0.30) < 1e-9, "Labyrinth Mind: +10% a Golem, capped at +30%")
expect(GDm.Specials.Maze.tier == 5 and GDm.Elements.Maze.special, "the Maze Golem is a Tier 5 special")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
