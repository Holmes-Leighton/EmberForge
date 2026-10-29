-- The Hollow Maze's new depth: rooms with pillars, item orbs, hiding crates, and a Zombie Golem that hunts by sound and can be stunned, slowed and decoyed.
QUIET = true
local MD = load("game/ReplicatedStorage/Shared/Data/MazeData")
local ML = load("game/ReplicatedStorage/Shared/Modules/MazeLayout")
local MZ = load("game/ReplicatedStorage/Shared/Modules/MazeZombie")

local function build(seed) return ML.Build({ seed = seed, base = MD.BASE }) end

print("== every section has a room with a pillar to circle")
local roomsOk, pillarOk, ringOk, edgeOk, reachOk, countOk = true, true, true, true, true, true
local DX = { N = 0, E = 1, S = 0, W = -1 }
local DY = { N = -1, E = 0, S = 1, W = 0 }
for seed = 1, 60 do
    local M = build(seed * 19 + 4)
    if #M.rooms ~= 5 then countOk = false end
    for s, r in ipairs(M.rooms) do
        local x0, x1 = (s - 1) * M.cols + 1, s * M.cols
        if r.x2 - r.x1 ~= 2 or r.y2 - r.y1 ~= 2 then roomsOk = false end
        if r.x1 <= x0 or r.x2 >= x1 then edgeOk = false end                       -- never an edge column: doorways, start and exit stay as they were
        local c = M.cells[r.pillar.x][r.pillar.y]
        if not (c.N and c.E and c.S and c.W and c.pillar) then pillarOk = false end
        for d, name in pairs({ N = "S", E = "W", S = "N", W = "E" }) do
            local n = M.cells[r.pillar.x + DX[d]][r.pillar.y + DY[d]]
            if not n[name] then pillarOk = false end
        end
        -- the eight cells round the pillar form a ring: each has two ways on within the ring
        for x = r.x1, r.x2 do
            for y = r.y1, r.y2 do
                if not (x == r.pillar.x and y == r.pillar.y) then
                    local inRing = 0
                    for _, n in ipairs(ML.Neighbours(M, x, y)) do
                        if n.x >= r.x1 and n.x <= r.x2 and n.y >= r.y1 and n.y <= r.y2 then inRing += 1 end
                    end
                    if inRing < 2 then ringOk = false end
                end
            end
        end
    end
    local dist = ML.Distances(M, M.start.x, M.start.y)
    for x = 1, M.width do for y = 1, M.height do if dist[x][y] == nil and not M.cells[x][y].pillar then reachOk = false end end end
    if dist[M.exit.x][M.exit.y] == nil then reachOk = false end
end
expect(countOk, "five rooms, one per section, on every maze")
expect(roomsOk and edgeOk, "each is 3 x 3 and keeps off a section's edge columns")
expect(pillarOk, "the middle cell is a solid pillar, walled on every side")
expect(ringOk, "and the eight cells round it make a ring you can run round")
expect(reachOk, "every other cell and the exit are still reachable from the entrance")

print("== item orbs")
local pickOk, specialOk, distinctOk, deadShare, total, dead = true, true, true, 0, 0, 0
for seed = 1, 60 do
    local M = build(seed * 7 + 2)
    local picks = ML.Pickups(M)
    if #picks ~= #MD.SECTIONS * MD.PICKUPS_PER_SECTION then pickOk = false end
    local seen = {}
    for _, p in ipairs(picks) do
        if p.item ~= MD.ITEMS[MD.SECTIONS[p.section]] then pickOk = false end
        if ML.SectionOf(M, p.cx) ~= p.section then pickOk = false end
        local key = p.cx * 1000 + p.cy
        if seen[key] then distinctOk = false end
        seen[key] = true
        local c = M.cells[p.cx][p.cy]
        local x1 = p.section * M.cols
        if c.pillar or (p.cx == M.start.x and p.cy == M.start.y) or (p.cx == M.exit.x and p.cy == M.exit.y)
            or (p.cx == x1 and M.gates[p.section] == p.cy) or (p.section > 1 and p.cx == x1 - M.cols + 1 and M.gates[p.section - 1] == p.cy) then specialOk = false end
        local open = 0
        for _, n in ipairs(ML.Neighbours(M, p.cx, p.cy)) do open += 1 end
        total += 1
        if open == 1 then dead += 1 end
    end
end
expect(pickOk, "two orbs in every section, each holding that section's item")
expect(distinctOk and specialOk, "never two in a cell, nor on the pillar, the entrance, the exit or a doorway")
expect(dead / total > 0.55, "mostly in dead ends: a gamble to go in (" .. string.format("%.0f%%", 100 * dead / total) .. ")")
local a, b, c2 = ML.Pickups(build(5)), ML.Pickups(build(5)), ML.Pickups(build(6))
local same, differs = true, false
for i = 1, #a do if a[i].cx ~= b[i].cx or a[i].cy ~= b[i].cy then same = false end if a[i].cx ~= c2[i].cx or a[i].cy ~= c2[i].cy then differs = true end end
expect(same and differs, "the same seed puts them in the same places on every server; another seed does not")
local items = {}
for _, it in pairs(MD.ITEMS) do items[it.id] = true end
expect(items.sprint and items.flare and items.freeze and items.stun and items.cloak, "five items: sprint, flare, freeze, stun, cloak")

print("== hiding crates")
local hideOk, hideCount = true, 0
for seed = 1, 60 do
    local M = build(seed * 11 + 3)
    local hides, picks = ML.Hideouts(M), ML.Pickups(M)
    local want = 0
    for _, n in ipairs(MD.HIDEOUTS_PER_SECTION) do want += n end
    if #hides ~= want then hideOk = false end
    local taken = {}
    for _, p in ipairs(picks) do taken[p.cx * 1000 + p.cy] = true end
    for _, h in ipairs(hides) do
        if taken[h.cx * 1000 + h.cy] or M.cells[h.cx][h.cy].pillar then hideOk = false end
        taken[h.cx * 1000 + h.cy] = true
        hideCount += 1
    end
end
expect(hideOk, "the right number of crates, never in a cell with an orb or on a pillar")

print("== the Zombie Golem hunts by sound")
local function awake(M)
    local z = MZ.New(M)
    z.awake = true
    return z
end
local function cellXZ(M, cx, cy) local x, _, z = ML.CellCenter(M, cx, cy) return x, z end
local function routeCells(M)                                  -- the cells of the shortest way from the entrance to the exit
    local d = ML.Distances(M, M.exit.x, M.exit.y)
    local cx, cy = M.start.x, M.start.y
    local set = { [cx * 1000 + cy] = { cx, cy } }
    while not (cx == M.exit.x and cy == M.exit.y) do
        cx, cy = ML.NextStep(M, cx, cy, M.exit.x, M.exit.y, d)
        set[cx * 1000 + cy] = { cx, cy }
    end
    return set
end
-- a dead end well away from the route the zombie walks to the exit (at least 3 cells from every route cell)
local function hideySpot(M)
    local route = routeCells(M)
    for _, de in ipairs(ML.DeadEnds(M)) do
        local far = true
        for _, r in pairs(route) do
            if math.abs(r[1] - de.x) + math.abs(r[2] - de.y) < 4 then far = false break end
        end
        if far and not M.cells[de.x][de.y].pillar then return de end
    end
    return nil
end
local function simulate(M, z, targetFn, seconds)
    local t, caughtAt = 0, nil
    while t < seconds and not caughtAt do
        local caught, info = MZ.Step(M, z, targetFn(t), 0.1, 30 + t)
        t += 0.1
        if #caught > 0 then caughtAt = t end
    end
    return caughtAt
end

local M = build(31)
local spot = hideySpot(M)
expect(spot ~= nil, "there is a dead end off the route to hide in")
local sx, sz = cellXZ(M, spot.x, spot.y)

local zStill = awake(M)
expect(simulate(M, zStill, function() return { { id = 1, x = sx, z = sz, noise = "still" } } end, 400) == nil, "a player who keeps still in a dead end off the route is never found")
local zRun = awake(M)
expect(simulate(M, zRun, function() return { { id = 1, x = sx, z = sz, noise = "run" } } end, 400) ~= nil, "but the same spot, running about, is heard and caught")
local zHide = awake(M)
expect(simulate(M, zHide, function() return { { id = 1, x = sx, z = sz, noise = "run", hidden = true } } end, 400) == nil, "a hidden player is safe however much noise they made")
local zCloak = awake(M)
expect(simulate(M, zCloak, function() return { { id = 1, x = sx, z = sz, noise = "run", cloaked = true } } end, 400) == nil, "so is a cloaked one")
local zWalk = awake(M)
local walkCaught = simulate(M, zWalk, function() return { { id = 1, x = sx, z = sz, noise = "walk" } } end, 400)
expect(walkCaught == nil or walkCaught > 0, "a walking player is heard from half as far (" .. tostring(walkCaught and string.format("%.0f s", walkCaught) or "never") .. ")")

-- the cheap check on the three hearing ranges: the same player at three distances
local function heardAt(noise, studs)
    local R = build(31)
    local z = awake(R)
    local ex, ez = cellXZ(R, 8, R.start.y)
    z.x, z.z = ex, ez                                                    -- (in the middle of the first section)
    -- stand `studs` along the corridors: use cells along the route
    local route = {}
    local d = ML.Distances(R, R.exit.x, R.exit.y)
    local cx, cy = 8, R.start.y
    local tx, tz = cellXZ(R, cx, cy)
    local walked = 0
    local px, pz = tx, tz
    while walked < studs do
        local nx, ny = ML.NextStep(R, cx, cy, R.exit.x, R.exit.y, d)
        if not nx then break end
        cx, cy = nx, ny
        walked += R.cell
        px, pz = cellXZ(R, cx, cy)
    end
    local _, info = MZ.Step(R, z, { { id = 1, x = px, z = pz, noise = noise } }, 0.01, 0)
    return info and info.mode == "hunt", walked
end
local loudNear = heardAt("run", MD.HEAR_RUN - 40)
local loudFar = heardAt("run", MD.HEAR_RUN + 60)
local quietFar = heardAt("walk", MD.HEAR_WALK + 60)
local quietNear = heardAt("walk", MD.HEAR_WALK - 30)
local stillNear = heardAt("still", MD.HEAR_STILL + 60)
expect(loudNear and not loudFar, "a runner is heard inside " .. MD.HEAR_RUN .. " studs of corridor and not beyond")
expect(quietNear and not quietFar, "a walker inside " .. MD.HEAR_WALK .. " and not beyond")
expect(not stillNear, "a player standing still is not heard from " .. (MD.HEAR_STILL + 60) .. " studs")

print("== with nobody to hear it prowls to the exit")
local Mp = build(44)
local zp = awake(Mp)
local startX = zp.x
local reached = nil
local t = 0
while t < 500 and not reached do
    MZ.Step(Mp, zp, {}, 0.1, 30 + t)
    t += 0.1
    local cx = ML.CellOf(Mp, zp.x, zp.z)
    if cx == Mp.exit.x then reached = t end
end
expect(zp.x > startX + 100, "it walks east into the maze (" .. string.format("%.0f", zp.x - startX) .. " studs)")
expect(reached ~= nil, "all the way to the exit in " .. tostring(reached and string.format("%.0f s", reached) or "never"))
local _, pinfo = MZ.Step(Mp, awake(Mp), {}, 0.1, 30)
expect(pinfo and pinfo.mode == "patrol", "and says it is patrolling")

print("== it remembers where it last heard you, then gives up")
local Mm = build(31)
local zm = awake(Mm)
local mx, mz = cellXZ(Mm, 4, Mm.start.y)
zm.x, zm.z = cellXZ(Mm, 6, Mm.start.y)
MZ.Step(Mm, zm, { { id = 1, x = mx, z = mz, noise = "run" } }, 0.1, 30)
expect(zm.memory ~= nil, "it remembers where it heard a runner")
local before = math.sqrt((zm.x - mx) ^ 2 + (zm.z - mz) ^ 2)
for _ = 1, 10 do MZ.Step(Mm, zm, { { id = 1, x = mx, z = mz, noise = "run", cloaked = true } }, 0.1, 30) end
local _, sinfo = MZ.Step(Mm, zm, { { id = 1, x = mx, z = mz, noise = "run", cloaked = true } }, 0.1, 30)
expect(sinfo and sinfo.mode == "search", "once the runner cloaks it searches the spot (" .. tostring(sinfo and sinfo.mode) .. ")")
for _ = 1, math.floor((MD.MEMORY + 2) / 0.1) do MZ.Step(Mm, zm, {}, 0.1, 30) end
local _, ginfo = MZ.Step(Mm, zm, {}, 0.1, 30)
expect(ginfo and ginfo.mode == "patrol" and zm.memory == nil, "and goes back to prowling after " .. MD.MEMORY .. " seconds of nothing")

print("== a loud player is still hunted and caught")
local Mh = build(31)
local zh = awake(Mh)
local hx, hz = cellXZ(Mh, 3, Mh.start.y)
local caughtAt = simulate(Mh, zh, function() return { { id = 9, x = hx, z = hz, noise = "run" } } end, 200)
expect(caughtAt ~= nil, "a runner standing in its way is caught (" .. tostring(caughtAt) .. " s)")
local zClose = awake(Mh)
zClose.x, zClose.z = hx + 2, hz
local caught2, info2 = MZ.Step(Mh, zClose, { { id = 9, x = hx, z = hz, noise = "run" } }, 0.1, 30)
expect(caught2[1] == 9 and info2.mode == "hunt" and info2.target == 9, "and info names the player it is hunting")

print("== items: stun, slow and decoy")
local Mi = build(31)
local function travelled(z, seconds)
    local d, px, pz = 0, z.x, z.z
    for _ = 1, math.floor(seconds / 0.1) do
        MZ.Step(Mi, z, {}, 0.1, 30)
        d += math.sqrt((z.x - px) ^ 2 + (z.z - pz) ^ 2)
        px, pz = z.x, z.z
    end
    return d
end
local zn = awake(Mi)
local normal = travelled(zn, 5)
local zs = awake(Mi)
MZ.Stun(zs, 3.5)
local sx0, sz0 = zs.x, zs.z
local stunnedMove = travelled(zs, 3.4)
expect(stunnedMove == 0, "a stunned zombie does not move at all (" .. stunnedMove .. ")")
expect(MZ.IsStunned(zs), "and is stunned for the full 3.5 seconds")
local near = { { id = 5, x = zs.x + 1, z = zs.z, noise = "run" } }
local cStun = MZ.Step(Mi, zs, near, 0.05, 30)
expect(#cStun == 0, "it cannot catch anyone while stunned, even right next to it")
local after = travelled(zs, 5)
expect(after > normal * 0.6, "afterwards it moves again (" .. string.format("%.0f", after) .. " vs " .. string.format("%.0f", normal) .. " studs)")
local zf = awake(Mi)
MZ.Slow(zf, MD.ITEMS.Frost.slow, MD.ITEMS.Frost.seconds)
local slowed = travelled(zf, 5)
expect(slowed < normal * 0.5 and slowed > normal * 0.3, "slowed to 40%: " .. string.format("%.0f", slowed) .. " studs in 5 s against " .. string.format("%.0f", normal))

local Md = build(31)
local zd = awake(Md)
local lane = {}                                                          -- the cells of the way to the exit, in order
do
    local d = ML.Distances(Md, Md.exit.x, Md.exit.y)
    local cx, cy = Md.start.x, Md.start.y
    lane[1] = { cx, cy }
    while not (cx == Md.exit.x and cy == Md.exit.y) do cx, cy = ML.NextStep(Md, cx, cy, Md.exit.x, Md.exit.y, d) lane[#lane + 1] = { cx, cy } end
end
zd.x, zd.z = cellXZ(Md, lane[12][1], lane[12][2])
local fx, fz = cellXZ(Md, lane[9][1], lane[9][2])                        -- a flare three cells behind it
local rx, rz = cellXZ(Md, lane[15][1], lane[15][2])                      -- the real player, three cells ahead
MZ.AddDecoy(zd, "f1", fx, fz, MD.ITEMS.Ember.seconds)
local target = { { id = 4, x = rx, z = rz, noise = "run" } }
local _, dinfo = MZ.Step(Md, zd, target, 0.1, 30)
expect(dinfo.mode == "hunt" and dinfo.target == nil, "it goes for the flare, not the player equally far the other way (target " .. tostring(dinfo.target) .. ")")
local ate, caughtPlayer = false, false
for _ = 1, 200 do
    local c = MZ.Step(Md, zd, target, 0.1, 30)
    if #c > 0 then caughtPlayer = true end
    if #zd.decoys == 0 then ate = true break end
end
expect(ate and not caughtPlayer, "it reaches the flare and uses it up without touching the player")
expect(MZ.IsStunned(zd), "then stops to sniff at it for a moment (" .. MD.SNIFF .. " s)")
local zExpire = awake(Md)
MZ.AddDecoy(zExpire, "f2", fx, fz, 2)
for _ = 1, 30 do MZ.Step(Md, zExpire, {}, 0.1, 30) end
expect(#zExpire.decoys == 0, "an old flare burns out")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
