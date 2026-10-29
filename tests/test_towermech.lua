-- The new tower mechanics: windmills (rotating arms), vanishing platforms and wall chimneys. Proves the maths, that each is fair, and that towers really use them.
QUIET = true
local TL = load("game/ReplicatedStorage/Shared/Modules/TowerLayout")
local CL = load("game/ReplicatedStorage/Shared/Modules/CourierLayout")
local TD = load("game/ReplicatedStorage/Shared/Data/TowerData")
local CD = load("game/ReplicatedStorage/Shared/Data/CourierData")

local BASE = { x = 0, y = 100, z = 0 }
local function build(seed) return TL.Build({ levels = 30, seed = seed, base = BASE }) end
local function near(a, b, e) return math.abs(a - b) <= (e or 1e-6) end

print("== windmill maths")
local r = { x = 50, y = 20, z = 10, radius = 10, arms = 3, width = 5.5, omega = 0.6, phase = 0 }
local a1, mx, mz = CL.RotorArm(r, 1, 0)
expect(near(a1, 0) and near(mx, 55) and near(mz, 10), "arm 1 at time 0 points along +x, its middle 5 studs from the hub")
local a2 = CL.RotorArm(r, 2, 0)
expect(near(a2, 2 * math.pi / 3), "arms are spread evenly round the hub (arm 2 is a third of a turn on)")
local aLater = CL.RotorArm(r, 1, 5)
expect(near(aLater, (0.6 * 5) % (2 * math.pi)), "and turn at omega (" .. string.format("%.2f", aLater) .. " rad after 5 s)")
expect(CL.RotorArm({ x = 0, y = 0, z = 0, radius = 10, arms = 2, omega = -0.5, phase = 0 }, 1, 1) > math.pi, "a negative omega turns the other way (the angle stays 0..2 pi)")
expect(CL.OnRotorArm(r, 1, 0, 55, 20.5, 10), "a point on the arm's middle is on the arm")
expect(CL.OnRotorArm(r, 1, 0, 59.5, 20.5, 11), "and near its tip")
expect(not CL.OnRotorArm(r, 1, 0, 55, 20.5, 20), "but not beside it")
expect(not CL.OnRotorArm(r, 1, 0, 55, 40, 10), "nor high above it")
expect(not CL.OnRotorArm(r, 1, 0, 70, 20.5, 10), "nor beyond its tip")
local rx, rz = CL.RotateAbout(0, 0, 1, 0, math.pi / 2)
expect(near(rx, 0, 1e-9) and near(rz, 1, 1e-9), "turning (1, 0) a quarter turn gives (0, 1): the same way the arms turn")

print("== carrying a player round stays on the arm")
local stays = true
for arm = 1, 3 do
    local px, pz = r.x + 7, r.z                                      -- 7 studs out along arm 1 at time 0
    local ang0 = CL.RotorArm(r, arm, 0)
    local sx, sz = r.x + math.cos(ang0) * 7, r.z + math.sin(ang0) * 7
    local t = 0
    for _ = 1, 600 do                                                -- ten seconds at 60 frames a second
        local dt = 1 / 60
        sx, sz = CL.RotateAbout(r.x, r.z, sx, sz, r.omega * dt)      -- exactly what the client does each frame
        t += dt
        if not CL.OnRotorArm(r, arm, t, sx, 20.5, sz) then stays = false break end
    end
end
expect(stays, "a player standing 7 studs out, carried each frame, is still on the arm after 10 s (all three arms)")

print("== every windmill is fair")
local fastest, longestWait, shortestWindow, count = 0, 0, 99, 0
local tiersSeen = {}
for seed = 1, 60 do
    local tw = build(seed * 7 + 3)
    for _, rot in ipairs(tw.rotors) do
        count += 1
        local lv = tw.levels[rot.level]
        local lim = CD.Limits[lv.designTier]
        fastest = math.max(fastest, math.abs(rot.omega) * rot.radius)
        local wait = 2 * math.pi / (rot.arms * math.abs(rot.omega))
        longestWait = math.max(longestWait, wait)
        -- how long is an arm close enough to the platform you stand on for the jump? (its tip must come within the tier's gap, and sideways within the landing's half width)
        local reach = lim.maxGap - 0.2 - rot.gap
        local cosMin = 1 - reach / rot.radius
        local window = (cosMin >= 1) and 0 or (2 * math.acos(math.max(-1, math.min(1, cosMin)))) / math.abs(rot.omega)
        shortestWindow = math.min(shortestWindow, window)
        tiersSeen[lv.designTier] = true
    end
end
expect(count > 40, "there are plenty of windmills to check (" .. count .. " in 60 towers)")
expect(fastest <= 9, "no arm tip moves faster than 9 studs a second (" .. string.format("%.1f", fastest) .. "): always slower than a walk")
expect(longestWait <= 7, "an arm comes round to you at least every 7 seconds (" .. string.format("%.1f", longestWait) .. ")")
expect(shortestWindow >= 0.6, "and stays within jumping reach for at least 0.6 s each time (" .. string.format("%.2f", shortestWindow) .. ")")

print("== vanishing platforms keep their promise")
local blinkChains, worstOverlap, minDuty, maxPeriod, minPeriod = 0, 99, 1, 0, 99
local function solidWindow(b, t) return CL.BlinkState(b, t) ~= "gone" end        -- (a flickering platform can still be stood on)
for seed = 1, 40 do
    local tw = build(seed * 5 + 1)
    for i, b in ipairs(tw.blinkers) do
        local nxt = tw.blinkers[i + 1]
        minDuty, maxPeriod, minPeriod = math.min(minDuty, b.duty), math.max(maxPeriod, b.period), math.min(minPeriod, b.period)
        if nxt and nxt.level == b.level and math.abs(nxt.phase - b.phase - b.period * (b.duty - 0.3)) < 1e-6 then
            blinkChains += 1
            local both = 0
            for k = 0, math.floor(b.period * 100) do
                local t = k / 100
                if solidWindow(b, t) and solidWindow(nxt, t) then both += 0.01 end
            end
            worstOverlap = math.min(worstOverlap, both)
        end
    end
end
expect(blinkChains > 200, "there are plenty of neighbouring pairs to check (" .. blinkChains .. ")")
expect(worstOverlap >= 0.9, "every platform is still there for at least 0.9 s after the next one appears (worst " .. string.format("%.2f", worstOverlap) .. ")")
expect(minDuty >= 0.58, "each is solid for at least 58% of the time (" .. minDuty .. ")")
expect(minPeriod >= 3.2 and maxPeriod <= 4.6, "and cycles every 3.2-4.6 seconds (" .. minPeriod .. " - " .. maxPeriod .. ")")
local sample = { period = 4, duty = 0.7, phase = 0 }
expect(CL.BlinkState(sample, 0.5) == "solid" and CL.BlinkState(sample, 2.5) == "warn" and CL.BlinkState(sample, 3.5) == "gone" and CL.BlinkState(sample, 4.5) == "solid", "solid, then flickering for the last 0.8 s, then gone, then back")

print("== wall chimneys")
local function designByName(name) for _, d in ipairs(TL.Designs) do if d.name == name then return d end end end
local chimneys = { "Chimney Climb", "Wall Chimney", "Ice Chimney", "Chimney Storm", "Frozen Chimney" }
for _, name in ipairs(chimneys) do
    local d = designByName(name)
    expect(d ~= nil, name .. " is a design")
    local lim = CD.Limits[d.tier]
    local L = CL.Build({ base = BASE, modules = { { "rest", { len = 20, width = 30 } }, d.modules[1] }, zRange = 9 })
    local ledges = {}
    for _, p in ipairs(L.platforms) do if p.sz <= 4.2 then ledges[#ledges + 1] = p end end
    table.sort(ledges, function(a, b) return a.y < b.y end)
    local okHops, okHead, okRise = true, true, true
    local function dist(a, b)
        local gx = math.max(0, math.abs(a.x - b.x) - (a.sx + b.sx) / 2)
        local gz = math.max(0, math.abs(a.z - b.z) - (a.sz + b.sz) / 2)
        return math.sqrt(gx * gx + gz * gz)
    end
    for k = 2, #ledges do
        if dist(ledges[k - 1], ledges[k]) > lim.maxGap - 0.3 then okHops = false end
        if ledges[k].y - ledges[k - 1].y > lim.maxRise + 1e-6 then okRise = false end
    end
    for a = 1, #ledges do
        for b = a + 2, #ledges do
            if ledges[b].y - ledges[a].y <= 9 and dist(ledges[a], ledges[b]) < 0.5 then okHead = false end
        end
    end
    expect(#ledges >= 8 and okHops and okRise, name .. ": " .. #ledges .. " ledges, every hop sideways-and-up is inside tier " .. d.tier .. "'s limits")
    expect(okHead, name .. ": no ledge hangs over another within head height")
    local shaft = 0
    local tall = true
    for _, w in ipairs(L.walls) do
        if w.shaft then
            shaft += 1
            if w.sy < #ledges * (lim.maxRise - 0.4) then tall = false end
            for _, lg in ipairs(ledges) do
                if math.abs(w.z - lg.z) - (w.sz + lg.sz) / 2 < 0 then tall = false end        -- a wall must never cut through a ledge
            end
        end
    end
    expect(shaft == 2 and tall, name .. ": two tall walls frame the shaft and clear every ledge")
end

print("== towers really use them")
local totals = { rotor = 0, blink = 0, chimney = 0 }
local kindsPerTower, minKinds = 0, 99
local function nameOf(m) return m[1] end
for seed = 1, 60 do
    local tw = build(seed * 3 + 2)
    totals.rotor += #tw.rotors
    totals.blink += #tw.blinkers
    for _, w in ipairs(tw.walls) do if w.shaft then totals.chimney += 1 end end
    local kinds = {}
    for _, lv in ipairs(tw.levels) do
        local d = type(lv.designKey) == "number" and TL.Designs[lv.designKey] or (TL.Bosses[lv.zoneId])
        for _, m in ipairs(d and d.modules or {}) do kinds[nameOf(m)] = true end
        if lv.connector then kinds["connector_" .. lv.connector] = true end
    end
    local n = 0 for _ in pairs(kinds) do n += 1 end
    kindsPerTower += n
    minKinds = math.min(minKinds, n)
end
expect(totals.rotor > 60 and totals.blink > 400 and totals.chimney > 50, "windmills (" .. totals.rotor .. "), vanishing platforms (" .. totals.blink .. ") and chimney walls (" .. totals.chimney .. ") fill the towers")
expect(kindsPerTower / 60 >= 16 and minKinds >= 12, "a tower uses " .. string.format("%.1f", kindsPerTower / 60) .. " different kinds of piece on average (fewest " .. minKinds .. ")")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
