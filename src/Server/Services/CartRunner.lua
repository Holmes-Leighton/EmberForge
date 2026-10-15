-- The rules of one Cart Run cart, with no Roblox objects in it (so tests can run whole runs): who is pushing, how the cart moves, the checkpoints, the crusher
-- gates, the retracting bridges, derailing, and the finish. CartCourseService feeds it real players and reacts to what it reports through `hooks`:
--   onCheckpoint(index, pushers)        a checkpoint was reached (pushers = the players pushing right now)
--   onFinish(seconds, contributors)     the depot was reached (contributors = userIds that pushed long enough)
--   onDerail(reason, checkpointIndex)   "crushed", "fell" or "toppled" (too fast round a bend); the cart waits, then goes back to the checkpoint
--   onBump()                            it hit a shut gate and stopped
--   onReset(reason)                     the cart went back (reason: "derail" | "delivered" | "abandoned") so clients should snap to the new place
local CartCourseData = require(game.ReplicatedStorage.Shared.Data.CartCourseData)
local CartPath       = require(game.ReplicatedStorage.Shared.Modules.CartPath)
local CartSim        = require(game.ReplicatedStorage.Shared.Modules.CartSim)

local CartRunner = {}

local DOOR_HALF = 1.25          -- half the thickness of a gate's door (studs)

function CartRunner.New(resolved, hooks)
    return {
        r = resolved,
        st = { s = 0, v = 0, length = resolved.length },
        phase = "idle",         -- idle | running | derailed | delivered | reloading
        phaseAt = 0,
        startedAt = nil,
        lastPushAt = nil,
        lastCP = 0,             -- index of the last checkpoint reached (0 = the start)
        cpPaid = {},
        pushTime = {},          -- userId -> seconds spent pushing this run
        derails = 0,
        hooks = hooks or {},
    }
end

local function Hook(runner, name, ...)
    local fn = runner.hooks[name]
    if fn then fn(...) end
end

local function ResetToStart(runner, reason)
    runner.st.s, runner.st.v = 0, 0
    runner.cpPaid, runner.lastCP, runner.pushTime = {}, 0, {}
    runner.startedAt, runner.lastPushAt, runner.derails = nil, nil, 0
    Hook(runner, "onReset", reason)
end

local function Derail(runner, now, reason)
    runner.phase, runner.phaseAt = "derailed", now
    runner.st.v = 0
    runner.derails += 1
    Hook(runner, "onDerail", reason, runner.lastCP)
end

-- pushers: { { userId = n, speed = studs/s forward along the rail } ... } for the players pushing this tick.
function CartRunner.Step(runner, dt, now, pushers)
    local r, st = runner.r, runner.st

    if runner.phase == "reloading" then
        if now - runner.phaseAt >= CartCourseData.COOLDOWN then runner.phase, runner.phaseAt = "idle", now end
        return
    elseif runner.phase == "delivered" then
        if now - runner.phaseAt >= CartCourseData.RETURN_AFTER then
            ResetToStart(runner, "delivered")
            runner.phase, runner.phaseAt = "reloading", now
        end
        return
    elseif runner.phase == "derailed" then
        if now - runner.phaseAt >= CartCourseData.DERAIL_TIME then
            st.s = runner.lastCP > 0 and r.checkpoints[runner.lastCP] or 0
            st.v = 0
            runner.phase, runner.phaseAt = (runner.startedAt and "running" or "idle"), now
            Hook(runner, "onReset", "derail")
        end
        return
    end

    -- idle or running: pushers move it
    local speeds, braking = {}, false
    for _, p in ipairs(pushers) do
        if p.speed > 0 then
            table.insert(speeds, p.speed)
            runner.pushTime[p.userId] = (runner.pushTime[p.userId] or 0) + dt
        else
            braking = true                                          -- walking against the cart holds it back
        end
    end
    local pushV = CartSim.PushTarget(speeds)
    if pushV or braking then runner.lastPushAt = now end

    local prevS = st.s
    local _, _, _, _, slope = CartPath.At(r.path, st.s)
    CartSim.Step(st, dt, slope, pushV, braking)

    -- too fast round a bend and it tips over
    if st.s > 12 and st.v > 0 and st.v > CartSim.CornerLimit(CartPath.Curvature(r.path, st.s)) then
        Derail(runner, now, "toppled")
        return
    end

    -- hazards, judged on the same shared clock the clients draw
    local half = CartSim.LENGTH / 2
    for _, h in ipairs(r.hazards) do
        local open = CartCourseData.HazardOpen(h, now)
        if h.kind == "gate" and not open then
            local face = h.s - DOOR_HALF
            if prevS + half <= face and st.s + half > face then
                st.s = face - half                                  -- stopped dead against the door
                st.v = -math.abs(st.v) * 0.2
                Hook(runner, "onBump")
            elseif prevS + half > face and prevS - half < h.s + DOOR_HALF and st.s + half > face then
                Derail(runner, now, "crushed")                      -- the door came down on it
                return
            end
        elseif h.kind == "bridge" and not open then
            if st.s > h.s - h.length / 2 + 1 and st.s < h.s + h.length / 2 - 1 then
                Derail(runner, now, "fell")
                return
            end
        end
    end

    -- checkpoints
    for i, cp in ipairs(r.checkpoints) do
        if not runner.cpPaid[i] and st.s >= cp then
            runner.cpPaid[i] = true
            runner.lastCP = i
            Hook(runner, "onCheckpoint", i, pushers)
        end
    end

    if runner.phase == "idle" and st.s > 3 then
        runner.phase, runner.startedAt = "running", now
    end

    if st.s >= r.length - 1.5 then
        local contributors = {}
        for userId, secs in pairs(runner.pushTime) do
            if secs >= CartCourseData.MIN_PUSH_TIME then table.insert(contributors, userId) end
        end
        local seconds = now - (runner.startedAt or now)
        runner.phase, runner.phaseAt = "delivered", now
        st.s, st.v = r.length, 0
        Hook(runner, "onFinish", seconds, contributors)
        return
    end

    -- left alone away from the start for too long: send it home
    if st.s > 3 and runner.lastPushAt and now - runner.lastPushAt > CartCourseData.IDLE_RESET then
        ResetToStart(runner, "abandoned")
        runner.phase, runner.phaseAt = "idle", now
    end
end

-- What the cart's sign should say
function CartRunner.StatusText(runner, now)
    local r = runner.r
    local function clock(sec)
        sec = math.max(0, math.floor(sec))
        return string.format("%d:%02d", sec // 60, sec % 60)
    end
    if runner.phase == "idle" then
        return string.format("%s  (level %d+)  Push me to the depot!", r.name, r.def.minLevel)
    elseif runner.phase == "running" then
        return string.format("%s  %s   Checkpoint %d/%d", r.name, clock(now - (runner.startedAt or now)), runner.lastCP, #r.checkpoints)
    elseif runner.phase == "derailed" then
        return "Derailed!"
    elseif runner.phase == "delivered" then
        return "Delivered!"
    end
    return "Reloading..."
end

function CartRunner.FormatTime(seconds)
    seconds = math.max(0, seconds)
    local m = math.floor(seconds / 60)
    return string.format("%d:%04.1f", m, seconds - m * 60)
end

return CartRunner
