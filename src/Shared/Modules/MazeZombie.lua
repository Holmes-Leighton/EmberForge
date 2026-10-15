-- The Zombie Golem's brain: pure maths with no Roblox types, so tests can run a whole hunt. It hunts the NEAREST player by real distance along the maze's corridors (a
-- breadth-first search over the cells), never through a wall, speeds up as the hunt goes on (MazeData.ZombieSpeed), and catches anyone within CATCH_RADIUS.
-- Between corridor cells it moves in straight lines through cell centres, so it can turn round mid-corridor when its target does.
--
--   z = MazeZombie.New(M)                         asleep in the lobby by the entrance
--   caught, info = MazeZombie.Step(M, z, targets, dt, huntElapsed)
--        targets = { { id, x, z }, ... } the players still running (world positions); info = { target = id, distance = studs } or nil
local MazeData   = require(game.ReplicatedStorage.Shared.Data.MazeData)
local MazeLayout = require(script.Parent.MazeLayout)

local MazeZombie = {}

local LOBBY_DEPTH = 20            -- studs west of the entrance that count as the lobby

-- Where the zombie sleeps: in the lobby, in line with the entrance
function MazeZombie.New(M)
    local sx, _, sz = MazeLayout.CellCenter(M, 1, M.start.y)
    return { x = M.base.x - LOBBY_DEPTH * 0.5, z = sz, awake = false }
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

function MazeZombie.Step(M, z, targets, dt, huntElapsed)
    local caught = {}
    if not z.awake then return caught, nil end
    local zoneKind, zcx, zcy = Zone(M, z.x, z.z)
    if zoneKind == "out" then return caught, nil end

    -- from the zombie's cell, how far (in cell steps) is every cell? A lobby zombie counts as standing in the entrance cell.
    local fromX, fromY = zcx, zcy
    if zoneKind == "lobby" then fromX, fromY = 1, M.start.y end
    local dist = MazeLayout.Distances(M, fromX, fromY)

    -- the nearest player by corridor distance (a player in the lobby is just beyond the entrance cell)
    local best, bestCost
    for _, t in ipairs(targets) do
        local kind, cx, cy = Zone(M, t.x, t.z)
        local cost
        if kind == "maze" and dist[cx][cy] then
            local mx, _, mz = MazeLayout.CellCenter(M, cx, cy)
            cost = dist[cx][cy] * M.cell + Dist2D(t.x, t.z, mx, mz)
        elseif kind == "lobby" then
            local _, _, ez = MazeLayout.CellCenter(M, 1, M.start.y)
            cost = dist[1][M.start.y] * M.cell + Dist2D(t.x, t.z, M.base.x, ez)
        end
        if cost and (not bestCost or cost < bestCost) then best, bestCost = t, cost end
    end
    if not best then return caught, nil end

    -- walk toward it
    local step = MazeData.ZombieSpeed(huntElapsed or 0) * dt
    local tKind, tcx, tcy = Zone(M, best.x, best.z)
    local guard = 0
    while step > 1e-6 and guard < 8 do
        guard += 1
        local kind, cx, cy = Zone(M, z.x, z.z)
        local goalX, goalZ
        if kind == "lobby" then
            if tKind == "lobby" then
                goalX, goalZ = best.x, best.z
            else
                local ex, _, ez = MazeLayout.CellCenter(M, 1, M.start.y)             -- into the maze through the entrance cell
                goalX, goalZ = ex, ez
            end
        elseif kind == "maze" then
            if tKind == "maze" and cx == tcx and cy == tcy then
                goalX, goalZ = best.x, best.z                                                       -- in the same cell: straight at it
            elseif tKind == "lobby" and cx == 1 and cy == M.start.y then
                goalX, goalZ = best.x, best.z
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

    for _, t in ipairs(targets) do
        if Dist2D(z.x, z.z, t.x, t.z) <= MazeData.CATCH_RADIUS then caught[#caught + 1] = t.id end
    end
    return caught, { target = best.id, distance = Dist2D(z.x, z.z, best.x, best.z) }
end

return MazeZombie
