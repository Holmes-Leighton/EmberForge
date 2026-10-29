QUIET = true
local TL = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local CD = load("game/ReplicatedStorage/Shared/Data/CourierData")

local BASE = { x = 0, y = 100, z = 0 }
local function build(seed, levels) return TL.Build({ levels = levels or 30, seed = seed, base = BASE }) end

print("== shape")
local T = build(7)
expect(#T.levels == 30 and T.finish ~= nil, "30 levels and a finish")
expect(T.height > 600 and T.height < 1100, "it climbs high (" .. math.floor(T.height) .. " studs)")
expect(#T.checkpoints == 30, "one checkpoint at the start of every level (" .. #T.checkpoints .. ")")
local flips = 0
for i = 2, #T.levels do if T.levels[i].dir ~= T.levels[i - 1].dir then flips += 1 end end
expect(flips >= 20, "levels zig-zag (they turn back " .. flips .. " times in 29)")
local worstWidth = 0
for seed = 1, 60 do
    for _, levels in ipairs({ 30, 60 }) do
        local tw = build(seed * 29 + 4, levels)
        local lo, hi = 1e9, -1e9
        for _, p in ipairs(tw.platforms) do lo = math.min(lo, p.x - p.sx / 2) hi = math.max(hi, p.x + p.sx / 2) end
        worstWidth = math.max(worstWidth, hi - lo)
    end
end
expect(worstWidth < 700, "the tower stays compact on 120 random towers (widest " .. math.floor(worstWidth) .. " studs)")
local rising = true
for i = 2, #T.levels do if T.levels[i].y <= T.levels[i - 1].y + 10 then rising = false end end
expect(rising, "every level is well above the one below")
expect(T.levels[1].tier == 1 and T.levels[15].tier == 2 and T.levels[30].tier == 3, "difficulty rises with height")
expect(not T.levels[1].lava and not T.levels[10].lava and T.levels[11].lava and T.levels[30].lava, "lava chases from level 11 up")

print("== it is the same every time for a seed, and different between seeds")
local A, B, C = build(7), build(7), build(8)
local same = #A.platforms == #B.platforms
for i = 1, math.min(#A.platforms, #B.platforms) do if A.platforms[i].x ~= B.platforms[i].x or A.platforms[i].y ~= B.platforms[i].y then same = false end end
expect(same, "the same seed builds the same tower")
local differs = #A.platforms ~= #C.platforms
for i = 1, math.min(#A.platforms, #C.platforms) do if A.platforms[i].x ~= C.platforms[i].x or A.platforms[i].sx ~= C.platforms[i].sx then differs = true end end
expect(differs, "a different seed builds a different tower")

print("== every jump can be made, on 60 random towers")
local worstGap = {}
local failures = {}
for seed = 1, 60 do
    local tw = build(seed * 37 + 5, 30)
    for _, lv in ipairs(tw.levels) do
        local lim = CD.Limits[lv.designTier]                      -- each design is held to its own tier's limits
        local order = TL.WalkOrder(tw, lv.index)
        if lv.dir == 1 then
            table.sort(order, function(a, b) return a.x1 < b.x1 end)
        else
            table.sort(order, function(a, b) return a.x2 > b.x2 end)
        end
        local lastEnd, lastTop, lastZ, lastW
        for _, piece in ipairs(order) do
            local near = lv.dir == 1 and piece.x1 or piece.x2
            local far = lv.dir == 1 and piece.x2 or piece.x1
            if lastEnd and not piece.viaBounce then                    -- (a bounce landing is checked on its own, below)
                local gap = (lv.dir == 1) and (near - lastEnd) or (lastEnd - near)
                local rise = piece.viaTruss and 0 or (piece.top - lastTop)           -- a ladder carries its own height (checked below)
                local side = math.abs(piece.z - lastZ) - (piece.w + lastW) / 2
                -- a hop is judged by the real distance between the two edges: forward and sideways together (a chimney's ledges are sideways hops)
                local dist = math.sqrt(math.max(gap, 0) ^ 2 + math.max(side, 0) ^ 2)
                if dist > lim.maxGap + 1e-6 or rise > lim.maxRise + 1e-6 then
                    failures[#failures + 1] = string.format("seed %d level %d: gap %.1f rise %.1f side %.1f (limits %.1f / %.1f)", seed, lv.index, gap, rise, side, lim.maxGap, lim.maxRise)
                end
                worstGap[lv.designTier] = math.max(worstGap[lv.designTier] or 0, gap)
            end
            local advance = (not lastEnd) or (lv.dir == 1 and far > lastEnd) or (lv.dir == -1 and far < lastEnd)
            if advance then lastEnd, lastTop, lastZ, lastW = far, piece.top, piece.z, piece.w end
        end
    end
end
expect(#failures == 0, "no impossible jump in 60 towers (" .. #failures .. " found" .. (failures[1] and (": " .. failures[1]) or "") .. ")")
for tier = 1, 3 do
    expect((worstGap[tier] or 0) <= CD.Limits[tier].maxGap + 1e-6, "tier " .. tier .. ": the widest gap is " .. string.format("%.1f", worstGap[tier] or 0) .. " (limit " .. CD.Limits[tier].maxGap .. ")")
end

print("== the new obstacles are fair")
local G = 196.2
local bounceN, ladderN, convN, sweepN = 0, 0, 0, 0
local ok = { ladder = true, belt = true, sweeper = true, bounce = true }
for seed = 1, 60 do
    local tw = build(seed * 13 + 1, 30)
    for _, tr in ipairs(tw.trusses) do
        ladderN += 1
        if tr.height < 10 or tr.height > 30 then ok.ladder = false end            -- a ladder is a real climb, but not a chore
    end
    for _, p in ipairs(tw.platforms) do
        if p.conveyor then
            convN += 1
            if math.abs(p.conveyor) > 6 then ok.belt = false end                  -- a belt must not out-run a walker (16 studs/s)
        end
    end
    for _, sw in ipairs(tw.sweepers) do
        sweepN += 1
        if sw.period < 2.8 or sw.amp > 5 then ok.sweeper = false end              -- slow enough to time, narrow enough to dodge
    end
    for _, b in ipairs(tw.bounces) do
        bounceN += 1
        local apex = b.power * b.power / (2 * G)
        local flight = (b.power + math.sqrt(math.max(0, b.power * b.power - 2 * G * b.rise))) / G
        local range = b.hspeed * flight                                           -- the pad throws you forward at a fixed speed, so this does not depend on the player
        local land
        for _, p in ipairs(tw.platforms) do if p.level == b.level and p.viaBounce then land = p end end
        local padHalf = b.sx / 2 + 1
        if not land or apex < b.rise + 2.5 or range < padHalf + land.bounceGap + 1.5 or range > padHalf + land.bounceGap + land.sx - 2 then ok.bounce = false end
    end
end
expect(ladderN > 0 and ok.ladder, "every ladder is a 10-30 stud climb (" .. ladderN .. " in 60 towers)")
expect(convN > 0 and ok.belt, "every conveyor belt is slower than a walker (" .. convN .. ")")
expect(sweepN > 0 and ok.sweeper, "every sweeper bar is slow enough to time and narrow enough to dodge (" .. sweepN .. ")")
expect(bounceN > 0 and ok.bounce, "every bounce pad clears its landing and lands you on it, not short and not past it (" .. bounceN .. ")")

print("== a safe route always exists through the tile floors")
local function crossable(pattern, bad)
    local rows, cols = #pattern, #pattern[1]
    local function safe(r, c) return r >= 1 and r <= rows and c >= 1 and c <= cols and pattern[r]:sub(c, c) ~= bad end
    local seen, queue = {}, {}
    for r = 1, rows do if safe(r, 1) then seen[r .. "," .. 1] = true queue[#queue + 1] = { r, 1 } end end
    local head = 1
    while head <= #queue do
        local r, c = queue[head][1], queue[head][2]
        head += 1
        if c == cols then return true end
        for dr = -1, 1 do
            for dc = -1, 1 do
                local nr, nc = r + dr, c + dc
                if (dr ~= 0 or dc ~= 0) and safe(nr, nc) and not seen[nr .. "," .. nc] then seen[nr .. "," .. nc] = true queue[#queue + 1] = { nr, nc } end
            end
        end
    end
    return false
end
local floors, killFloors, fallFloors = 0, 0, 0
local allOk, hardEnough = true, true
for _, d in ipairs(TL.Designs) do
    for _, m in ipairs(d.modules) do
        if m[1] == "killfloor" or m[1] == "tilefall" then
            floors += 1
            local bad = m[1] == "killfloor" and "X" or "o"
            if not crossable(m[2].pattern, bad) then allOk = false end
            if m[1] == "killfloor" then
                killFloors += 1
                local kills, tiles = 0, 0
                for _, row in ipairs(m[2].pattern) do for c = 1, #row do tiles += 1 if row:sub(c, c) == "X" then kills += 1 end end end
                local share = kills / tiles
                local lo, hi = d.tier == 1 and 0.25 or (d.tier == 2 and 0.3 or 0.38), 0.6
                if share < lo or share > hi then hardEnough = false end
            else
                fallFloors += 1
            end
        end
    end
end
expect(floors >= 6 and allOk, "every death-tile floor and falling floor can be crossed (" .. floors .. " floors checked)")
expect(killFloors >= 4 and hardEnough, "death tiles cover a real share of the floor, more on harder levels, never most of it (" .. killFloors .. " floors)")
local tilesBuilt, killsBuilt = 0, 0
for seed = 1, 20 do
    local tw = build(seed * 7 + 3, 30)
    for _, c in ipairs(tw.crumbles) do if c.grid then tilesBuilt += 1 end end
    killsBuilt += #tw.kills
end
expect(tilesBuilt > 100 and killsBuilt > 100, "towers contain them (" .. tilesBuilt .. " falling tiles and " .. killsBuilt .. " death tiles in 20 towers)")
local kk
for _, k in ipairs(build(4, 30).kills) do if not k.style then kk = k break end end
expect(kk and kk.sx > 4 and kk.sz > 4, "a death tile is a tile-sized square")

print("== the designs")
local DS = TL.Designs
expect(#DS >= 33, "at least 33 distinct level designs (" .. #DS .. ")")
local names, themes = {}, {}
local dupe = false
for _, d in ipairs(DS) do if names[d.name] then dupe = true end names[d.name] = true themes[d.theme] = true end
local themeCount = 0 for _ in pairs(themes) do themeCount += 1 end
expect(not dupe and themeCount >= 6, "each has its own name, and there are " .. themeCount .. " different looks")
local tiers = { 0, 0, 0 }
for _, d in ipairs(DS) do tiers[d.tier] += 1 end
expect(tiers[1] >= 9 and tiers[2] >= 9 and tiers[3] >= 9, "designs at every difficulty (" .. tiers[1] .. " easy, " .. tiers[2] .. " medium, " .. tiers[3] .. " hard)")
local seen, repeats = {}, 0
for seed = 1, 20 do
    local tw = build(seed * 3 + 2, 30)
    for i = 1, #tw.levels do
        seen[tw.levels[i].design] = true
        if i > 1 and tw.levels[i].design == tw.levels[i - 1].design then repeats += 1 end
    end
end
local variety = 0 for _ in pairs(seen) do variety += 1 end
expect(variety >= #DS * 0.75, "most designs turn up in the towers (" .. variety .. " of " .. #DS .. "; each zone favours the designs that suit it, so not every design fits every zone)")
expect(repeats == 0, "no design twice in a row")
local diff = build(10, 30)
local first = {}
for i = 1, 30 do first[#first + 1] = diff.levels[i].design end
local distinct = {} local n = 0
for _, nme in ipairs(first) do if not distinct[nme] then distinct[nme] = true n += 1 end end
expect(n >= 24, "one tower has " .. n .. " different kinds of level in its 30 (the 5 bosses are their own)")

print("== the levels connect")
local bad = {}
for seed = 1, 40 do
    local tw = build(seed * 11 + 3, 30)
    for i = 1, #tw.levels - 1 do
        local lvB = tw.levels[i + 1]
        local last, firstRest
        local restCp = tw.checkpoints[lvB.firstCheckpoint]
        for _, p in ipairs(tw.platforms) do
            if p.level == i and (not last or p.y >= last.y) then last = p end
            if p.level == i + 1 and math.abs(p.x - restCp.x) < 0.01 then firstRest = p end       -- (the rest platform is the one holding the level's first checkpoint)
        end
        local dy = firstRest.y + firstRest.sy / 2 - (last.y + last.sy / 2)
        local dz = math.abs(firstRest.z - last.z) - (firstRest.sz + last.sz) / 2
        local xOverlap = math.min(firstRest.x + firstRest.sx / 2, last.x + last.sx / 2) - math.max(firstRest.x - firstRest.sx / 2, last.x - last.sx / 2)
        if math.abs(dy) > 0.01 or dz > 3 or xOverlap < 0 then bad[#bad + 1] = string.format("seed %d, %d to %d: dy %.2f dz %.1f overlap %.1f", seed, i, i + 1, dy, dz, xOverlap) end
    end
end
expect(#bad == 0, "every climb lands on the next level's rest platform (" .. #bad .. " bad" .. (bad[1] and (": " .. bad[1]) or "") .. ")")

print("== levels do not overlap")
local clash = 0
for seed = 1, 10 do
    local tw = build(seed * 5 + 1, 30)
    local all = {}
    for _, p in ipairs(tw.platforms) do all[#all + 1] = { x1 = p.x - p.sx / 2, x2 = p.x + p.sx / 2, z1 = p.z - p.sz / 2, z2 = p.z + p.sz / 2, y = p.y + p.sy / 2, level = p.level } end
    for _, p in ipairs(tw.crumbles) do all[#all + 1] = { x1 = p.x - p.sx / 2, x2 = p.x + p.sx / 2, z1 = p.z - p.sz / 2, z2 = p.z + p.sz / 2, y = p.y + p.sy / 2, level = p.level } end
    for a = 1, #all do
        for b = a + 1, #all do
            local P, Q = all[a], all[b]
            if math.abs(P.level - Q.level) > 1 and math.abs(P.y - Q.y) < 14 and P.x1 < Q.x2 and Q.x1 < P.x2 and P.z1 < Q.z2 and Q.z1 < P.z2 then clash += 1 end
        end
    end
end
expect(clash == 0, "levels more than one apart never overlap vertically (" .. clash .. " clashes)")

print("== obstacles stay fair")
local fair = true
for _, sp in ipairs(T.spinners) do if sp.omega > 2.2 or sp.radius > 12 then fair = false end end
for _, c in ipairs(T.crushers) do if c.open < 3 or c.closed > 3 then fair = false end end
for _, m in ipairs(T.movers) do if m.period < 4.5 or math.abs(m.x1 - m.x0) < 5 then fair = false end end
expect(fair, "spinners, crushers and moving platforms keep to the speeds the Courier courses use")

print("== other sizes")
local small = build(3, 9)
expect(#small.levels == 9 and small.finish and small.height > 150, "a 9-level tower works (" .. math.floor(small.height) .. " studs)")
local pro = build(3, 60)
expect(#pro.levels == 60 and pro.height > 1300 and pro.levels[60].tier == 3, "a 60-level Pro tower works (" .. math.floor(pro.height) .. " studs)")

print("== walls, yellow strips and harder climbs")
local wallsSeen, stripsSeen, hurdlesSeen, crumblesInClimbs, narrowInClimbs = 0, 0, 0, 0, 0
for seed = 1, 20 do
    local tw = build(seed * 5 + 1, 30)
    for _, w in ipairs(tw.walls) do
        local lim = CD.Limits[tw.levels[w.level].designTier]
        if w.shaft then
            -- (the tall walls of a chimney are the sides of a shaft, not obstacles: they are climbed beside, never hopped)
        elseif w.open then
            wallsSeen += 1
            expect(w.open >= lim.minWidth + 1.5 and w.open >= 5, "seed " .. seed .. ": a slalom wall leaves a gap you can walk through (" .. w.open .. ")")
            expect(w.sy > 6, "and is too tall to jump over (" .. w.sy .. ")")
        else
            hurdlesSeen += 1
            expect(w.sy <= lim.maxRise, "seed " .. seed .. ": a hurdle can be jumped (" .. w.sy .. " high, limit " .. lim.maxRise .. ")")
        end
    end
    for _, k in ipairs(tw.kills) do
        if k.style == "strip" then
            stripsSeen += 1
            expect(k.sx <= 2.6, "a yellow strip is narrow enough to jump (" .. k.sx .. ")")
        end
    end
    for lvIndex, lv in ipairs(tw.levels) do
        if lvIndex < #tw.levels and lv.designTier >= 2 then
            local order = TL.WalkOrder(tw, lvIndex)
            local last = order[#order]
            local plainEnd = false
            for _, p in ipairs(tw.platforms) do if p.level == lvIndex and math.abs((p.x + (lv.dir == 1 and p.sx / 2 or -p.sx / 2)) - lv.endX) < 0.01 then plainEnd = true end end
            expect(plainEnd, "seed " .. seed .. " level " .. lvIndex .. ": the climb ends on a plain ledge (the next level starts there)")
        end
    end
    for _, c in ipairs(tw.crumbles) do if not c.grid and tw.levels[c.level].designTier >= 2 then crumblesInClimbs += 1 end end
end
expect(wallsSeen > 0 and hurdlesSeen > 0 and stripsSeen > 0, "towers contain slalom walls (" .. wallsSeen .. "), hurdles (" .. hurdlesSeen .. ") and yellow strips (" .. stripsSeen .. ")")
expect(crumblesInClimbs > 40, "the harder levels have crumbling ledges in them (" .. crumblesInClimbs .. " across 20 towers)")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
