QUIET = true
local CD  = load("game/ReplicatedStorage/Shared/Data/CourierData")
local CL  = load("game/ReplicatedStorage/Shared/Modules/CourierLayout")
local MD  = load("game/ReplicatedStorage/Shared/Data/MaterialData")

print("== every course can be walked")
expect(#CD.Courses == 3, "three courses")
local lastTier, lastMult, lastLevel, lastCourier = 0, 0, 0, 0
for _, def in ipairs(CD.Courses) do
    local r = CD.Resolve(def.id)
    local L = r.layout
    local lim = CD.Limits[def.tier]
    expect(def.tier > lastTier and def.rewardMult > lastMult and def.minLevel > lastLevel and def.minCourier > lastCourier,
        def.name .. " is harder, better paid and needs more than the course before")
    lastTier, lastMult, lastLevel, lastCourier = def.tier, def.rewardMult, def.minLevel, def.minCourier
    expect(r.length > 250 and r.length < 700, def.name .. " is a sensible length (" .. math.floor(r.length) .. " studs)")

    -- inside the north strip, under the roof
    local inside = true
    local function check(x1, x2, y, z, sz)
        if x1 < CD.ZONE.x1 or x2 > CD.ZONE.x2 or z - sz / 2 < CD.ZONE.z1 or z + sz / 2 > CD.ZONE.z2 or y > CD.ZONE.maxY then inside = false end
    end
    for _, p in ipairs(L.platforms) do check(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz) end
    for _, p in ipairs(L.crumbles) do check(p.x - p.sx / 2, p.x + p.sx / 2, p.y + p.sy / 2, p.z, p.sz) end
    for _, m in ipairs(L.movers) do check(m.x0 - m.sx / 2, m.x1 + m.sx / 2, m.y + m.sy / 2, m.z, m.sz) end
    expect(inside, def.name .. " stays inside the north strip and under the roof")
    expect(L.base.y >= 10, def.name .. " is raised well above the cavern floor (falls are obvious)")

    -- every jump: walk the pieces in order and measure the gap and the rise
    local order = CL.WalkOrder(L)
    local worstGap, worstRise, narrow = 0, 0, math.huge
    local lastEnd, lastTop = order[1].x2, order[1].top
    local lastKind = order[1].kind
    local ok = true
    for i = 2, #order do
        local piece = order[i]
        local gap = piece.x1 - lastEnd
        if piece.x1 >= lastEnd - 0.01 then                           -- (a mover's far end overlaps its own near end, so only compare pieces that follow)
            worstGap = math.max(worstGap, gap)
            worstRise = math.max(worstRise, piece.top - lastTop)
            lastEnd, lastTop = piece.x2, piece.top
        end
        narrow = math.min(narrow, piece.w)
    end
    expect(worstGap <= lim.maxGap + 1e-6, def.name .. ": the widest gap to jump is " .. string.format("%.1f", worstGap) .. " (limit " .. lim.maxGap .. ")")
    expect(worstRise <= lim.maxRise + 1e-6, def.name .. ": the biggest step up is " .. string.format("%.1f", worstRise) .. " (limit " .. lim.maxRise .. ")")
    expect(narrow >= (def.tier == 3 and 3 or lim.minWidth) - 1e-6, def.name .. ": the narrowest platform is " .. string.format("%.1f", narrow) .. " wide")

    -- sideways jumps: consecutive platforms must overlap, or sit within a jump of each other, across Z too
    local sideways = 0
    for i = 2, #order do
        local a, b = order[i - 1], order[i]
        local dz = math.abs(a.z - b.z) - (a.w + b.w) / 2
        if dz > sideways then sideways = dz end
    end
    expect(sideways <= 1.0, def.name .. ": platforms line up sideways (worst " .. string.format("%.1f", sideways) .. " studs clear)")

    -- checkpoints and the finish stand on something
    expect(#L.checkpoints >= 4, def.name .. " has checkpoints (" .. #L.checkpoints .. ")")
    local function standsOn(x, y, z)
        for _, p in ipairs(L.platforms) do
            if math.abs(x - p.x) <= p.sx / 2 and math.abs(z - p.z) <= p.sz / 2 and math.abs((p.y + p.sy / 2) - (y - 3)) < 0.01 then return true end
        end
        return false
    end
    local allOn = true
    for _, cp in ipairs(L.checkpoints) do if not standsOn(cp.x, cp.y, cp.z) then allOn = false end end
    expect(allOn, def.name .. ": every checkpoint stands on a platform")
    expect(L.finish and standsOn(L.finish.x, L.finish.y, L.finish.z), def.name .. ": the finish stands on a platform")
    expect(L.start and L.start.x == L.checkpoints[1].x, def.name .. " starts at the first checkpoint")
    local prevX = -1
    local inOrder = true
    for _, cp in ipairs(L.checkpoints) do if cp.x <= prevX then inOrder = false end prevX = cp.x end
    expect(inOrder and L.finish.x > prevX, def.name .. ": checkpoints run in order to the finish")

    -- obstacles
    for _, sp in ipairs(L.spinners) do
        expect(sp.omega > 0.5 and sp.omega < 3, def.name .. ": a spinner turns at a fair speed (" .. sp.omega .. " rad/s)")
        expect(sp.radius <= 12, def.name .. ": a spinner's bar fits its platform")
    end
    for _, c in ipairs(L.crushers) do
        expect(c.open >= 3 and c.closed <= 3, def.name .. ": a crusher is open at least 3 s and shut at most 3 s")
    end
    for _, m in ipairs(L.movers) do
        expect(m.period >= 4.5, def.name .. ": a moving platform isn't dizzyingly quick (period " .. m.period .. " s)")
        expect(m.x1 - m.x0 > 5, def.name .. ": a moving platform really moves")
    end
    if def.lava then
        expect(def.lava.speed < 5, def.name .. ": the lava is slower than walking (" .. def.lava.speed .. " studs/s)")
        expect(def.lava.headStart >= 40, def.name .. ": you get a head start on the lava")
    end
end

print("== the lava")
local rookie, cavern, deep = CD.Get("RookieRun"), CD.Get("CavernCourier"), CD.Get("DeepCourier")
expect(rookie.lava == nil and cavern.lava and deep.lava and deep.lava.speed > cavern.lava.speed, "only the harder courses chase you, and the deepest chases fastest")

print("== rewards")
for tier = 1, 3 do
    local ok = true
    for _, item in ipairs(CD.Bundles[tier]) do if not MD.Get(item.id) then ok = false end end
    expect(ok, "tier " .. tier .. " pays materials that exist")
    expect(MD.Get(CD.RareDrops[tier].id) ~= nil, "tier " .. tier .. " rare drop exists (" .. CD.RareDrops[tier].id .. ")")
    expect(CD.RareChance[tier] > 0 and CD.RareChance[tier] < 0.5, "tier " .. tier .. " rare chance is a small chance")
end
expect(CD.RareChance[3] > CD.RareChance[2] and CD.RareChance[2] > CD.RareChance[1], "better courses have a better rare chance")

print("== Courier Level")
local lvl, xp, ups = CD.AddXp(1, 0, CD.XpToNext(1))
expect(lvl == 2 and xp == 0 and ups == 1, "exactly enough XP is one level")
lvl, xp, ups = CD.AddXp(1, 0, CD.XpToNext(1) + 10)
expect(lvl == 2 and xp == 10, "leftover XP carries over")
lvl, xp, ups = CD.AddXp(1, 0, 100000)
expect(lvl == CD.MAX_LEVEL and xp == 0 and ups == CD.MAX_LEVEL - 1, "it stops at the top level")
expect(CD.XpToNext(2) > CD.XpToNext(1) and CD.XpToNext(10) > CD.XpToNext(5), "each level takes longer")
local p1, p10, p20 = CD.Perks(1), CD.Perks(10), CD.Perks(20)
expect(p1.coinBonus == 0 and p1.walkBonus == 0 and p1.jumpBonus == 0, "level 1 has no bonus")
expect(p10.coinBonus > 0 and p10.walkBonus > p1.walkBonus and p10.jumpBonus > 0, "higher levels help")
expect(p20.walkBonus <= 4 and p20.jumpBonus <= 1.5 and p20.coinBonus <= 0.2, "bonuses are capped")
local perHour = CD.RunXp(deep, "Gold")
expect(CD.RunXp(deep, "Gold") > CD.RunXp(deep, "Silver") and CD.RunXp(deep, nil) < CD.RunXp(deep, "Silver") and CD.RunXp(deep, nil) > CD.RunXp(rookie, nil), "XP rewards harder courses and quicker runs")
-- how many runs to reach the level each course needs
local runs, level, cur = 0, 1, 0
local needed = {}
while level < CD.MAX_LEVEL and runs < 400 do
    local ok1, ok2 = false, false
    local course = level < 3 and rookie or (level < 8 and cavern or deep)
    level, cur = CD.AddXp(level, cur, CD.RunXp(course, "Silver"))
    runs += 1
    if level >= 3 and not needed[3] then needed[3] = runs end
    if level >= 8 and not needed[8] then needed[8] = runs end
end
expect(needed[3] and needed[3] >= 3 and needed[3] <= 15, "Cavern Courier opens after " .. tostring(needed[3]) .. " Silver runs (a few sessions)")
expect(needed[8] and needed[8] > needed[3] and needed[8] <= 120, "Deep Courier opens after " .. tostring(needed[8]) .. " Silver runs in total")

print("== daily challenge")
local seen = {}
for day = 20000, 20005 do seen[CD.DailyChallenge(day).courseId] = true end
local n = 0 for _ in pairs(seen) do n += 1 end
expect(n == 3, "the daily challenge rotates through every course")
expect(CD.DailyChallenge(20000).courseId == CD.DailyChallenge(20000).courseId and CD.DailyChallenge(20000).medal == "Gold", "it is the same all day and asks for Gold")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
