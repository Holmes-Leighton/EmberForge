-- The rules of one player's Courier Run, with no Roblox objects in it (so tests can run whole courses): checkpoints in order, falling, the lava wall, spinners and
-- crushers, the finish, and the cheat checks. CourierService feeds it the player's position about ten times a second and reacts through `hooks`:
--   onStart()                       the run began
--   onCheckpoint(index, seconds)    a checkpoint was reached (index counts from 2: checkpoint 1 is the start)
--   onRespawn(reason, cpIndex, cp)  "fell" | "lava" | "crushed" | "spun": send the player back to checkpoint `cp` ({ x, y, z })
--   onFinish(seconds, respawns)     delivered (seconds already includes the penalty for each respawn)
--   onAbandon(reason)               "left" | "idle" | "speed": the run is dropped
local CourierData = require(game.ReplicatedStorage.Shared.Data.CourierData)
local CartCourseData = require(game.ReplicatedStorage.Shared.Data.CartCourseData)
local CourierLayout  = require(game.ReplicatedStorage.Shared.Modules.CourierLayout)     -- (its shared gate clock drives the crushers)

local CourierRunner = {}

local CP_REACH_X, CP_REACH_Z, CP_REACH_Y = 9, 14, 8
local FALL_BELOW = 14              -- studs below the last checkpoint's standing height that count as a fall
local LAVA_CATCH = 1               -- the lava wall catches you when you are this far inside it
local BAR_BODY   = 1.0             -- how close to a spinner's bar (beyond its thickness) still touches a player
local STAND_HEIGHT = 3             -- a standing character's root is about this far above the floor
local SPEED_STRIKES = 3

function CourierRunner.New(resolved, hooks, now)
    local def, L = resolved.def, resolved.layout
    local run = {
        r = resolved, hooks = hooks or {},
        startedAt = now, lastProgressAt = now,
        lastCP = 1, nextCP = 2,
        respawns = 0, finished = false, dropped = false,
        lastPos = nil, lastT = nil, strikes = 0,
    }
    if def.lava then
        run.lavaX0 = L.checkpoints[1].x - def.lava.headStart
        run.lavaT0 = now
    end
    return run
end

local function Hook(run, name, ...)
    local fn = run.hooks[name]
    if fn then fn(...) end
end

-- x of the front of the lava wall at time `now` (nil when the course has no lava)
function CourierRunner.LavaX(run, now)
    local lava = run.r.def.lava
    if not lava then return nil end
    return run.lavaX0 + lava.speed * math.max(0, now - run.lavaT0)
end

-- Is the point (px, py, pz) touching this spinner's bar at time t?
function CourierRunner.SpinnerHits(sp, t, px, py, pz)
    local h = py - sp.y                                       -- how high the player's root is above the platform
    if h > sp.barY + sp.thick / 2 + STAND_HEIGHT - 0.4 or h < -2 then return false end     -- jumped clear over it (or nowhere near)
    local angle = sp.phase + sp.omega * t
    local dx, dz = px - sp.x, pz - sp.z
    local ax, az = math.cos(angle), math.sin(angle)
    local along = dx * ax + dz * az
    local across = math.abs(-dx * az + dz * ax)
    return math.abs(along) <= sp.radius and across <= sp.thick / 2 + BAR_BODY
end

-- Is the point standing on this deadly tile? (Jump over it and you are fine.)
function CourierRunner.KillTileHits(k, px, py, pz)
    return math.abs(px - k.x) <= k.sx / 2 and math.abs(pz - k.z) <= k.sz / 2 and py - k.y > -0.5 and py - k.y < 4.2
end

-- Where a sweeper's bar is along Z at time t (it slides back and forth across its beam)
function CourierRunner.SweeperZ(sw, t)
    return sw.z + sw.amp * math.sin(2 * math.pi * (t + sw.phase) / sw.period)
end

-- Is the point touching this sweeper's bar? The bar is a low wall (3.2 tall): jump over it, or time it.
function CourierRunner.SweeperHits(sw, t, px, py, pz)
    local h = py - sw.y
    if h > 3.2 + STAND_HEIGHT - 0.4 or h < -2 then return false end
    return math.abs(px - sw.x) <= (sw.thick or 1.6) / 2 + BAR_BODY and math.abs(pz - CourierRunner.SweeperZ(sw, t)) <= 1.7 + BAR_BODY
end

-- Is the point touching this swinging blade? (jump it, or time it; it hangs over the whole width of its platform)
function CourierRunner.PendulumHits(p, t, px, py, pz)
    if math.abs(pz - p.z) > p.width / 2 + 1 or math.abs(px - p.x) > p.length + 4 then return false end
    local bx, by = CourierLayout.PendulumBlade(p, t)
    local dx, dy = px - bx, py - by
    return dx * dx + dy * dy <= 3.8 * 3.8
end

-- Is the point inside the circle that is firing right now? (a beam of light shoots up out of it)
function CourierRunner.BeamHits(f, t, px, py, pz)
    if px < f.x1 - 6 or px > f.x2 + 6 then return false end
    local idx, state = CourierLayout.BeamState(f, t)
    if state ~= "fire" then return false end
    local c = f.circles[idx]
    local dx, dz = px - c.x, pz - c.z
    local h = py - f.y
    return dx * dx + dz * dz <= (c.r + 0.8) * (c.r + 0.8) and h > -1 and h < 70
end

-- Is the point under this crusher while it is shut?
function CourierRunner.CrusherHits(c, t, px, py, pz)
    if CartCourseData.HazardOpen(c, t) then return false end
    return math.abs(px - c.x) <= c.sx / 2 and math.abs(pz - c.z) <= c.sz / 2 and py > c.y + 0.5 and py < c.y + c.height        -- (above its floor only: someone on a ledge below the platform is not under the block)
end

local function Respawn(run, now, reason)
    local L = run.r.layout
    local cp = L.checkpoints[run.lastCP]
    run.respawns += 1
    run.lastPos, run.lastT = nil, nil                         -- the teleport is not a cheat
    local lava = run.r.def.lava
    if lava then                                              -- a fresh head start from the checkpoint
        run.lavaX0 = cp.x - lava.headStart
        run.lavaT0 = now
    end
    Hook(run, "onRespawn", reason, run.lastCP, cp)
end

-- Seconds on the clock: real time plus a penalty for each respawn
function CourierRunner.Elapsed(run, now)
    return (now - run.startedAt) + run.respawns * CourierData.RESPAWN_PENALTY
end

-- Called with the player's root position. now = server time in seconds.
function CourierRunner.Step(run, now, px, py, pz)
    if run.finished or run.dropped then return end
    local r, L, def = run.r, run.r.layout, run.r.def

    -- walked away from the course, or stuck without progress
    if px < L.base.x - CourierData.LEAVE_RADIUS or px > L.endX + CourierData.LEAVE_RADIUS or pz < CourierData.ZONE.z1 - CourierData.LEAVE_RADIUS
        or pz > CourierData.ZONE.z2 + CourierData.LEAVE_RADIUS or py > CourierData.ZONE.maxY + 40 then
        run.dropped = true
        Hook(run, "onAbandon", "left")
        return
    end
    if now - run.lastProgressAt > CourierData.IDLE_ABANDON then
        run.dropped = true
        Hook(run, "onAbandon", "idle")
        return
    end

    -- cheat check: nobody runs this fast along the ground (falling does not count: only sideways speed)
    if run.lastPos then
        local dt = now - run.lastT
        if dt > 0.05 then
            local dx, dz = px - run.lastPos[1], pz - run.lastPos[3]
            local speed = math.sqrt(dx * dx + dz * dz) / dt
            if speed > CourierData.MIN_SPEED then
                run.strikes += 1
                if run.strikes >= SPEED_STRIKES then
                    run.dropped = true
                    Hook(run, "onAbandon", "speed")
                    return
                end
            else
                run.strikes = math.max(0, run.strikes - 1)
            end
        end
    end
    run.lastPos, run.lastT = { px, py, pz }, now

    -- ways to lose a few seconds
    local cp = L.checkpoints[run.lastCP]
    if py < cp.y - FALL_BELOW then
        Respawn(run, now, "fell")
        return
    end
    local lavaX = CourierRunner.LavaX(run, now)
    if lavaX and px < lavaX - LAVA_CATCH then
        Respawn(run, now, "lava")
        return
    end
    for _, sp in ipairs(L.spinners) do
        if math.abs(px - sp.x) <= sp.radius + 2 and CourierRunner.SpinnerHits(sp, now, px, py, pz) then
            Respawn(run, now, "spun")
            return
        end
    end
    for _, c in ipairs(L.crushers) do
        if math.abs(px - c.x) <= c.sx and CourierRunner.CrusherHits(c, now, px, py, pz) then
            Respawn(run, now, "crushed")
            return
        end
    end
    for _, pd in ipairs(L.pendulums or {}) do
        if CourierRunner.PendulumHits(pd, now, px, py, pz) then Respawn(run, now, "swung") return end
    end
    for _, f in ipairs(L.beamfields or {}) do
        if CourierRunner.BeamHits(f, now, px, py, pz) then Respawn(run, now, "zapped") return end
    end

    -- progress: the next checkpoint, in order, then the finish
    local nextCp = L.checkpoints[run.nextCP]
    if nextCp and px >= nextCp.x - CP_REACH_X and math.abs(pz - nextCp.z) <= CP_REACH_Z and math.abs(py - nextCp.y) <= CP_REACH_Y then
        run.lastCP = run.nextCP
        run.nextCP += 1
        run.lastProgressAt = now
        Hook(run, "onCheckpoint", run.lastCP, CourierRunner.Elapsed(run, now))
    elseif not nextCp and L.finish then
        local f = L.finish
        if math.abs(px - f.x) <= f.hx and math.abs(pz - f.z) <= f.hz and math.abs(py - f.y) <= CP_REACH_Y then
            run.finished = true
            Hook(run, "onFinish", CourierRunner.Elapsed(run, now), run.respawns)
        end
    end
end

return CourierRunner
