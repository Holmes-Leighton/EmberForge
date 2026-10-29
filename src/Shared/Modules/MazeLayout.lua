-- Builds a Hollow Maze from a seed: five sections (one per Golem element) of random corridors joined end to end, with loops opened into each so there is somewhere to run.
-- Pure maths with no Roblox types: tests prove on hundreds of seeds that the exit can be reached from everywhere, and the server and every client build the same maze from the
-- same seed. See MAZE_DESIGN.md.
--
-- Cells are numbered cx = 1..width (west to east: the way you run) and cy = 1..height (north to south). Each cell has four walls (N, E, S, W; true = a wall is there).
local MazeData = require(game.ReplicatedStorage.Shared.Data.MazeData)

local MazeLayout = {}

local DX = { N = 0, E = 1, S = 0, W = -1 }
local DY = { N = -1, E = 0, S = 1, W = 0 }
local OPPOSITE = { N = "S", S = "N", E = "W", W = "E" }
local DIRS = { "N", "E", "S", "W" }

-- A tiny deterministic random number generator (so the server and the clients agree without sharing state)
local function Rng(seed)
    local s = (seed * 2654435761 + 12345) % 4294967296
    return function(n)
        s = (s * 1664525 + 1013904223) % 4294967296
        return (s // 65536) % n + 1
    end
end

local function Open(cells, x, y, dir)               -- knock the wall between (x, y) and its neighbour in `dir`
    cells[x][y][dir] = false
    local nx, ny = x + DX[dir], y + DY[dir]
    if cells[nx] and cells[nx][ny] then cells[nx][ny][OPPOSITE[dir]] = false end
end

local function OpenCount(cell)
    local n = 0
    for _, d in ipairs(DIRS) do if not cell[d] then n += 1 end end
    return n
end

-- opts: { seed, sections, cols, rows, cell, base = { x, y, z } }
function MazeLayout.Build(opts)
    opts = opts or {}
    local seed = opts.seed or 1
    local sections = opts.sections or #MazeData.SECTIONS
    local cols, rows = opts.cols or MazeData.COLS, opts.rows or MazeData.ROWS
    local cell = opts.cell or MazeData.CELL
    local base = opts.base or MazeData.BASE
    local width = sections * cols
    local rng = Rng(seed)

    local cells = {}
    for x = 1, width do
        cells[x] = {}
        for y = 1, rows do cells[x][y] = { N = true, E = true, S = true, W = true, section = (x - 1) // cols + 1 } end
    end

    -- each section is a random maze of its own (an iterative recursive backtracker: carve to an unvisited neighbour, back up at dead ends)
    for s = 1, sections do
        local x0, x1 = (s - 1) * cols + 1, s * cols
        local seen, stack = {}, {}
        local function key(x, y) return x * 1000 + y end
        local sx, sy = x0 + rng(cols) - 1, rng(rows)
        seen[key(sx, sy)] = true
        stack[1] = { sx, sy }
        while #stack > 0 do
            local cur = stack[#stack]
            local options = {}
            for _, d in ipairs(DIRS) do
                local nx, ny = cur[1] + DX[d], cur[2] + DY[d]
                if nx >= x0 and nx <= x1 and ny >= 1 and ny <= rows and not seen[key(nx, ny)] then options[#options + 1] = d end
            end
            if #options == 0 then
                stack[#stack] = nil
            else
                local d = options[rng(#options)]
                Open(cells, cur[1], cur[2], d)
                local nx, ny = cur[1] + DX[d], cur[2] + DY[d]
                seen[key(nx, ny)] = true
                stack[#stack + 1] = { nx, ny }
            end
        end
    end

    -- the doorways between sections, at seeded rows
    local gates = {}
    for s = 1, sections - 1 do
        local row = rng(rows)
        Open(cells, s * cols, row, "E")
        gates[s] = row
    end
    local startRow, exitRow = rng(rows), rng(rows)
    cells[1][startRow].W = false                       -- the entrance from the lobby
    cells[width][exitRow].E = false                    -- the way out

    -- rooms: one open room per section (ROOM_SIZE x ROOM_SIZE cells, every wall between its cells knocked out) with a solid pillar cell in the middle, so there is somewhere to
    -- circle round and shake the Zombie Golem off. A room never touches a section's edge columns, so the doorways and the start and exit cells are untouched, and it only adds
    -- passages (the pillar cell has no way in from anywhere but the room itself, so nothing is cut off).
    local rooms = {}
    local size = MazeData.ROOM_SIZE or 3
    if cols >= size + 2 and rows >= size then
        for s = 1, sections do
            local x0 = (s - 1) * cols + 1
            local rx = x0 + 1 + (rng(cols - size - 1) - 1)
            local ry = rng(rows - size + 1)
            local mx, my = rx + (size - 1) // 2, ry + (size - 1) // 2
            for x = rx, rx + size - 1 do
                for y = ry, ry + size - 1 do
                    cells[x][y].room = s
                    if not (x == mx and y == my) then
                        if x < rx + size - 1 and not (x + 1 == mx and y == my) then Open(cells, x, y, "E") end
                        if y < ry + size - 1 and not (x == mx and y + 1 == my) then Open(cells, x, y, "S") end
                    end
                end
            end
            for _, d in ipairs(DIRS) do                                             -- seal the pillar cell from every side
                cells[mx][my][d] = true
                local nx, ny = mx + DX[d], my + DY[d]
                cells[nx][ny][OPPOSITE[d]] = true
            end
            cells[mx][my].pillar = true
            rooms[s] = { section = s, x1 = rx, y1 = ry, x2 = rx + size - 1, y2 = ry + size - 1, pillar = { x = mx, y = my } }
        end
    end

    -- loops: open a share of each section's dead ends into a neighbour in the same section (never the outer doors)
    for s = 1, sections do
        local x0, x1 = (s - 1) * cols + 1, s * cols
        local ends = {}
        for x = x0, x1 do
            for y = 1, rows do
                if OpenCount(cells[x][y]) == 1 and not (x == 1 and y == startRow) and not (x == width and y == exitRow) then ends[#ends + 1] = { x, y } end
            end
        end
        local want = math.floor(#ends * (MazeData.BRAID[s] or 0.2) + 0.5)
        for _ = 1, want do
            if #ends == 0 then break end
            local pick = table.remove(ends, rng(#ends))
            local x, y = pick[1], pick[2]
            if OpenCount(cells[x][y]) == 1 then
                local walled = {}
                for _, d in ipairs(DIRS) do
                    local nx, ny = x + DX[d], y + DY[d]
                    if cells[x][y][d] and nx >= x0 and nx <= x1 and ny >= 1 and ny <= rows then walled[#walled + 1] = d end
                end
                if #walled > 0 then Open(cells, x, y, walled[rng(#walled)]) end
            end
        end
    end

    return {
        seed = seed, sections = sections, cols = cols, rows = rows, cell = cell, base = base, width = width, height = rows, cells = cells,
        gates = gates, start = { x = 1, y = startRow }, exit = { x = width, y = exitRow }, names = MazeData.SECTIONS, rooms = rooms,
    }
end

-- ── Where things are ──────────────────────────────────────────────────────────
-- The world position of the middle of a cell (the maze lies flat on the plane y = base.y; rows are centred on base.z)
function MazeLayout.CellCenter(M, cx, cy)
    return M.base.x + (cx - 1) * M.cell + M.cell / 2, M.base.y, M.base.z + (cy - 1) * M.cell + M.cell / 2 - M.height * M.cell / 2
end

-- The cell a world position is in, or nil if it is outside the maze
function MazeLayout.CellOf(M, wx, wz)
    local cx = math.floor((wx - M.base.x) / M.cell) + 1
    local cy = math.floor((wz - M.base.z + M.height * M.cell / 2) / M.cell) + 1
    if cx < 1 or cx > M.width or cy < 1 or cy > M.height then return nil end
    return cx, cy
end

function MazeLayout.SectionOf(M, cx) return math.clamp((cx - 1) // M.cols + 1, 1, M.sections) end

-- The cells you can walk to from (x, y) without crossing a wall
function MazeLayout.Neighbours(M, x, y)
    local out = {}
    local c = M.cells[x] and M.cells[x][y]
    if not c then return out end
    for _, d in ipairs(DIRS) do
        if not c[d] then
            local nx, ny = x + DX[d], y + DY[d]
            if M.cells[nx] and M.cells[nx][ny] then out[#out + 1] = { x = nx, y = ny, dir = d } end
        end
    end
    return out
end

-- How many steps it is from (fx, fy) to every cell: dist[x][y] (nil = unreachable)
function MazeLayout.Distances(M, fx, fy)
    local dist = {}
    for x = 1, M.width do dist[x] = {} end
    dist[fx][fy] = 0
    local queue, head = { { fx, fy } }, 1
    while head <= #queue do
        local cur = queue[head]
        head += 1
        local d = dist[cur[1]][cur[2]]
        for _, n in ipairs(MazeLayout.Neighbours(M, cur[1], cur[2])) do
            if dist[n.x][n.y] == nil then
                dist[n.x][n.y] = d + 1
                queue[#queue + 1] = { n.x, n.y }
            end
        end
    end
    return dist
end

-- The next cell on a shortest way from (fx, fy) to (tx, ty), or nil if already there / no way
function MazeLayout.NextStep(M, fx, fy, tx, ty, distFromTarget)
    if fx == tx and fy == ty then return nil end
    local dist = distFromTarget or MazeLayout.Distances(M, tx, ty)
    local here = dist[fx][fy]
    if here == nil then return nil end
    for _, n in ipairs(MazeLayout.Neighbours(M, fx, fy)) do
        if dist[n.x][n.y] ~= nil and dist[n.x][n.y] == here - 1 then return n.x, n.y end
    end
    return nil
end

-- ── Walls, for the builder ────────────────────────────────────────────────────
-- Every wall as a segment { x, z, length, along = "x" | "z", section } (world centre), with straight runs inside one section joined into one segment
function MazeLayout.Walls(M)
    local out = {}
    local function add(x, z, length, along, section) out[#out + 1] = { x = x, z = z, length = length, along = along, section = section } end
    local z0 = M.base.z - M.height * M.cell / 2
    -- horizontal walls (running along x) on grid line j (0 = the north edge, height = the south edge)
    for j = 0, M.height do
        local run
        for x = 1, M.width + 1 do
            local present = false
            if x <= M.width then
                if j == 0 then present = M.cells[x][1].N
                elseif j == M.height then present = M.cells[x][M.height].S
                else present = M.cells[x][j].S end
            end
            local section = x <= M.width and M.cells[x][1].section or nil
            if present and run and run.section == section then
                run.to = x
            else
                if run then add(M.base.x + ((run.from - 1) + run.to) * M.cell / 2, z0 + j * M.cell, (run.to - run.from + 1) * M.cell, "x", run.section) end
                run = present and { from = x, to = x, section = section } or nil
            end
        end
    end
    -- vertical walls (running along z) on grid line i (0 = the west edge, width = the east edge)
    for i = 0, M.width do
        local run
        for y = 1, M.height + 1 do
            local present = false
            if y <= M.height then
                if i == 0 then present = M.cells[1][y].W
                elseif i == M.width then present = M.cells[M.width][y].E
                else present = M.cells[i][y].E end
            end
            if present and run then
                run.to = y
            else
                if run then add(M.base.x + i * M.cell, z0 + ((run.from - 1) + run.to) * M.cell / 2, (run.to - run.from + 1) * M.cell, "z", run.section) end
                run = present and { from = y, to = y } or nil
            end
        end
    end
    -- the section of a vertical wall is the section of the cell to its west (the first section for the west edge)
    for _, w in ipairs(out) do
        if w.along == "z" then
            local i = math.floor((w.x - M.base.x) / M.cell + 0.5)
            w.section = MazeLayout.SectionOf(M, math.max(1, i))
        end
    end
    return out
end

-- ── Things to find ────────────────────────────────────────────────────────────
-- Candidate cells of a section for an item or a hiding place: never the start or exit cell, a doorway cell, or the pillar. Dead ends first (a good place to hide, and a gamble to
-- go into), then any other cell, each list shuffled by `rng`.
local function Candidates(M, s, rng)
    local x0, x1 = (s - 1) * M.cols + 1, s * M.cols
    local dead, other = {}, {}
    for x = x0, x1 do
        for y = 1, M.height do
            local c = M.cells[x][y]
            local special = c.pillar
                or (x == M.start.x and y == M.start.y) or (x == M.exit.x and y == M.exit.y)
                or (x == x1 and M.gates[s] == y) or (s > 1 and x == x0 and M.gates[s - 1] == y)
            if not special then
                if OpenCount(c) == 1 then dead[#dead + 1] = { x, y } else other[#other + 1] = { x, y } end
            end
        end
    end
    for _, list in ipairs({ dead, other }) do
        for k = #list, 2, -1 do
            local j = rng(k)
            list[k], list[j] = list[j], list[k]
        end
    end
    return dead, other
end

local function Pick(dead, other, n, taken)
    local out = {}
    for _, list in ipairs({ dead, other }) do
        for _, c in ipairs(list) do
            if #out >= n then break end
            if not taken[c[1] * 1000 + c[2]] then
                taken[c[1] * 1000 + c[2]] = true
                out[#out + 1] = c
            end
        end
    end
    return out
end

-- The item orbs lying about the maze: MazeData.PICKUPS_PER_SECTION in each section, each holding that section's item. { id, cx, cy, section, item }
function MazeLayout.Pickups(M)
    local out, taken = {}, {}
    for s = 1, M.sections do
        local dead, other = Candidates(M, s, Rng(M.seed * 31 + s * 7 + 5))
        for k, c in ipairs(Pick(dead, other, MazeData.PICKUPS_PER_SECTION, taken)) do
            out[#out + 1] = { id = string.format("P%d_%d", s, k), cx = c[1], cy = c[2], section = s, item = MazeData.ITEMS[M.names[s]] }
        end
    end
    return out
end

-- The hiding crates (in dead ends where there are any, and never in a cell holding an item): { id, cx, cy, section }
function MazeLayout.Hideouts(M)
    local out, taken = {}, {}
    for _, p in ipairs(MazeLayout.Pickups(M)) do taken[p.cx * 1000 + p.cy] = true end
    for s = 1, M.sections do
        local dead, other = Candidates(M, s, Rng(M.seed * 53 + s * 11 + 9))
        for k, c in ipairs(Pick(dead, other, (MazeData.HIDEOUTS_PER_SECTION or {})[s] or 1, taken)) do
            out[#out + 1] = { id = string.format("H%d_%d", s, k), cx = c[1], cy = c[2], section = s }
        end
    end
    return out
end

-- Dead ends (cells with one way in), for decoration and the tests
function MazeLayout.DeadEnds(M)
    local out = {}
    for x = 1, M.width do
        for y = 1, M.height do
            if OpenCount(M.cells[x][y]) == 1 then out[#out + 1] = { x = x, y = y } end
        end
    end
    return out
end

-- Number of open passages (each counted once): a perfect maze has cells - 1 of them (plus the two outer doors); loops add more
function MazeLayout.Passages(M)
    local n = 0
    for x = 1, M.width do
        for y = 1, M.height do
            if not M.cells[x][y].E and x < M.width then n += 1 end
            if not M.cells[x][y].S and y < M.height then n += 1 end
        end
    end
    return n
end

return MazeLayout
