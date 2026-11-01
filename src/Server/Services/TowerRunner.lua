-- The rules of one player's Sky Tower climb, with no Roblox objects in it (so tests can climb whole towers). TowerService feeds it the player's position about ten
-- times a second and reacts through `hooks`:
--   onLevel(level, seconds)          a new level was reached (the first is level 1, on arrival)
--   onRespawn(reason, level, cp)     "fell" | "lava" | "crushed" | "spun" | "swung" | "zapped": back to the start of the highest level reached (never lower)
--   onSummit(seconds, respawns)      the top; seconds already includes the penalty for each respawn
--   onAbandon(reason)                "left" | "speed": the climb is dropped
local TowerData    = require(game.ReplicatedStorage.Shared.Data.TowerData)
local CourierData  = require(game.ReplicatedStorage.Shared.Data.CourierData)
local CourierRunner = require(script.Parent.CourierRunner)

local TowerRunner = {}

local CP_REACH_X, CP_REACH_Z, CP_REACH_Y = 9, 14, 8
local SPEED_STRIKES = 3
local LEAVE_RADIUS = 500

-- mutator: this round's twist (TowerData.Mutators), or nil. It changes how fast the lava rises and from which level, and what a fall costs.
function TowerRunner.New(T, hooks, now, mutator)
    local run = {
        T = T, hooks = hooks or {}, startedAt = now, levelAt = now, highest = 1, mutator = mutator or TowerData.Mutators[1],
        respawns = 0, finished = false, dropped = false, lastPos = nil, lastT = nil, strikes = 0,
        byLevel = {},
    }
    for i = 1, #T.levels do run.byLevel[i] = { spinners = {}, crushers = {} } end
    for _, s in ipairs(T.spinners) do table.insert(run.byLevel[s.level].spinners, s) end
    for _, c in ipairs(T.crushers) do table.insert(run.byLevel[c.level].crushers, c) end
    for i = 1, #T.levels do run.byLevel[i].sweepers = {} run.byLevel[i].kills = {} run.byLevel[i].pendulums = {} run.byLevel[i].beamfields = {} end
    for _, p in ipairs(T.pendulums or {}) do table.insert(run.byLevel[p.level].pendulums, p) end
    for _, f in ipairs(T.beamfields or {}) do table.insert(run.byLevel[f.level].beamfields, f) end
    for _, k in ipairs(T.kills or {}) do table.insert(run.byLevel[k.level].kills, k) end
    for _, s in ipairs(T.sweepers or {}) do table.insert(run.byLevel[s.level].sweepers, s) end
    TowerRunner.StartLava(run, now)
    return run
end

local function Hook(run, name, ...)
    local fn = run.hooks[name]
    if fn then fn(...) end
end

local function StartCp(run, level)
    return run.T.checkpoints[run.T.levels[level].firstCheckpoint]
end

-- (Re)starts the lava for the level the player is on: a head start below its start platform, rising at the tier's pace
function TowerRunner.StartLava(run, now)
    local lv = run.T.levels[run.highest]
    local mut = run.mutator or {}
    local chases = lv.lava or (mut.lavaFrom ~= nil and run.highest >= mut.lavaFrom)
    if chases then
        local cp = StartCp(run, run.highest)
        local rise = math.max(TowerData.LAVA_RISE[lv.tier] * (mut.lava or 1), mut.lavaMin or 0)
        run.lava = { y0 = cp.y - TowerData.LAVA_HEAD, t0 = now, rise = rise }
    else
        run.lava = nil
    end
end

function TowerRunner.LavaY(run, now)
    local l = run.lava
    if not l then return nil end
    return l.y0 + l.rise * math.max(0, now - l.t0)
end

function TowerRunner.Penalty(run)
    return (run.mutator and run.mutator.penalty) or TowerData.RESPAWN_PENALTY
end

function TowerRunner.Elapsed(run, now)
    return (now - run.startedAt) + run.respawns * TowerRunner.Penalty(run)
end

-- Can this climber skip up a level? (a paid skip: never from the last level, never once the run is over, and at most SKIPS_PER_ROUND a round). Returns ok, reason.
function TowerRunner.CanSkip(run, skipsUsed)
    if run.finished or run.dropped then return false, "over" end
    if run.highest >= #run.T.levels then return false, "top" end
    if (skipsUsed or 0) >= TowerData.SKIPS_PER_ROUND then return false, "limit" end
    return true
end

-- Put the climber on the next level as if they had climbed it (the caller moves the player to StartCp). Returns the new level.
function TowerRunner.SkipLevel(run, now)
    run.highest += 1
    run.levelAt = now - TowerData.LEVEL_MIN_MINIMUM - 1           -- so the following level's speed check does not count the skip as a too-fast climb
    run.lastPos, run.lastT, run.strikes = nil, nil, 0
    TowerRunner.StartLava(run, now)
    return run.highest
end

function TowerRunner.StartPoint(run, level)
    return StartCp(run, level or run.highest)
end

local function Respawn(run, now, reason)
    local cp = StartCp(run, run.highest)
    run.respawns += 1
    run.lastPos, run.lastT = nil, nil
    TowerRunner.StartLava(run, now)
    Hook(run, "onRespawn", reason, run.highest, cp)
end

function TowerRunner.Step(run, now, px, py, pz)
    if run.finished or run.dropped then return end
    local T = run.T

    if math.abs(px - T.base.x) > LEAVE_RADIUS or math.abs(pz - T.base.z) > LEAVE_RADIUS or py > T.base.y + (T.height or 1000) + 300 then
        run.dropped = true
        Hook(run, "onAbandon", "left")
        return
    end

    if run.lastPos then
        local dt = now - run.lastT
        if dt > 0.05 then
            local dx, dz = px - run.lastPos[1], pz - run.lastPos[3]
            if math.sqrt(dx * dx + dz * dz) / dt > CourierData.MIN_SPEED then
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
    local prev = (run.lastPos and run.lastT and now - run.lastT <= 0.5) and run.lastPos or nil          -- (the line walked since the last sample, for the death tiles; not across a long gap)
    run.lastPos, run.lastT = { px, py, pz }, now

    local cp = StartCp(run, run.highest)
    if py < cp.y - TowerData.FALL_BELOW then
        Respawn(run, now, "fell")
        return
    end
    local lavaY = TowerRunner.LavaY(run, now)
    if lavaY and py < lavaY then
        Respawn(run, now, "lava")
        return
    end
    for lv = math.max(1, run.highest - 1), math.min(#T.levels, run.highest + 1) do
        for _, sp in ipairs(run.byLevel[lv].spinners) do
            if math.abs(px - sp.x) <= sp.radius + 2 and CourierRunner.SpinnerHits(sp, now, px, py, pz) then
                Respawn(run, now, "spun")
                return
            end
        end
        for _, k in ipairs(run.byLevel[lv].kills) do
            local near = math.abs(px - k.x) <= 4 or (prev ~= nil and math.abs(prev[1] - k.x) <= 4 + k.sx / 2)
            if near and (CourierRunner.KillTileHits(k, px, py, pz) or (prev ~= nil and CourierRunner.KillTileCrossed(k, prev[1], prev[2], prev[3], px, py, pz))) then
                Respawn(run, now, "burned")
                return
            end
        end
        for _, sw in ipairs(run.byLevel[lv].sweepers) do
            if math.abs(px - sw.x) <= 4 and CourierRunner.SweeperHits(sw, now, px, py, pz) then
                Respawn(run, now, "swept")
                return
            end
        end
        for _, pd in ipairs(run.byLevel[lv].pendulums) do
            if CourierRunner.PendulumHits(pd, now, px, py, pz) then Respawn(run, now, "swung") return end
        end
        for _, f in ipairs(run.byLevel[lv].beamfields) do
            if CourierRunner.BeamHits(f, now, px, py, pz) then Respawn(run, now, "zapped") return end
        end
        for _, c in ipairs(run.byLevel[lv].crushers) do
            if math.abs(px - c.x) <= c.sx and CourierRunner.CrusherHits(c, now, px, py, pz) then
                Respawn(run, now, "crushed")
                return
            end
        end
    end

    -- the next level up, taken in order and not faster than anyone can really climb a level
    local nextLevel = run.highest + 1
    if nextLevel <= #T.levels then
        local ncp = StartCp(run, nextLevel)
        if px >= ncp.x - CP_REACH_X and px <= ncp.x + CP_REACH_X and math.abs(pz - ncp.z) <= CP_REACH_Z and math.abs(py - ncp.y) <= CP_REACH_Y
            and now - run.levelAt >= TowerData.LEVEL_MIN_MINIMUM then
            run.highest = nextLevel
            run.levelAt = now
            TowerRunner.StartLava(run, now)
            Hook(run, "onLevel", nextLevel, TowerRunner.Elapsed(run, now))
        end
    elseif T.finish then
        local f = T.finish
        if math.abs(px - f.x) <= f.hx and math.abs(pz - f.z) <= f.hz and math.abs(py - f.y) <= CP_REACH_Y
            and TowerRunner.Elapsed(run, now) >= TowerData.TOP_MIN_TIME * (#T.levels / TowerData.LEVELS) then
            run.finished = true
            Hook(run, "onSummit", TowerRunner.Elapsed(run, now), run.respawns)
        end
    end
end

return TowerRunner
