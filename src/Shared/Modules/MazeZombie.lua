-- The Zombie Golem's brain: pure maths with no Roblox types, so tests can run a whole hunt.
--
-- It is not all-knowing any more. It hunts what it can HEAR (MazeData.HEAR_*): a running player is heard from far along the corridors, a walking one from half as far, one standing
-- still only when it is nearly on top of them, and a hiding or cloaked player only when it comes right up to them. It hunts the NEAREST player it can hear by real distance along the
-- corridors (a breadth-first search over the cells), never through a wall. When it hears nobody it goes to where it last heard someone and, after MazeData.MEMORY seconds, goes back to
-- prowling the way to the exit (a little slower than when it hunts). It speeds up as the hunt goes on (MazeData.ZombieSpeed) and catches anyone within CATCH_RADIUS.
-- Players can fight back with items: Stun (it stands still), Slow (it moves at a fraction of its pace) and Decoy (a flare it goes for instead of you, and stops to sniff at).
-- Between corridor cells it moves in straight lines through cell centres, so it can turn round mid-corridor when its target does.
--
--   z = MazeZombie.New(M)                         asleep in the lobby by the entrance (set z.awake = true when the hunt starts)
--   caught, info = MazeZombie.Step(M, z, targets, dt, huntElapsed)
--        targets = { { id, x, z, scale?, noise? = "run" | "walk" | "still", hidden?, cloaked? }, ... } the players still running (world positions)
--        info = { target = id | nil, distance = studs | nil, speed, mode = "hunt" | "search" | "patrol" | "stunned" } or nil
--   MazeZombie.Stun(z, seconds)   MazeZombie.Slow(z, factor, seconds)   MazeZombie.AddDecoy(z, id, x, z, seconds)
local MazeData   = require(game.ReplicatedStorage.Shared.Data.MazeData)
local MazeLayout = require(script.Parent.MazeLayout)

local MazeZombie = {}

local LOBBY_DEPTH = 20            -- studs west of the entrance that count as the lobby
local PROWL = 0.85                -- it moves at this share of its hunting pace while it searches or patrols

-- Where the zombie sleeps: in the lobby, in line with the entrance
function MazeZombie.New(M)
    local sx, _, sz = MazeLayout.CellCenter(M, 1, M.start.y)
    return { x = M.base.x - LOBBY_DEPTH * 0.5, z = sz, awake = false, clock = 0, decoys = {} }
end

-- Which part of the world a position is in: "maze" with its cell, "lobby", or "out" (past the exit, escaped, or somewhere it should not be)
local function Zone(M, x, z)
    local cx, cy = MazeLayout.CellOf(M, x, z)
    if cx then return "maze", cx, cy end
    local _, _, sz = MazeLayout.CellCenter(M, 1, M.start.y)
    if x < M.base.x and x > M.base.x - LOBBY_DEPTH * 2 and math.abs(z - sz) < M.height * M.cell / 2 then return "lobby" end
    return "out"
end
MazeZombie.Zone = Zone

local function Dist2D(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return math.sqrt(dx * dx + dz * dz)
end

-- Move from (x, z) toward (tx, tz) by up to `step` studs. Returns the new position and the studs left over.
local function Go(x, z, tx, tz, step)
    local d = Dist2D(x, z, tx, tz)
    if d <= step then return tx, tz, step - d end
    return x + (tx - x) / d * step, z + (tz - z) / d * step, 0
end

-- ── Item effects on the zombie ────────────────────────────────────────────────
function MazeZombie.Stun(z, seconds)
    z.stunUntil = math.max(z.stunUntil or 0, (z.clock or 0) + seconds)
end

function MazeZombie.IsStunned(z)
    return z.stunUntil ~= nil and (z.clock or 0) < z.stunUntil
end

function MazeZombie.Slow(z, factor, seconds)
    z.slowFactor, z.slowUntil = factor, (z.clock or 0) + seconds
end

function MazeZombie.AddDecoy(z, id, x, zz, seconds)
    z.decoys = z.decoys or {}
    table.insert(z.decoys, { id = id, x = x, z = zz, expires = (z.clock or 0) + seconds })
end

-- What it costs (studs along the corridors) for the zombie to get to a world position, or nil if there is no way
local function CostTo(M, dist, x, z)
    local kind, cx, cy = Zone(M, x, z)
    if kind == "maze" and dist[cx][cy] then
        local mx, _, mz = MazeLayout.CellCenter(M, cx, cy)
        return dist[cx][cy] * M.cell + Dist2D(x, z, mx, mz)
    elseif kind == "lobby" then
        local _, _, ez = MazeLayout.CellCenter(M, 1, M.start.y)
        return dist[1][M.start.y] * M.cell + Dist2D(x, z, M.base.x, ez)
    end
    return nil
end

-- Can the zombie hear this player from where it stands? `cost` is the corridor distance to them.
local function Heard(t, cost, straight)
    if t.hidden then return straight <= MazeData.HIDE_FIND end
    if t.cloaked then return straight <= MazeData.CLOAK_FIND end
    local noise = t.noise or "run"
    local radius = noise == "run" and MazeData.HEAR_RUN or (noise == "walk" and MazeData.HEAR_WALK or MazeData.HEAR_STILL)
    return cost <= radius or straight <= MazeData.HEAR_STILL
end

function MazeZombie.Step(M, z, targets, dt, huntElapsed)
    local caught = {}
    if not z.awake then return caught, nil end
    z.clock = (z.clock or 0) + dt
    z.decoys = z.decoys or {}
    local zoneKind, zcx, zcy = Zone(M, z.x, z.z)
    if zoneKind == "out" then return caught, nil end

    -- a stunned zombie stands still and catches nobody until it recovers
    if MazeZombie.IsStunned(z) then return caught, { stunned = true, mode = "stunned", speed = 0 } end

    -- from the zombie's cell, how far (in cell steps) is every cell? A lobby zombie counts as standing in the entrance cell.
    local fromX, fromY = zcx, zcy
    if zoneKind == "lobby" then fromX, fromY = 1, M.start.y end
    local dist = MazeLayout.Distances(M, fromX, fromY)

    -- everything it can hear, with how far along the corridors it is (a flare is loud and tempting: it counts for half its distance)
    local heardList = {}
    for _, t in ipairs(targets) do
        local cost = CostTo(M, dist, t.x, t.z)
        if cost and Heard(t, cost, Dist2D(z.x, z.z, t.x, t.z)) then heardList[#heardList + 1] = { t = t, cost = cost } end
    end
    local live = {}
    for _, d in ipairs(z.decoys) do
        if z.clock < d.expires then
            live[#live + 1] = d
            local cost = CostTo(M, dist, d.x, d.z)
            if cost then heardList[#heardList + 1] = { t = d, cost = cost * 0.5, decoy = true } end
        end
    end
    z.decoys = live

    local best
    for _, h in ipairs(heardList) do if not best or h.cost < best.cost then best = h end end

    -- decide where to go: the nearest thing it can hear; else where it last heard something; else the way to the exit
    local goal, mode
    if best then
        goal, mode = best.t, "hunt"
        z.memory = { x = best.t.x, z = best.t.z, t = z.clock }
    elseif z.memory and z.clock - z.memory.t <= MazeData.MEMORY and Dist2D(z.x, z.z, z.memory.x, z.memory.z) > 3 then
        goal, mode = z.memory, "search"
    else
        z.memory = nil
        local ex, _, ez = MazeLayout.CellCenter(M, M.exit.x, M.exit.y)
        goal, mode = { x = ex, z = ez }, "patrol"
    end

    -- walk toward it
    local pace = MazeData.ZombieSpeed(huntElapsed or 0)
    if mode == "hunt" then pace = pace * ((not best.decoy and best.t.scale) or 1)       -- (keeps pace with a trained-up target: see MazeData.ZombieScale)
    else pace = pace * PROWL end
    if z.slowUntil and z.clock < z.slowUntil then pace = pace * (z.slowFactor or 1) end
    local step = pace * dt
    local tKind, tcx, tcy = Zone(M, goal.x, goal.z)
    local guard = 0
    while step > 1e-6 and guard < 8 do
        guard += 1
        local kind, cx, cy = Zone(M, z.x, z.z)
        local goalX, goalZ
        if kind == "lobby" then
            if tKind == "lobby" then
                goalX, goalZ = goal.x, goal.z
            else
                local ex, _, ez = MazeLayout.CellCenter(M, 1, M.start.y)             -- into the maze through the entrance cell
                goalX, goalZ = ex, ez
            end
        elseif kind == "maze" then
            if tKind == "maze" and cx == tcx and cy == tcy then
                goalX, goalZ = goal.x, goal.z                                                       -- in the same cell: straight at it
            elseif tKind == "lobby" and cx == 1 and cy == M.start.y then
                goalX, goalZ = goal.x, goal.z
            else
                local tx, ty
                if tKind == "maze" then tx, ty = tcx, tcy else tx, ty = 1, M.start.y end            -- a lobby target is reached through the entrance cell
                local nx, ny = MazeLayout.NextStep(M, cx, cy, tx, ty)
                if not nx then break end
                local wx, _, wz = MazeLayout.CellCenter(M, nx, ny)
                goalX, goalZ = wx, wz
            end
        else
            break
        end
        z.x, z.z, step = Go(z.x, z.z, goalX, goalZ, step)
        if Dist2D(z.x, z.z, goalX, goalZ) > 1e-6 then break end
    end

    -- it stops to sniff at a flare it has reached (and the flare is used up)
    local kept = {}
    for _, d in ipairs(z.decoys) do
        if Dist2D(z.x, z.z, d.x, d.z) <= MazeData.CATCH_RADIUS then
            MazeZombie.Stun(z, MazeData.SNIFF)
            z.memory = nil
        else
            kept[#kept + 1] = d
        end
    end
    z.decoys = kept

    for _, t in ipairs(targets) do
        if Dist2D(z.x, z.z, t.x, t.z) <= MazeData.CATCH_RADIUS then caught[#caught + 1] = t.id end
    end
    local info = { mode = mode, speed = pace }
    if mode == "hunt" and not best.decoy then
        info.target = best.t.id
        info.distance = Dist2D(z.x, z.z, best.t.x, best.t.z)
    end
    return caught, info
end

return MazeZombie
