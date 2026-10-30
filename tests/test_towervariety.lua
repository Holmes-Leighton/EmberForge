-- "The levels are all the same": measured across many towers. Neighbouring levels must differ in what is on them, how they run, how they look, and how they play.
QUIET = true
local TL = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local TD = load("game/ReplicatedStorage/Shared/Data/TowerData")
local Art = load("SSS/EmberForge/Services/TowerArt")

local BASE = { x = 0, y = 100, z = 0 }
local TOWERS = 60
local function build(seed) return TL.Build({ levels = 30, seed = seed, base = BASE }) end

-- what a level is made of: the kinds of piece in its design (and its connector)
local function kinds(T, i)
    local lv = T.levels[i]
    local d = type(lv.designKey) == "number" and TL.Designs[lv.designKey] or TL.Bosses[lv.zoneId]
    local set = {}
    for _, m in ipairs(d and d.modules or {}) do set[m[1]] = true end
    if lv.connector then set["connector_" .. lv.connector] = true end
    return set
end
local function sameSet(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end
local function overlap(a, b)
    local n, total = 0, 0
    for k in pairs(a) do total += 1 if b[k] then n += 1 end end
    for k in pairs(b) do if not a[k] then total += 1 end end
    return total == 0 and 1 or n / total
end

print("== neighbouring levels")
local sameDesign, sameKinds, repeatsIn4, distinctSum, minDistinct = 0, 0, 0, 0, 99
local simSum, simN, worstRun = 0, 0, 0
local sameDirRuns = 0
for seed = 1, TOWERS do
    local T = build(seed * 11 + 5)
    local seen = {}
    local run = 1
    for i = 1, 30 do
        local lv = T.levels[i]
        seen[lv.design] = true
        if i > 1 then
            local prev = T.levels[i - 1]
            if lv.design == prev.design then sameDesign += 1 end
            local ka, kb = kinds(T, i - 1), kinds(T, i)
            if sameSet(ka, kb) then sameKinds += 1 end
            simSum += overlap(ka, kb)
            simN += 1
            if lv.dir == prev.dir then run += 1 worstRun = math.max(worstRun, run) else run = 1 end
        end
        for back = 2, 4 do
            local other = T.levels[i - back]
            if other and other.design == lv.design and not lv.boss then repeatsIn4 += 1 end
        end
    end
    local n = 0 for _ in pairs(seen) do n += 1 end
    distinctSum += n
    minDistinct = math.min(minDistinct, n)
end
expect(sameDesign == 0, "no level has the same design as the one before it (" .. sameDesign .. " in " .. TOWERS .. " towers)")
expect(repeatsIn4 == 0, "and none comes back within the next three (" .. repeatsIn4 .. ")")
expect(sameKinds == 0, "no two neighbouring levels are made of exactly the same kinds of piece (" .. sameKinds .. ")")
local sim = simSum / simN
expect(sim <= 0.45, "neighbours share under 45% of their kinds of piece on average (" .. string.format("%.0f%%", sim * 100) .. ")")
expect(distinctSum / TOWERS >= 22 and minDistinct >= 19, "a tower has " .. string.format("%.1f", distinctSum / TOWERS) .. " different designs out of 30 on average (fewest " .. minDistinct .. ")")
-- (how many levels in a row run the same way is not a sameness problem: the zig-zag is just the course turning back on itself)

print("== how the levels are built")
-- the shapes of climbing: running along, hopping up, riding something that moves, going round, passing a hazard on a timer
local function category(T, i)
    local k = kinds(T, i)
    local cats = {}
    if k.chimney or k.helix or k.connector_helix or k.ladder or k.lift or k.climb then cats.vertical = true end
    if k.rotor or k.orbit or k.mover or k.zmover or k.conveyor then cats.ride = true end
    if k.blink or k.crumble or k.tilefall or k.killfloor then cats.vanish = true end
    if k.spinner or k.crusher or k.sweeper or k.pendulum or k.beam or k.beams then cats.hazard = true end
    if k.slalom or k.strips then cats.wall = true end
    if k.ice or k.bounce then cats.surface = true end
    if k.steps then cats.hops = true end
    return cats
end
local windowsMono, windows, tallWindows, minCats = 0, 0, 0, 99
local catTotals = {}
for seed = 1, TOWERS do
    local T = build(seed * 13 + 1)
    for i = 1, 26 do
        local seen, n = {}, 0
        for j = i, i + 4 do
            for c in pairs(category(T, j)) do
                if not seen[c] then seen[c] = true n += 1 end
            end
        end
        windows += 1
        minCats = math.min(minCats, n)
        if n <= 2 then windowsMono += 1 end
        if seen.vertical then tallWindows += 1 end
    end
    for i = 1, 30 do for c in pairs(category(T, i)) do catTotals[c] = (catTotals[c] or 0) + 1 end end
end
expect(windowsMono == 0, "any five levels in a row bring at least three different kinds of challenge (worst window has " .. minCats .. "; " .. windowsMono .. " thin windows of " .. windows .. ")")
expect(tallWindows / windows >= 0.7, "and most stretches include a hard vertical climb (spiral, chimney, ladder or lift): " .. string.format("%.0f%%", 100 * tallWindows / windows) .. " of five-level windows")
local nCat = 0 for _ in pairs(catTotals) do nCat += 1 end
expect(nCat >= 6, "all the families of challenge turn up (" .. nCat .. " of 7)")

print("== how they play and look")
local ruleWindows, plain = 0, 0
local ruleKinds = {}
for seed = 1, TOWERS do
    local T = build(seed * 7 + 2)
    for i = 3, 27 do
        local n = 0
        for j = i, i + 3 do if T.levels[j].modifier then n += 1 end end
        if n > 0 then ruleWindows += 1 else plain += 1 end
    end
    for i = 1, 30 do if T.levels[i].modifier then ruleKinds[T.levels[i].modifier] = true end end
end
expect(ruleWindows / (ruleWindows + plain) >= 0.55, "most four-level stretches include a level with its own rule (" .. string.format("%.0f%%", 100 * ruleWindows / (ruleWindows + plain)) .. ")")

local sameDoor = 0
for seed = 1, TOWERS do
    for i = 3, 30 do if Art.EntranceKind(i, seed) == Art.EntranceKind(i - 1, seed) then sameDoor += 1 end end
end
expect(sameDoor == 0, "no two levels in a row open with the same doorway")

-- the zones: five looks, each with its own colour and its own tower sky
local hues = {}
for z = 1, 5 do hues[z] = TD.ZONES[z].hue end
local minGap = 1
for a = 1, 5 do for b = a + 1, 5 do
    local d = math.abs(hues[a] - hues[b])
    minGap = math.min(minGap, math.min(d, 1 - d))
end end
expect(minGap >= 0.08, "the five zones' colours are clearly apart on the colour wheel (closest pair " .. string.format("%.2f", minGap) .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
