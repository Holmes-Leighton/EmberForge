QUIET = true
local CP  = load("game/ReplicatedStorage/Shared/Modules/CartPath")
local Sim = load("game/ReplicatedStorage/Shared/Modules/CartSim")
local CD  = load("game/ReplicatedStorage/Shared/Data/CartCourseData")

print("== rail path")
local straight = CP.Build({ { 0, 0, 0 }, { 50, 0, 0 }, { 100, 0, 0 } })
expect(math.abs(straight.length - 100) < 0.01, "a straight path is as long as its points (" .. straight.length .. ")")
local x, y, z, tx, ty, tz = CP.At(straight, 25)
expect(math.abs(x - 25) < 0.01 and math.abs(tx - 1) < 1e-6 and ty == 0, "position and heading at 25 studs")
x = CP.At(straight, -10)
expect(x == 0, "before the start clamps to the start")
x = CP.At(straight, 1e6)
expect(math.abs(x - 100) < 0.01, "past the end clamps to the end")
local ramp = CP.Build({ { 0, 0, 0 }, { 50, 0, 0 }, { 100, 10, 0 }, { 150, 10, 0 } })
local _, _, _, _, ry = CP.At(ramp, 75)
expect(ry > 0.05, "a climbing stretch has a positive slope (" .. ry .. ")")
local dipped = CP.Build({ { 0, 0.6, 0 }, { 40, 0.6, 0 }, { 80, 12, 0 }, { 120, 12, 0 } }, 0.6)
local lowest = 1e9
for _, p in ipairs(dipped.pts) do lowest = math.min(lowest, p[2]) end
expect(lowest >= 0.6 - 1e-9, "the smoothed rail never dips below the road")
local samples = CP.Samples(straight, 10)
expect(#samples == 11 and samples[1].s == 0 and math.abs(samples[11].s - 100) < 1e-6, "samples run from start to end")
local arc = CP.Build({ { 0, 0, 0 }, { 40, 0, 0 }, { 60, 0, 30 }, { 100, 0, 30 } })
local prev = CP.Samples(arc, 4)
local worst = 0
for i = 2, #prev do
    local dot = prev[i].tx * prev[i - 1].tx + prev[i].tz * prev[i - 1].tz
    worst = math.max(worst, math.acos(math.clamp(dot, -1, 1)))
end
expect(worst < math.rad(25), "a bend turns gradually, no sharp kinks (worst step " .. math.floor(math.deg(worst) + 0.5) .. " deg)")

print("== cart physics")
local function run(slope, pushV, seconds, v0)
    local st = { s = 50, v = v0 or 0, length = 1000 }
    for _ = 1, math.floor(seconds * 20) do Sim.Step(st, 0.05, slope, pushV) end
    return st
end
local st = run(0, nil, 5, 0)
expect(st.s == 50 and st.v == 0, "an unpushed cart on the flat stays put")
st = run(0, 14, 6, 0)
expect(st.v > 11 and st.v <= 14 and st.s > 100, "a pusher gets it rolling to nearly their pace (" .. string.format("%.1f", st.v) .. ")")
st = run(0, nil, 12, 12)
expect(st.v == 0 and st.s > 50, "friction stops a coasting cart (never reverses it)")
st = run(0.30, nil, 4, 0)
expect(st.v < -3 and st.s < 50, "a parked cart on a steep slope rolls back (" .. string.format("%.1f", st.v) .. ")")
st = run(0.15, nil, 4, 0)
expect(st.v == 0 and st.s == 50, "a gentle slope holds a parked cart")
st = run(0.30, 14, 8, 0)
expect(st.v > 0 and st.v < 11, "pushing uphill works, but slower than on the flat (" .. string.format("%.1f", st.v) .. ")")
st = run(-0.30, nil, 10, 0)
expect(st.v > 15 and st.v <= Sim.MAX_RUN, "downhill it runs away, up to a top speed (" .. string.format("%.1f", st.v) .. ")")
local team1 = Sim.PushTarget({ 14 })
local team3 = Sim.PushTarget({ 14, 14, 14 })
expect(team1 == 14 and team3 > team1 and team3 <= Sim.TEAM_MAX, "more pushers means a higher target pace (" .. team1 .. " -> " .. team3 .. ")")
expect(Sim.PushTarget({}) == nil, "no pushers means no target")
expect(Sim.PushTarget({ 40 }) == Sim.PUSH_MAX, "one player can't push faster than the limit")
st = { s = 995, v = 10, length = 1000 }
for _ = 1, 40 do Sim.Step(st, 0.05, 0, 14) end
expect(st.s == 1000 and st.v <= 0, "it stops at the end of the rail")
st = { s = 5, v = -10, length = 1000 }
for _ = 1, 40 do Sim.Step(st, 0.05, 0.3, nil) end
expect(st.s == 0 and st.v >= 0, "it stops at the start of the rail")

print("== courses")
expect(#CD.Courses == 3, "three courses")
local lastTier, lastMult, lastLevel = 0, 0, 0
for _, c in ipairs(CD.Courses) do
    local r = CD.Resolve(c.id)
    expect(r and r.length > 300, c.name .. " is a proper length (" .. math.floor(r.length) .. " studs)")
    expect(c.tier > lastTier and c.rewardMult > lastMult and c.minLevel >= lastLevel, c.name .. " is harder, better paid and higher level than the one before")
    lastTier, lastMult, lastLevel = c.tier, c.rewardMult, c.minLevel
    -- the south band of the hub: east of the pads, south of the forge plots (z -30..30; their fences reach about -35) and clear of the south wall (-260)
    local inside = true
    for _, p in ipairs(r.path.pts) do
        if p[1] < 170 or p[1] > 2040 or p[3] < -225 or p[3] > -55 then inside = false end
    end
    expect(inside, c.name .. " stays in the south band, clear of every forge plot, quarry plot and wall")
    expect(r.path.pts[1][1] > 150, c.name .. " starts well clear of the spawn and forge")
    local steepest = 0
    for _, sm in ipairs(CP.Samples(r.path, 4)) do steepest = math.max(steepest, math.abs(sm.ty)) end
    expect(steepest < 0.45, c.name .. " has no cliffs (steepest " .. string.format("%.2f", steepest) .. ")")
    local prevS = 0
    for i, cp in ipairs(r.checkpoints) do
        expect(cp > prevS and cp < r.length, c.name .. " checkpoint " .. i .. " is in order")
        prevS = cp
    end
    for _, h in ipairs(r.hazards) do
        local lo = h.kind == "bridge" and h.s - h.length / 2 or h.s - 6
        local hi = h.kind == "bridge" and h.s + h.length / 2 or h.s + 6
        expect(lo > 25 and hi < r.length - 25, c.name .. " " .. h.kind .. " " .. h.index .. " is well inside the course")
        local flat = true
        for s = lo, hi, 2 do
            local _, _, _, _, _, _ = CP.At(r.path, s)
            local _, _, _, _, ty = CP.At(r.path, s)
            if math.abs(ty) > 0.08 then flat = false end
        end
        expect(flat, c.name .. " " .. h.kind .. " " .. h.index .. " sits on level track")
    end
end

print("== difficulty: bends, hills and length")
local lastLen, lastR = 0, math.huge
for _, c in ipairs(CD.Courses) do
    local r = CD.Resolve(c.id)
    local minR = CP.MinRadius(r.path)
    expect(r.length > lastLen, c.name .. " is longer than the one before (" .. math.floor(r.length) .. " studs)")
    expect(minR <= lastR, c.name .. " has bends at least as tight as the one before (tightest radius " .. math.floor(minR) .. ")")
    lastLen, lastR = r.length, minR
    expect(minR >= 5, c.name .. " has no impossible kink")
end
expect(CP.MinRadius(CD.Resolve("EasyHaul").path) >= 11, "Easy Haul's bends can all be taken at a steady push")
expect(CP.MinRadius(CD.Resolve("CaveRun").path) < 10 and CP.MinRadius(CD.Resolve("DeepRun").path) < 8, "Cave and Deep have tight turns")
local deepPath = CD.Resolve("DeepRun").path
local climb = 0
for _, sm in ipairs(CP.Samples(deepPath, 4)) do climb = math.max(climb, sm.y) end
expect(climb > 45, "Deep Run climbs a real mountain (" .. math.floor(climb) .. " studs up)")
expect(Sim.CornerLimit(0) == math.huge and Sim.CornerLimit(1 / 10) < 14 and Sim.CornerLimit(1 / 40) > 25, "the safe bend speed falls as the bend tightens")

print("== gates and bridges run on a shared clock")
local gate = { open = 4, closed = 3, phase = 0 }
expect(CD.HazardOpen(gate, 0) and CD.HazardOpen(gate, 3.9) and not CD.HazardOpen(gate, 4.1) and not CD.HazardOpen(gate, 6.9) and CD.HazardOpen(gate, 7.1), "open 4 s, shut 3 s, repeating")
local shifted = { open = 4, closed = 3, phase = 4 }
expect(not CD.HazardOpen(shifted, 0) and CD.HazardOpen(shifted, 3.2), "the phase shifts the cycle")
expect(math.abs(CD.HazardChangesIn(gate, 1) - 3) < 1e-9 and math.abs(CD.HazardChangesIn(gate, 5) - 2) < 1e-9, "it can say how long until the next change")
expect(CD.Get("nope") == nil and CD.Resolve("nope") == nil, "an unknown course is nil")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
