QUIET = true
local CD     = load("game/ReplicatedStorage/Shared/Data/CourierData")
local CCD    = load("game/ReplicatedStorage/Shared/Data/CartCourseData")
local Runner = load("SSS/EmberForge/Services/CourierRunner")

local function newRun(id, now)
    local log = { cps = {}, respawns = {} }
    local hooks = {
        onCheckpoint = function(i, sec) table.insert(log.cps, { i = i, sec = sec }) end,
        onRespawn    = function(reason, cpIndex, cp) table.insert(log.respawns, { reason = reason, cpIndex = cpIndex, cp = cp }) end,
        onFinish     = function(sec, respawns) log.finish = { sec = sec, respawns = respawns } end,
        onAbandon    = function(reason) log.abandon = reason end,
    }
    return Runner.New(CD.Resolve(id), hooks, now), log
end

-- A player who stands on checkpoint k then the next, walking at `speed` studs/s: feeds positions to the runner every 0.1 s
-- A skilled player: jumps clear over spinner bars and crossing under crushers is done by leaping over them (so this bot tests the checkpoints and the lava,
-- not the obstacles, which have tests of their own below)
local function walkTo(run, now, from, to, speed)
    local L = run.r.layout
    local dx, dz = to.x - from.x, to.z - from.z
    local dist = math.sqrt(dx * dx + dz * dz)
    local steps = math.max(1, math.floor(dist / speed / 0.1))
    for i = 1, steps do
        local f = i / steps
        now += 0.1
        local x = from.x + dx * f
        local lift = 0
        for _, sp in ipairs(L.spinners) do if math.abs(x - sp.x) <= sp.radius + 2 then lift = 7 end end
        for _, c in ipairs(L.crushers) do if math.abs(x - c.x) <= c.sx then lift = 14 end end
        Runner.Step(run, now, x, from.y + (to.y - from.y) * f + lift, from.z + dz * f)
    end
    return now
end

print("== a clean run, checkpoint to checkpoint to the finish")
local run, log = newRun("RookieRun", 1000)
local L = run.r.layout
local now = 1000
local pos = L.checkpoints[1]
Runner.Step(run, now, pos.x, pos.y, pos.z)
for i = 2, #L.checkpoints do
    now = walkTo(run, now, pos, L.checkpoints[i], 6)
    pos = L.checkpoints[i]
end
now = walkTo(run, now, pos, L.finish, 6)
expect(#log.cps == #L.checkpoints - 1, "every checkpoint after the start is reported (" .. #log.cps .. " of " .. (#L.checkpoints - 1) .. ")")
local inOrder = true
for k, c in ipairs(log.cps) do if c.i ~= k + 1 then inOrder = false end end
expect(inOrder, "they come in order")
expect(log.finish ~= nil and log.finish.respawns == 0, "the finish is reported with no falls")
expect(log.finish.sec > 30 and log.finish.sec < 200, "the clock reads a believable time (" .. string.format("%.1f", log.finish.sec) .. " s)")
expect(run.finished and #log.respawns == 0 and log.abandon == nil, "nothing else happened")
local before = log.finish.sec
Runner.Step(run, now + 1, L.finish.x, L.finish.y, L.finish.z)
expect(log.finish.sec == before, "a finished run does not finish twice")

print("== checkpoints must be taken in order")
run, log = newRun("RookieRun", 1000)
L = run.r.layout
Runner.Step(run, 1000, L.checkpoints[1].x, L.checkpoints[1].y, L.checkpoints[1].z)
local far = L.checkpoints[4]                               -- jumped straight to the fourth checkpoint (a skip)
Runner.Step(run, 1000.1, far.x, far.y, far.z)
expect(#log.cps == 0, "skipping ahead earns nothing")
expect(run.nextCP == 2, "the next checkpoint is still the second")

print("== falling")
run, log = newRun("RookieRun", 1000)
L = run.r.layout
local cp1 = L.checkpoints[1]
Runner.Step(run, 1000, cp1.x, cp1.y, cp1.z)
Runner.Step(run, 1000.1, cp1.x + 30, cp1.y - 20, cp1.z)
expect(#log.respawns == 1 and log.respawns[1].reason == "fell" and log.respawns[1].cpIndex == 1, "falling well below the checkpoint sends you back to it")
expect(log.respawns[1].cp.x == cp1.x, "to the checkpoint's own position")
expect(run.respawns == 1 and Runner.Elapsed(run, 1010) == 10 + CD.RESPAWN_PENALTY, "and costs a time penalty (" .. Runner.Elapsed(run, 1010) .. " s on a 10 s run)")
-- after reaching checkpoint 2, a fall returns there instead
local cp2 = L.checkpoints[2]
now = 1001
now = walkTo(run, now, cp1, cp2, 6)
Runner.Step(run, now + 0.2, cp2.x + 10, cp2.y - 25, cp2.z)
expect(log.respawns[#log.respawns].cpIndex == 2, "once a checkpoint is reached, falls return to it")

print("== the lava wall")
run, log = newRun("CavernCourier", 1000)
L = run.r.layout
local lava = run.r.def.lava
cp1 = L.checkpoints[1]
local x0 = Runner.LavaX(run, 1000)
expect(math.abs(x0 - (cp1.x - lava.headStart)) < 1e-6, "the lava starts behind you with a head start")
expect(math.abs(Runner.LavaX(run, 1010) - (x0 + lava.speed * 10)) < 1e-6, "and advances at its speed")
Runner.Step(run, 1000, cp1.x, cp1.y, cp1.z)
-- a player who dawdles at the start platform is caught: the wall reaches them after (head start + platform offset) / speed seconds
local t = 1000
for _ = 1, 600 do
    t += 0.1
    Runner.Step(run, t, cp1.x, cp1.y, cp1.z)
    if #log.respawns > 0 then break end
end
expect(#log.respawns == 1 and log.respawns[1].reason == "lava", "standing still lets the lava catch you")
expect(t - 1000 > 15 and t - 1000 < 60, "after a fair wait (" .. string.format("%.0f", t - 1000) .. " s)")
local lx = Runner.LavaX(run, t + 0.1)
expect(lx < cp1.x - lava.headStart + 1, "after a respawn the lava is moved back for a fresh head start")
-- a steady walker stays ahead
run, log = newRun("CavernCourier", 1000)
L = run.r.layout
pos, now = L.checkpoints[1], 1000
Runner.Step(run, now, pos.x, pos.y, pos.z)
for i = 2, #L.checkpoints do
    now = walkTo(run, now, pos, L.checkpoints[i], 6)
    pos = L.checkpoints[i]
end
expect(#log.respawns == 0, "a player walking at 6 studs/s keeps ahead of the lava the whole way (" .. #log.respawns .. " catches)")
for _, id in ipairs({ "CavernCourier", "DeepCourier" }) do
    for _, speed in ipairs({ 6, 2.5 }) do
        run, log = newRun(id, 1000)
        L = run.r.layout
        pos, now = L.checkpoints[1], 1000
        Runner.Step(run, now, pos.x, pos.y, pos.z)
        for i = 2, #L.checkpoints do
            now = walkTo(run, now, pos, L.checkpoints[i], speed)
            pos = L.checkpoints[i]
        end
        local caught = 0
        for _, rs in ipairs(log.respawns) do if rs.reason == "lava" then caught += 1 end end
        if speed == 6 then
            expect(caught == 0, run.r.name .. ": a 6 studs/s runner is never caught by the lava (" .. caught .. ")")
        else
            expect(caught > 0, run.r.name .. ": a 2.5 studs/s crawler is caught (" .. caught .. " times)")
        end
    end
end
run, log = newRun("RookieRun", 1000)
expect(Runner.LavaX(run, 1000) == nil, "a course with no lava has no wall")

print("== spinners")
local spin = { x = 100, y = 20, z = 140, radius = 10, barY = 1.4, thick = 1.4, omega = 1.0, phase = 0 }
-- at t = 0 the bar lies along +X
expect(Runner.SpinnerHits(spin, 0, 105, 23, 140), "standing in the bar's path at ground level is a hit")
expect(not Runner.SpinnerHits(spin, 0, 100, 23, 146), "standing off to the side of the bar is safe")
expect(not Runner.SpinnerHits(spin, 0, 105, 29, 140), "jumping high over the bar is safe")
expect(Runner.SpinnerHits(spin, math.pi / 2, 100, 23, 145), "a quarter turn later the bar has swung to +Z")
expect(not Runner.SpinnerHits(spin, 0, 125, 23, 140), "beyond the bar's end is safe")
run, log = newRun("RookieRun", 1000)
L = run.r.layout
local sp = L.spinners[1]
Runner.Step(run, 1000, L.checkpoints[1].x, L.checkpoints[1].y, L.checkpoints[1].z)
-- stand where the bar passes at this moment, on the spinner's platform
Runner.Step(run, 1000.1, sp.x + 5 * math.cos(sp.phase + sp.omega * 1000.1), sp.y + 3, sp.z + 5 * math.sin(sp.phase + sp.omega * 1000.1))
expect(#log.respawns == 1 and log.respawns[1].reason == "spun", "the runner sends a player the bar hits back to a checkpoint")

print("== crushers")
local cr = { x = 200, y = 30, z = 140, sx = 6, sz = 14, height = 12, open = 4, closed = 2.5, phase = 0 }
local tShut
for x = 100, 120, 0.05 do if not CCD.HazardOpen(cr, x) then tShut = x break end end
expect(Runner.CrusherHits(cr, tShut, 200, 33, 140), "under a shut crusher is a hit")
local tOpen
for x = 100, 120, 0.05 do if CCD.HazardOpen(cr, x) then tOpen = x break end end
expect(not Runner.CrusherHits(cr, tOpen, 200, 33, 140), "under an open one is safe")
expect(not Runner.CrusherHits(cr, tShut, 215, 33, 140), "beside it is safe")
expect(not Runner.CrusherHits(cr, tShut, 200, 50, 140), "above it is safe")
expect(not Runner.CrusherHits(cr, tShut, 200, 24, 140), "on a ledge below its platform is safe (the floor is in the way)")

print("== cheats and drop-outs")
run, log = newRun("RookieRun", 1000)
L = run.r.layout
pos = L.checkpoints[1]
Runner.Step(run, 1000, pos.x, pos.y, pos.z)
for k = 1, 4 do
    Runner.Step(run, 1000 + k * 0.2, pos.x + k * 60, pos.y, pos.z)                  -- 300 studs/s sideways
end
expect(log.abandon == "speed", "teleporting along the course drops the run (" .. tostring(log.abandon) .. ")")
run, log = newRun("RookieRun", 1000)
L = run.r.layout
pos = L.checkpoints[1]
Runner.Step(run, 1000, pos.x, pos.y, pos.z)
Runner.Step(run, 1000.2, pos.x + 20, pos.y, pos.z)                                  -- one quick burst, e.g. a lag spike
Runner.Step(run, 1000.4, pos.x + 22, pos.y, pos.z)
Runner.Step(run, 1000.6, pos.x + 24, pos.y, pos.z)
expect(log.abandon == nil, "one burst is forgiven")
run, log = newRun("RookieRun", 1000)
L = run.r.layout
pos = L.checkpoints[1]
Runner.Step(run, 1000, pos.x, pos.y, pos.z)
Runner.Step(run, 1001, pos.x + 600, pos.y, pos.z)
expect(log.abandon == "left", "walking far away from the course drops the run (" .. tostring(log.abandon) .. ")")
run, log = newRun("RookieRun", 1000)
L = run.r.layout
pos = L.checkpoints[1]
for k = 0, 2500 do Runner.Step(run, 1000 + k * 0.1, pos.x, pos.y, pos.z) if log.abandon then break end end
expect(log.abandon == "idle", "standing around too long drops it (" .. tostring(log.abandon) .. ")")
run, log = newRun("RookieRun", 1000)
Runner.Step(run, 1000, L.checkpoints[1].x, L.checkpoints[1].y, L.checkpoints[1].z)
run.dropped = true
Runner.Step(run, 1001, L.checkpoints[1].x, L.checkpoints[1].y - 50, L.checkpoints[1].z)
expect(#log.respawns == 0, "a dropped run does nothing more")

print("== time and penalties")
run, log = newRun("RookieRun", 1000)
run.respawns = 2
expect(Runner.Elapsed(run, 1030) == 30 + 2 * CD.RESPAWN_PENALTY, "each fall adds the penalty")

print("== lifts, depth movers, orbiters, blades and beam pads")
do
    local CL = load("game/ReplicatedStorage/Shared/Modules/CourierLayout")
    local CR = load("SSS/EmberForge/Services/CourierRunner")
    local L = CL.Build({ base = { x = 0, y = 100, z = 0 }, zRange = 0, modules = {
        { "rest", {} }, { "lift", { rise = 12, period = 6 } }, { "zmover", { amp = 5, period = 6 } }, { "orbit", { radius = 8 } },
        { "pendulum", { len = 34, n = 3 } }, { "beams", { len = 36, cols = 3, rows = 2 } }, { "finish", {} } } })
    local lift = L.lifts[1]
    expect(math.abs(CL.LiftY(lift, 0) - lift.y0) < 1e-6 and math.abs(CL.LiftY(lift, lift.period / 2) - lift.y1) < 1e-6, "a lift rides between its two heights")
    local zm = L.zmovers[1]
    expect(math.abs(CL.ZMoverZ(zm, 0) - zm.z0) < 1e-6 and math.abs(CL.ZMoverZ(zm, zm.period / 2) - zm.z1) < 1e-6, "a depth mover slides toward and away")
    local o = L.orbiters[1]
    local x1, z1 = CL.OrbitPos(o, 0)
    local x2, z2 = CL.OrbitPos(o, math.pi / o.omega)
    expect(math.abs((x1 + x2) / 2 - o.x) < 1e-6 and math.abs((z1 + z2) / 2 - o.z) < 1e-6, "an orbiting platform circles its centre")
    local pd = L.pendulums[2]
    local hit = false
    for t = 0, pd.period, 0.05 do
        local bx, by = CL.PendulumBlade(pd, t)
        if CR.PendulumHits(pd, t, bx, by, pd.z) then hit = true end
    end
    expect(hit, "a swinging blade hits whoever stands in its path")
    expect(not CR.PendulumHits(pd, 0, pd.x, pd.y + 40, pd.z), "but not someone far above it")
    local f = L.beamfields[1]
    local seen, last, repeats, fires, warns = {}, nil, 0, 0, 0
    for slot = 0, 199 do
        local t = slot * f.period + 0.1
        local idx, st = CL.BeamState(f, t)
        if st == "warn" then warns += 1 end
        seen[idx] = true
        if last == idx then repeats += 1 end
        last = idx
        local tf = slot * f.period + f.warn + 0.1
        local i2, s2 = CL.BeamState(f, tf)
        if s2 == "fire" then
            fires += 1
            local c = f.circles[i2]
            if not CR.BeamHits(f, tf, c.x, f.y + 3, c.z) then expect(false, "a firing beam kills someone standing in its circle") break end
            for k, c2 in ipairs(f.circles) do
                if k ~= i2 and CR.BeamHits(f, tf, c2.x, f.y + 3, c2.z) then expect(false, "only the charged circle kills") break end
            end
        end
    end
    local count = 0 for _ in pairs(seen) do count += 1 end
    expect(count == #f.circles, "every circle gets used over time (" .. count .. " of " .. #f.circles .. ")")
    expect(repeats == 0, "never the same circle twice in a row")
    expect(fires == 200 and warns == 200, "every shot warns first, then fires")
    local idx, st = CL.BeamState(f, 0 * f.period + f.warn + f.fire + 0.1)
    expect(st == nil, "between shots every circle is safe")
    local c = f.circles[1]
    expect(not CR.BeamHits(f, f.warn + f.fire + 0.1, c.x, f.y + 3, c.z), "nobody is hurt between shots")
end

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
