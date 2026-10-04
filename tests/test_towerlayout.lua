QUIET = true
local TL = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local CD = load("game/ReplicatedStorage/Shared/Data/CourierData")

local BASE = { x = 0, y = 100, z = 0 }
local function build(seed, levels) return TL.Build({ levels = levels or 30, seed = seed, base = BASE }) end

print("== shape")
local T = build(7)
expect(#T.levels == 30 and T.finish ~= nil, "30 levels and a finish")
expect(T.height > 600 and T.height < 900, "it climbs high (" .. math.floor(T.height) .. " studs)")
expect(#T.checkpoints == 30, "one checkpoint at the start of every level (" .. #T.checkpoints .. ")")
local dirs = true
for i = 2, #T.levels do if T.levels[i].dir == T.levels[i - 1].dir then dirs = false end end
expect(dirs, "levels alternate direction")
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
        local lim = CD.Limits[lv.tier]
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
            if lastEnd then
                local gap = (lv.dir == 1) and (near - lastEnd) or (lastEnd - near)
                local rise = piece.top - lastTop
                local side = math.abs(piece.z - lastZ) - (piece.w + lastW) / 2
                if gap > lim.maxGap + 1e-6 or rise > lim.maxRise + 1e-6 or side > 1.0 then
                    failures[#failures + 1] = string.format("seed %d level %d: gap %.1f rise %.1f side %.1f (limits %.1f / %.1f)", seed, lv.index, gap, rise, side, lim.maxGap, lim.maxRise)
                end
                worstGap[lv.tier] = math.max(worstGap[lv.tier] or 0, gap)
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

print("== the levels connect")
local bad = {}
for seed = 1, 40 do
    local tw = build(seed * 11 + 3, 30)
    for i = 1, #tw.levels - 1 do
        local lvB = tw.levels[i + 1]
        local last, firstRest
        for _, p in ipairs(tw.platforms) do
            if p.level == i and (not last or p.y > last.y) then last = p end
            if p.level == i + 1 and p.sx >= 26 - 0.01 then
                if not firstRest or (lvB.dir == 1 and p.x < firstRest.x) or (lvB.dir == -1 and p.x > firstRest.x) then firstRest = p end
            end
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

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
