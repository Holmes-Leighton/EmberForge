QUIET = true
local CD     = load("game/ReplicatedStorage/Shared/Data/CartCourseData")
local CP     = load("game/ReplicatedStorage/Shared/Modules/CartPath")
local Sim    = load("game/ReplicatedStorage/Shared/Modules/CartSim")
local Runner = load("SSS/EmberForge/Services/CartRunner")

local function newRun(id, log)
    log = log or {}
    local hooks = {
        onCheckpoint = function(i, pushers) table.insert(log, "cp" .. i) end,
        onFinish     = function(sec, who) log.finish = { seconds = sec, who = who } table.insert(log, "finish") end,
        onDerail     = function(reason, cp) log.derail = reason table.insert(log, "derail:" .. reason) end,
        onBump       = function() log.bumps = (log.bumps or 0) + 1 end,
        onReset      = function(reason) table.insert(log, "reset:" .. reason) end,
    }
    return Runner.New(CD.Resolve(id), hooks), log
end

-- one player who keeps pushing at `speed`, always in reach, from time t for `seconds` (or until the run ends)
local function push(run, t, seconds, speed, uid)
    local dt, steps = 0.05, math.floor(seconds / 0.05)
    for _ = 1, steps do
        t += dt
        Runner.Step(run, dt, t, { { userId = uid or 1, speed = speed or 14 } })
        if run.phase ~= "idle" and run.phase ~= "running" then break end
    end
    return t
end
local function wait(run, t, seconds)
    for _ = 1, math.floor(seconds / 0.05) do t += 0.05 Runner.Step(run, 0.05, t, {}) end
    return t
end

print("== an easy run, start to finish")
local run, log = newRun("EasyHaul")
local t = push(run, 100, 120, 14)
expect(run.phase == "delivered" and log.finish ~= nil, "pushing the whole way delivers the cart (" .. run.phase .. ")")
expect(log.finish.seconds > 25 and log.finish.seconds < 60, "an Easy Haul takes about " .. math.floor(log.finish.seconds) .. " s of steady pushing")
expect(log.finish.who[1] == 1 and #log.finish.who == 1, "the pusher is credited")
expect(table.concat(log, ",") == "cp1,finish", "one checkpoint on the way, then the finish (" .. table.concat(log, ",") .. ")")
local par = run.r.par
expect(log.finish.seconds < par * 1.4, "a steady pusher finishes near par (" .. math.floor(log.finish.seconds) .. " s vs par " .. math.floor(par) .. " s)")

print("== the cart goes home and reloads")
t = wait(run, t, CD.RETURN_AFTER + 0.2)
expect(run.phase == "reloading" and run.st.s == 0, "after a few seconds it is wheeled back to the start")
expect(log[#log] == "reset:delivered", "and clients are told to snap it back")
t = push(run, t, 3, 14)
expect(run.st.s == 0, "it can't be pushed while it reloads")
t = wait(run, t, CD.COOLDOWN + 0.2)
expect(run.phase == "idle", "then it is ready again")

print("== nobody pushing")
run, log = newRun("EasyHaul")
t = wait(run, 100, 5)
expect(run.st.s == 0 and run.phase == "idle", "an unpushed cart stays at the start")
t = push(run, t, 4, 14)
expect(run.phase == "running" and run.startedAt ~= nil, "pushing starts the run")
t = wait(run, t, 6)
expect(run.st.s > 20, "it coasts a little after the push (" .. math.floor(run.st.s) .. " studs)")
t = wait(run, t, CD.IDLE_RESET + 3)
expect(run.st.s == 0 and run.phase == "idle" and log[#log] == "reset:abandoned", "left alone too long it goes home (" .. table.concat(log, ",") .. ")")

print("== a slow walker is not enough")
run = newRun("EasyHaul")
t = push(run, 100, 5, 3)
expect(run.st.s < 20, "pushing at a crawl moves it at a crawl (" .. math.floor(run.st.s) .. " studs in 5 s)")

print("== a team is faster")
local solo = newRun("EasyHaul")
local team = newRun("EasyHaul")
local ts, tt = 100, 100
for _ = 1, 20 * 12 do
    ts += 0.05 Runner.Step(solo, 0.05, ts, { { userId = 1, speed = 14 } })
    tt += 0.05 Runner.Step(team, 0.05, tt, { { userId = 1, speed = 14 }, { userId = 2, speed = 14 }, { userId = 3, speed = 14 } })
end
expect(team.st.s > solo.st.s * 1.2, "three pushers cover clearly more ground than one (" .. math.floor(team.st.s) .. " vs " .. math.floor(solo.st.s) .. ")")

print("== gates")
local cave = CD.Resolve("CaveRun")
local gate = cave.hazards[1]
local function shutAt(h, from)
    for x = from, from + 60, 0.05 do
        if not CD.HazardOpen(h, x) and not CD.HazardOpen(h, x + 2.5) and not CD.HazardOpen(h, x + 1.2) then return x end
    end
end
run, log = newRun("CaveRun")
run.phase, run.startedAt, run.lastPushAt = "running", 90, 100
run.st.s = gate.s - 20                                   -- 20 studs short of the gate
local ts0 = shutAt(gate, 100)
for _ = 1, 20 * 2 do ts0 += 0.05 Runner.Step(run, 0.05, ts0, { { userId = 1, speed = 14 } }) if run.phase ~= "running" then break end end
expect(run.phase == "running" and run.st.s + Sim.LENGTH / 2 <= gate.s, "a shut gate stops the cart in front of it (" .. string.format("%.1f", run.st.s) .. " vs door at " .. string.format("%.1f", gate.s) .. ")")
expect((log.bumps or 0) >= 1, "the bump is reported")
local openAt
for x = ts0, ts0 + 20, 0.05 do if CD.HazardOpen(gate, x) then openAt = x break end end
local tNow = openAt
for _ = 1, 20 * 3 do tNow += 0.05 Runner.Step(run, 0.05, tNow, { { userId = 1, speed = 14 } }) end
expect(run.st.s > gate.s + 3 or run.phase == "derailed", "once it opens the cart carries on")

print("== crushed under a gate")
run, log = newRun("CaveRun")
run.phase, run.startedAt, run.lastPushAt = "running", 90, 100
run.st.s = gate.s                                        -- right under the door
local tc
for x = 100, 160, 0.05 do if CD.HazardOpen(gate, x) and not CD.HazardOpen(gate, x + 0.1) then tc = x break end end
local crushed = false
for _ = 1, 20 * 3 do
    tc += 0.05
    Runner.Step(run, 0.05, tc, {})
    if run.phase == "derailed" then crushed = true break end
end
expect(crushed and log.derail == "crushed", "a cart under the door when it shuts is crushed (" .. tostring(log.derail) .. ")")
Runner.Step(run, 0.05, tc + CD.DERAIL_TIME + 0.2, {})
expect(run.phase == "running" and run.st.s == 0, "it is put back at the start (no checkpoint yet)")
expect(run.derails == 1, "the derail is counted")

print("== bridges")
local deep = CD.Resolve("DeepRun")
local bridge
for _, h in ipairs(deep.hazards) do if h.kind == "bridge" then bridge = h break end end
run, log = newRun("DeepRun")
run.phase, run.startedAt, run.lastPushAt = "running", 90, 100
run.st.s = bridge.s
local tb
for x = 100, 200, 0.05 do if not CD.HazardOpen(bridge, x) then tb = x break end end
Runner.Step(run, 0.05, tb, {})
expect(run.phase == "derailed" and log.derail == "fell", "a cart on a bridge that is out falls (" .. tostring(log.derail) .. ")")
run, log = newRun("DeepRun")
run.phase, run.startedAt, run.lastPushAt = "running", 90, 100
run.st.s = bridge.s
local tOpen
for x = 100, 200, 0.05 do if CD.HazardOpen(bridge, x) and CD.HazardOpen(bridge, x + 0.5) then tOpen = x break end end
Runner.Step(run, 0.05, tOpen, {})
expect(run.phase == "running", "the same spot is safe while the bridge is extended")

print("== checkpoints keep your progress")
run, log = newRun("CaveRun")
run.phase, run.startedAt, run.lastPushAt = "running", 90, 100
run.st.s = cave.checkpoints[1] - 1
local tk = 100
for _ = 1, 20 * 3 do tk += 0.05 Runner.Step(run, 0.05, tk, { { userId = 1, speed = 14 } }) end
expect(run.lastCP == 1 and log[1] == "cp1", "reaching a checkpoint is reported once (" .. table.concat(log, ",") .. ")")
for _ = 1, 20 * 3 do tk += 0.05 Runner.Step(run, 0.05, tk, { { userId = 1, speed = 14 } }) end
local count = 0
for _, e in ipairs(log) do if e == "cp1" then count += 1 end end
expect(count == 1, "and never twice")
run.phase, run.phaseAt = "derailed", tk
Runner.Step(run, 0.05, tk + CD.DERAIL_TIME + 0.1, {})
expect(math.abs(run.st.s - cave.checkpoints[1]) < 1e-6 and run.phase == "running", "a derailed cart restarts from the last checkpoint")

print("== only real pushers are paid")
run, log = newRun("EasyHaul")
local tp = 100
for k = 1, 20 * 120 do
    tp += 0.05
    local pushers = { { userId = 1, speed = 14 } }
    if k < 20 * 3 then table.insert(pushers, { userId = 2, speed = 14 }) end            -- player 2 only helps for 3 s
    Runner.Step(run, 0.05, tp, pushers)
    if run.phase ~= "idle" and run.phase ~= "running" then break end
end
local paid = {}
for _, u in ipairs(log.finish.who) do paid[u] = true end
expect(paid[1] and not paid[2], "someone who only pushed for a moment is not credited (needs " .. CD.MIN_PUSH_TIME .. " s)")

print("== signs")
run = newRun("CaveRun")
expect(Runner.StatusText(run, 0):find("Cave Run") and Runner.StatusText(run, 0):find("level 4"), "the idle sign names the course and its level")
run.phase, run.startedAt = "running", 0
expect(Runner.StatusText(run, 75):find("1:15"), "a running cart shows the clock")
expect(Runner.FormatTime(74.26) == "1:14.3", "times read m:ss.t (" .. Runner.FormatTime(74.26) .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
