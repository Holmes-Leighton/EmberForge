QUIET = true
local TD     = load("game/ReplicatedStorage/Shared/Data/TowerData")
local TL     = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local Runner = load("SSS/EmberForge/Services/TowerRunner")

local T = TL.Build({ levels = 30, seed = 21, base = TD.BASE })
local function newRun(now, tower)
    local log = { levels = {}, respawns = {} }
    local hooks = {
        onLevel   = function(l, s) table.insert(log.levels, l) end,
        onRespawn = function(reason, level, cp) table.insert(log.respawns, { reason = reason, level = level, cp = cp }) end,
        onSummit  = function(s, r) log.summit = { s = s, r = r } end,
        onAbandon = function(reason) log.abandon = reason end,
    }
    return Runner.New(tower or T, hooks, now), log
end

-- A bot that walks straight between level starts at `speed`, hopping over spinners and crushers (so these tests are about levels, falls and lava)
local function walkTo(run, now, from, to, speed)
    local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
    local dist = math.sqrt(dx * dx + dz * dz + dy * dy)
    local steps = math.max(1, math.floor(dist / speed / 0.1))
    for i = 1, steps do
        local f = i / steps
        now += 0.1
        local x = from.x + dx * f
        local lift = 0
        local lv = to.level or run.highest                          -- hop only over the obstacles of the level being walked (a ledge below another level's crusher is not under it)
        for _, sp in ipairs(run.byLevel[lv].spinners) do if math.abs(x - sp.x) <= sp.radius + 2 then lift = 7 end end
        for _, c in ipairs(run.byLevel[lv].crushers) do if math.abs(x - c.x) <= c.sx then lift = 9 end end
        for _, sw in ipairs(run.byLevel[lv].sweepers) do if math.abs(x - sw.x) <= 4 then lift = 8 end end
        for _, k in ipairs(run.byLevel[lv].kills) do if math.abs(x - k.x) <= k.sx / 2 + 1 then lift = 7 end end
        Runner.Step(run, now, x, from.y + dy * f + lift, from.z + dz * f)
    end
    return now
end

-- The route a real player takes: every platform of every level in order, standing on its middle
local function waypoints(tower)
    local out = {}
    for i = 1, #tower.levels do
        local lv = tower.levels[i]
        local order = TL.WalkOrder(tower, i)
        if lv.dir == 1 then table.sort(order, function(a, b) return a.x1 < b.x1 end) else table.sort(order, function(a, b) return a.x2 > b.x2 end) end
        for k, piece in ipairs(order) do
            out[#out + 1] = { x = (piece.x1 + piece.x2) / 2, y = piece.top + 3, z = piece.z, level = i, first = (k == 1) }
        end
    end
    return out
end

local function climb(run, now, speed, upToLevel)
    local tower = run.T
    local pts = waypoints(tower)
    local pos
    local started = false
    for _, w in ipairs(pts) do
        if w.level >= run.highest then
            if not started then pos = w started = true
            elseif w.level <= (upToLevel or #tower.levels) then
                now = walkTo(run, now, pos, w, speed)
                pos = w
            end
        end
    end
    return now, pos
end

print("== a full climb")
local run, log = newRun(1000)
local first = T.checkpoints[1]
Runner.Step(run, 1000, first.x, first.y, first.z)
local now, pos = climb(run, 1000, 6)
expect(run.highest == 30 and #log.levels == 29, "a steady climber reaches every level in order (" .. run.highest .. ")")
local inOrder = true
for k, l in ipairs(log.levels) do if l ~= k + 1 then inOrder = false end end
expect(inOrder, "the levels are reported in order")
expect(#log.respawns == 0, "with no falls and no lava hits (" .. #log.respawns .. ")")
now = walkTo(run, now, pos, T.finish, 6)
expect(log.summit ~= nil and run.finished, "walking to the finish is the summit")
expect(log.summit.s > TD.TOP_MIN_TIME and log.summit.s < 1500, "a believable summit time (" .. string.format("%.0f", log.summit.s) .. " s)")
local before = log.summit.s
Runner.Step(run, now + 1, T.finish.x, T.finish.y, T.finish.z)
expect(log.summit.s == before, "the summit counts once")

print("== levels must be taken in order, and not impossibly fast")
run, log = newRun(1000)
Runner.Step(run, 1000, first.x, first.y, first.z)
local third = T.checkpoints[T.levels[3].firstCheckpoint]
Runner.Step(run, 1000.1, third.x, third.y, third.z)
expect(run.highest == 1 and #log.levels == 0, "jumping straight to level 3 earns nothing")
run, log = newRun(1000)
Runner.Step(run, 1000, first.x, first.y, first.z)
local second = T.checkpoints[T.levels[2].firstCheckpoint]
Runner.Step(run, 1001, second.x, second.y, second.z)
expect(run.highest == 1, "reaching a level one second after the last is too fast to be real")
Runner.Step(run, 1000 + TD.LEVEL_MIN_MINIMUM + 1, second.x, second.y, second.z)
expect(run.highest == 2, "a few seconds later it counts")

print("== falling never costs a level")
run, log = newRun(1000)
Runner.Step(run, 1000, first.x, first.y, first.z)
now = climb(run, 1000, 6, 6)
expect(run.highest == 6, "up to level 6")
local cp6 = T.checkpoints[T.levels[6].firstCheckpoint]
Runner.Step(run, now + 0.1, cp6.x + 5, cp6.y - 60, cp6.z)
expect(#log.respawns == 1 and log.respawns[1].reason == "fell" and log.respawns[1].level == 6, "a fall sends you to the start of level 6, not lower")
expect(log.respawns[1].cp.y == cp6.y and run.highest == 6, "and you keep your level")
expect(Runner.Elapsed(run, now + 1) == (now + 1 - 1000) + TD.RESPAWN_PENALTY, "a fall adds the time penalty")

print("== the lava")
expect(not T.levels[5].lava and T.levels[15].lava and T.levels[28].lava, "lava starts above level 10")
run, log = newRun(1000)
Runner.Step(run, 1000, first.x, first.y, first.z)
expect(Runner.LavaY(run, 1000) == nil, "no lava on the low levels")
local c15 = T.checkpoints[T.levels[15].firstCheckpoint]
run.highest = 15
Runner.StartLava(run, 2000)
local y0 = Runner.LavaY(run, 2000)
expect(math.abs(y0 - (c15.y - TD.LAVA_HEAD)) < 1e-6, "on arrival it is a head start below the level")
expect(Runner.LavaY(run, 2010) > y0, "and it rises")
local rise2 = Runner.LavaY(run, 2010) - y0
run.highest = 28
Runner.StartLava(run, 3000)
local rise3 = Runner.LavaY(run, 3010) - Runner.LavaY(run, 3000)
expect(rise3 > rise2 / 1 * 0 + rise2 * 1.2, "the lava is faster at the top (" .. string.format("%.1f vs %.1f studs in 10 s", rise3, rise2) .. ")")
-- a player who stands still on level 15 is caught
run, log = newRun(5000)
run.highest = 15
Runner.StartLava(run, 5000)
local t = 5000
for _ = 1, 1500 do
    t += 0.1
    Runner.Step(run, t, c15.x, c15.y, c15.z)
    if #log.respawns > 0 then break end
end
expect(#log.respawns == 1 and log.respawns[1].reason == "lava" and log.respawns[1].level == 15, "standing still lets the lava catch you")
expect(t - 5000 > 30 and t - 5000 < 80, "after a fair wait (" .. string.format("%.0f", t - 5000) .. " s)")
local newY = Runner.LavaY(run, t + 0.1)
expect(newY < c15.y - TD.LAVA_HEAD + 1, "and the lava is reset to a fresh head start")
-- the climbers
local function climbHigh(speed)
    local r, l = newRun(1000)
    Runner.Step(r, 1000, first.x, first.y, first.z)
    local n = climb(r, 1000, speed, 30)
    local lavaHits = 0
    for _, rs in ipairs(l.respawns) do if rs.reason == "lava" then lavaHits += 1 end end
    return lavaHits, r.highest
end
local slowHits, slowLevel = climbHigh(6)
expect(slowHits == 0 and slowLevel == 30, "a 6 studs/s climber is never caught by the lava (" .. slowHits .. " catches)")
local crawlHits = climbHigh(2.2)
expect(crawlHits > 0, "a 2.2 studs/s crawler is (" .. crawlHits .. " catches)")

print("== spinners and crushers")
local sp = T.spinners[1]
run, log = newRun(7000)
local lvStart = T.checkpoints[T.levels[sp.level].firstCheckpoint]
run.highest = sp.level
Runner.Step(run, 7000, lvStart.x, lvStart.y, lvStart.z)
local ang = sp.phase + sp.omega * 7000.1
Runner.Step(run, 7000.1, sp.x + 5 * math.cos(ang), sp.y + 3, sp.z + 5 * math.sin(ang))
expect(#log.respawns == 1 and log.respawns[1].reason == "spun", "a spinner bar knocks you back to the level start")

print("== death tiles")
local CRun2 = load("SSS/EmberForge/Services/CourierRunner")
local tile = { x = 100, y = 20, z = 140, sx = 5.1, sz = 5.1 }
expect(CRun2.KillTileHits(tile, 100, 23, 140), "standing on a death tile is a hit")
expect(not CRun2.KillTileHits(tile, 100, 29, 140), "jumping over one is safe")
expect(not CRun2.KillTileHits(tile, 106, 23, 140), "the tile next to it is safe")
expect(not CRun2.KillTileHits(tile, 100, 10, 140), "below the floor is safe")
local kTower = TL.Build({ levels = 30, seed = 3, base = TD.BASE })
local k1 = kTower.kills[1]
local krun, klog = newRun(9500, kTower)
krun.highest = k1.level
local kcp = kTower.checkpoints[kTower.levels[k1.level].firstCheckpoint]
Runner.Step(krun, 9500, kcp.x, kcp.y, kcp.z)
Runner.Step(krun, 9500.1, k1.x, k1.y + 3, k1.z)
expect(#klog.respawns == 1 and klog.respawns[1].reason == "burned" and klog.respawns[1].level == k1.level, "stepping on a death tile sends you back to the start of the level, not lower")

print("== sweeper bars")
local CRun = load("SSS/EmberForge/Services/CourierRunner")
local sw = { x = 100, y = 20, z = 140, amp = 4, period = 3, phase = 0, thick = 1.6 }
expect(math.abs(CRun.SweeperZ(sw, 0) - 140) < 1e-6 and math.abs(CRun.SweeperZ(sw, 0.75) - 144) < 1e-6 and math.abs(CRun.SweeperZ(sw, 2.25) - 136) < 1e-6, "the bar slides 4 studs either side of the middle")
expect(CRun.SweeperHits(sw, 0, 100, 23, 140), "standing where the bar is, at ground level, is a hit")
expect(not CRun.SweeperHits(sw, 0.75, 100, 23, 139), "the bar has moved away: safe (it is at the far edge)")
expect(not CRun.SweeperHits(sw, 0, 100, 31, 140), "jumping clear over the bar is safe")
expect(not CRun.SweeperHits(sw, 0, 110, 23, 140), "somewhere else along the beam is safe")
expect(not CRun.SweeperHits(sw, 0, 100, 10, 140), "below the platform is safe")
local swTower = TL.Build({ levels = 30, seed = 3, base = TD.BASE })
local s1 = swTower.sweepers[1]
local srun, slog = newRun(9000, swTower)
srun.highest = s1.level
local lvCp = swTower.checkpoints[swTower.levels[s1.level].firstCheckpoint]
Runner.Step(srun, 9000, lvCp.x, lvCp.y, lvCp.z)
Runner.Step(srun, 9000.1, s1.x, s1.y + 3, CRun.SweeperZ(s1, 9000.1))
expect(#slog.respawns == 1 and slog.respawns[1].reason == "swept", "a sweeper bar sends a player it hits back to the level start")

print("== cheats and drop-outs")
run, log = newRun(1000)
Runner.Step(run, 1000, first.x, first.y, first.z)
for k = 1, 4 do Runner.Step(run, 1000 + k * 0.2, first.x + k * 60, first.y, first.z) end
expect(log.abandon == "speed", "teleporting along the tower drops the run (" .. tostring(log.abandon) .. ")")
run, log = newRun(1000)
Runner.Step(run, 1000, first.x, first.y, first.z)
Runner.Step(run, 1001, first.x + 5000, first.y, first.z)
expect(log.abandon == "left", "being far from the tower drops it")

print("== a Pro tower and a short tower")
local pro = TL.Build({ levels = 60, seed = 5, base = TD.BASE })
local pr, plog = newRun(1000, pro)
Runner.Step(pr, 1000, pro.checkpoints[1].x, pro.checkpoints[1].y, pro.checkpoints[1].z)
local tt, pos2 = climb(pr, 1000, 6)
tt = walkTo(pr, tt, pos2, pro.finish, 6)
expect(pr.highest == 60 and plog.summit ~= nil, "a 60-level Pro tower can be climbed too")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
