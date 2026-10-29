-- The Sky Tower's structure: five zones, boss levels, a difficulty sawtooth, mixed ways up (stairs, spirals, ladders, lifts) and round mutators.
QUIET = true
local TL = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local TD = load("game/ReplicatedStorage/Shared/Data/TowerData")
local CD = load("game/ReplicatedStorage/Shared/Data/CourierData")

local BASE = { x = 0, y = 100, z = 0 }
local function build(seed, levels) return TL.Build({ levels = levels or 30, seed = seed, base = BASE }) end

print("== zones")
expect(TD.ZONE_COUNT == 5 and #TD.ZONES == 5, "five zones")
local counts = {}
for l = 1, 30 do local z = TD.ZoneOf(l, 30); counts[z] = (counts[z] or 0) + 1 end
expect(counts[1] == 6 and counts[2] == 6 and counts[3] == 6 and counts[4] == 6 and counts[5] == 6, "six levels in every zone")
expect(TD.ZoneOf(1, 30) == 1 and TD.ZoneOf(6, 30) == 1 and TD.ZoneOf(7, 30) == 2 and TD.ZoneOf(30, 30) == 5, "zone boundaries")
local bosses = {}
for l = 1, 30 do if TD.IsBoss(l, 30) then bosses[#bosses + 1] = l end end
expect(table.concat(bosses, ",") == "6,12,18,24,30", "the boss is the last level of each zone (" .. table.concat(bosses, ",") .. ")")
local pro = {}
for l = 1, 60 do if TD.IsBoss(l, 60) then pro[#pro + 1] = l end end
expect(table.concat(pro, ",") == "12,24,36,48,60", "a 60-level Pro tower has its bosses every 12")
local nb = 0
for l = 1, 9 do if TD.IsBoss(l, 9) then nb += 1 end end
expect(nb == 0, "a tiny test tower has no bosses")
expect(TD.ZoneClearedAt(7, 30) == 1 and TD.ZoneClearedAt(13, 30) == 2 and TD.ZoneClearedAt(19, 30) == 3 and TD.ZoneClearedAt(25, 30) == 4 and TD.ZoneClearedAt(8, 30) == nil and TD.ZoneClearedAt(1, 30) == nil,
    "reaching the first level of the next zone clears a zone")
expect(TD.IsZoneStart(1, 30) and TD.IsZoneStart(7, 30) and not TD.IsZoneStart(6, 30), "zone starts")
local c1, c2 = TD.ZoneColor(1, 30), TD.ZoneColor(13, 30)
expect(c1 ~= nil and c2 ~= nil, "every level has a zone colour")
for _, z in ipairs(TD.ZONES) do expect(z.name and z.material and z.material.qty > 0, "zone " .. z.id .. " has a name and a material chest") end

print("== difficulty is a sawtooth")
local T = build(7)
expect(#T.levels == 30, "30 levels")
local ok = true
for l = 1, 30 do
    local lv = T.levels[l]
    if lv.zone ~= TD.ZoneOf(l, 30) or lv.boss ~= TD.IsBoss(l, 30) or lv.zoneStart ~= TD.IsZoneStart(l, 30) then ok = false end
end
expect(ok, "every level knows its zone, whether it is a boss and whether it starts a zone")
for z = 2, 5 do
    local startLevel, prevBoss = (z - 1) * 6 + 1, (z - 1) * 6
    expect(T.levels[startLevel].tier < T.levels[prevBoss].tier, "zone " .. z .. " starts easier (tier " .. T.levels[startLevel].tier .. ") than the boss before it (tier " .. T.levels[prevBoss].tier .. ")")
end
for z = 1, 5 do
    local peak = 0
    for l = (z - 1) * 6 + 1, z * 6 do peak = math.max(peak, T.levels[l].tier) end
    expect(T.levels[z * 6].tier == peak, "zone " .. z .. ": the boss is the hardest level of its zone")
end
local avg = {}
for z = 1, 5 do
    local sum = 0
    for l = (z - 1) * 6 + 1, z * 6 do sum += T.levels[l].tier end
    avg[z] = sum / 6
end
expect(avg[1] < avg[3] and avg[3] < avg[5], "later zones are harder on average (" .. string.format("%.2f, %.2f, %.2f", avg[1], avg[3], avg[5]) .. ")")
local eases = 0
for l = 2, 30 do if T.levels[l].tier < T.levels[l - 1].tier then eases += 1 end end
expect(eases >= 6, "the tower eases off " .. eases .. " times rather than only ever climbing in difficulty")

print("== bosses")
local names = { Stone = "Boulder Run", Ember = "Magma Gauntlet", Frost = "Frozen Spiral", Storm = "Storm Core", Void = "The Hollow Crown" }
local okBoss = true
for z = 1, 5 do
    local lv = T.levels[z * 6]
    if lv.design ~= names[TD.ZONES[z].id] then okBoss = false end
end
expect(okBoss, "each zone ends with its own named boss level")
local seenBossDesign = {}
for seed = 1, 20 do
    local tw = build(seed * 13 + 1)
    for z = 1, 5 do seenBossDesign[tw.levels[z * 6].design] = true end
    for _, lv in ipairs(tw.levels) do
        if not lv.boss then expect(lv.design ~= names.Stone and lv.design ~= names.Ember and lv.design ~= names.Frost and lv.design ~= names.Storm and lv.design ~= names.Void, "a boss design never turns up as an ordinary level") end
    end
end
local nBoss = 0 for _ in pairs(seenBossDesign) do nBoss += 1 end
expect(nBoss == 5, "all five bosses appear")
for z = 1, 5 do
    local conn = T.levels[z * 6].connector
    expect(z == 5 or conn == "helix" or conn == "none", "boss " .. z .. " is never a plain staircase up (" .. tostring(conn) .. ")")
end

print("== levels have their own start plaza")
local plazaOk = true
for seed = 1, 20 do
    local tw = build(seed * 3 + 1)
    for _, lv in ipairs(tw.levels) do
        local cp = tw.checkpoints[lv.firstCheckpoint]
        local pad
        for _, p in ipairs(tw.platforms) do if p.level == lv.index and math.abs(p.x - cp.x) < 0.01 then pad = p end end
        if not pad then plazaOk = false
        elseif lv.zoneStart and pad.sx < 40 then plazaOk = false
        elseif lv.boss and pad.sx < 32 then plazaOk = false end
    end
end
expect(plazaOk, "a new zone opens on a wide plaza and a boss on a roomy pad")

print("== every way up turns up, and not mostly stairs")
local kinds, total, bossHelix = { ledges = 0, helix = 0, ladder = 0, lifts = 0, custom = 0, none = 0 }, 0, 0
for seed = 1, 60 do
    local tw = build(seed * 17 + 5)
    for i = 1, 29 do
        local lv = tw.levels[i]
        if not lv.boss then
            kinds[lv.connector] = (kinds[lv.connector] or 0) + 1
            total += 1
        end
    end
end
local function share(k) return kinds[k] / total end
expect(share("ledges") < 0.4, "a plain staircase is under 40% of the ways up (" .. string.format("%.0f%%", 100 * share("ledges")) .. ")")
expect(share("helix") > 0.15, "spirals are common (" .. string.format("%.0f%%", 100 * share("helix")) .. ")")
expect(kinds.ladder > 0 and kinds.lifts > 0, "ladders (" .. kinds.ladder .. ") and lifts (" .. kinds.lifts .. ") turn up")
expect(kinds.ledges > 0, "stairs still turn up (" .. kinds.ledges .. ")")

print("== zones prefer their own kinds of level")
local AFF = { sandstone = "Stone", wood = "Stone", slate = "Stone", lava = "Ember", ice = "Frost", neon = "Storm", glass = "Storm", dark = "Void" }
local matched, considered = 0, 0
for seed = 1, 30 do
    local tw = build(seed * 7 + 2)
    for _, lv in ipairs(tw.levels) do
        if not lv.boss then
            considered += 1
            local a = AFF[lv.theme]
            if a == nil or a == lv.zoneId then matched += 1 end
        end
    end
end
expect(matched / considered > 0.9, "levels suit their zone's look (" .. string.format("%.0f%%", 100 * matched / considered) .. ")")
for tier = 1, 3 do
    for _, z in ipairs(TD.ZONES) do
        expect(#TL.Candidates(tier, z.id) >= TL.MIN_CANDIDATES, "tier " .. tier .. " has designs for " .. z.id)
    end
end

print("== the spirals are fair")
local function rectDist(a, b)
    local gx = math.max(0, math.abs(a.x - b.x) - (a.sx + b.sx) / 2)
    local gz = math.max(0, math.abs(a.z - b.z) - (a.sz + b.sz) / 2)
    return math.sqrt(gx * gx + gz * gz)
end
local spirals, problems, overlaps = 0, {}, 0
for seed = 1, 60 do
    local tw = build(seed * 31 + 9)
    for _, h in ipairs(tw.helixes) do
        spirals += 1
        local lim = CD.Limits[tw.levels[h.level].designTier]
        local ledges = {}
        for _, p in ipairs(tw.platforms) do if p.level == h.level and p.helix then ledges[#ledges + 1] = { x = p.x, z = p.z, sx = p.sx, sz = p.sz, top = p.y + p.sy / 2, crumble = false } end end
        for _, p in ipairs(tw.crumbles) do if p.level == h.level and p.helix then ledges[#ledges + 1] = { x = p.x, z = p.z, sx = p.sx, sz = p.sz, top = p.y + p.sy / 2, crumble = true } end end
        table.sort(ledges, function(a, b) return a.top < b.top end)
        if #ledges ~= h.ledges then problems[#problems + 1] = "seed " .. seed .. ": ledge count" end
        for k = 2, #ledges do
            local d = rectDist(ledges[k - 1], ledges[k])
            if d > lim.maxGap - 0.3 or ledges[k].top - ledges[k - 1].top > lim.maxRise + 1e-6 then
                problems[#problems + 1] = string.format("seed %d level %d ledge %d: gap %.2f rise %.2f (limits %.1f / %.1f)", seed, h.level, k, d, ledges[k].top - ledges[k - 1].top, lim.maxGap, lim.maxRise)
            end
            if d < 0.9 then problems[#problems + 1] = string.format("seed %d level %d ledges %d and %d touch in plan (%.2f)", seed, h.level, k - 1, k, d) end
        end
        for a = 1, #ledges do                                                    -- no ledge hangs over another within head height
            for b = a + 2, #ledges do
                if ledges[b].top - ledges[a].top <= 9 and rectDist(ledges[a], ledges[b]) < 0.5 then overlaps += 1 end
            end
        end
        local top = ledges[#ledges]
        if top.crumble then problems[#problems + 1] = "seed " .. seed .. ": the exit ledge crumbles" end
        if math.abs(top.top - h.top) > 1e-6 then problems[#problems + 1] = "seed " .. seed .. ": exit height mismatch" end
        -- the first ledge can be reached from the platform before it
        local entry = ledges[1]
        local best = math.huge
        for _, list in ipairs({ tw.platforms, tw.crumbles }) do          -- (what you step off can be a platform or a crumbling one)
            for _, p in ipairs(list) do
                if p.level == h.level and not p.helix and math.abs((p.y + p.sy / 2) - (entry.top - h.rise)) < 0.01 then
                    best = math.min(best, rectDist({ x = p.x, z = p.z, sx = p.sx, sz = p.sz }, entry))
                end
            end
        end
        if best > lim.maxGap - 0.3 then problems[#problems + 1] = string.format("seed %d level %d: the first ledge is %.2f from the start (limit %.1f)", seed, h.level, best, lim.maxGap) end
    end
end
expect(spirals > 100, "there are plenty of spirals to check (" .. spirals .. " in 60 towers)")
expect(#problems == 0, "every hop up every spiral is inside its tier's limits (" .. #problems .. " problems" .. (problems[1] and (": " .. problems[1]) or "") .. ")")
expect(overlaps == 0, "no spiral ledge hangs over another within head height (" .. overlaps .. ")")

print("== the whole tower stays makeable and compact")
local widest = 0
for seed = 1, 40 do
    for _, n in ipairs({ 30, 60 }) do
        local tw = build(seed * 29 + 4, n)
        local lo, hi = 1e9, -1e9
        for _, p in ipairs(tw.platforms) do lo = math.min(lo, p.x - p.sx / 2) hi = math.max(hi, p.x + p.sx / 2) end
        widest = math.max(widest, hi - lo)
    end
end
expect(widest < 700, "towers stay compact with spirals and plazas (widest " .. math.floor(widest) .. ")")
local h30 = build(7).height
expect(h30 > 650 and h30 < 1000, "a 30-level tower is " .. math.floor(h30) .. " studs tall")

print("== mutators")
expect(#TD.Mutators == 6 and TD.MutatorById.moon.jump == 1.35 and TD.MutatorById.turbo.walk == 1.3, "six mutators with their numbers")
local seenM, repeatM = {}, false
for r = 0, 11 do
    local m = TD.MutatorForRound(r)
    seenM[m.id] = (seenM[m.id] or 0) + 1
    if r > 0 and TD.MutatorForRound(r - 1).id == m.id then repeatM = true end
end
local distinctM = 0 for _ in pairs(seenM) do distinctM += 1 end
expect(distinctM == 6 and not repeatM, "every mutator comes round, never twice in a row")
expect(TD.MutatorForRound(5) == TD.MutatorForRound(5), "the same round gives the same mutator on every server")
expect(TD.MutatorById.tide.lava > 1 and TD.MutatorById.tide.lavaFrom == 4, "Rising Tide speeds up the lava")
expect(TD.MutatorById.gold.pay > 1 and TD.MutatorById.gold.penalty > TD.RESPAWN_PENALTY, "Golden Hour pays more but punishes falls")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
