QUIET = true
local GW = load("game/ReplicatedStorage/Shared/Modules/GolemWalk")

print("== Golem wander and walk")
local st = GW.New(5)
local s0 = GW.Sample(st, 0)
expect(type(s0.x) == "number" and type(s0.z) == "number", "samples are numbers")

-- it never wanders further than RADIUS (plus a hair) from home, over many cycles
local far, walks, minePhases = 0, 0, 0
for t = 0, 600, 0.25 do
    local s = GW.Sample(st, t)
    far = math.max(far, math.sqrt(s.x * s.x + s.z * s.z))
    if s.walking then walks += 1 else minePhases += 1 end
end
expect(far <= GW.RADIUS + 0.01, "stays within " .. GW.RADIUS .. " studs of home (" .. string.format("%.1f", far) .. ")")
expect(walks > 0 and minePhases > walks, "walks sometimes, mines most of the time (" .. walks .. " walking samples vs " .. minePhases .. " mining)")

-- continuous: no teleporting between samples
local jump = 0
local prev = GW.Sample(st, 0)
for t = 0.05, 300, 0.05 do
    local s = GW.Sample(st, t)
    jump = math.max(jump, math.sqrt((s.x - prev.x) ^ 2 + (s.z - prev.z) ^ 2))
    prev = s
end
expect(jump < 0.9, "moves smoothly, never jumping (largest step " .. string.format("%.2f", jump) .. " studs per 0.05s)")

-- deterministic: the same Golem is in the same place on every client
local a, b = GW.Sample(GW.New(9), 123.4), GW.Sample(GW.New(9), 123.4)
expect(a.x == b.x and a.z == b.z and a.yaw == b.yaw, "same seed and time give the same pose")
local c = GW.Sample(GW.New(10), 123.4)
expect(a.x ~= c.x or a.z ~= c.z or a.walking ~= c.walking, "different Golems are in different places")

-- legs swing in opposition and only while walking
local walkingSample, t0
for t = 0, 60, 0.1 do
    local s = GW.Sample(st, t)
    if s.walking and s.env > 0.9 then walkingSample, t0 = s, t break end
end
expect(walkingSample ~= nil, "finds a moment of full-speed walking")
if walkingSample then
    expect(GW.LegSwing(walkingSample, t0, 1) == -GW.LegSwing(walkingSample, t0, -1), "the two legs swing in opposite directions")
    expect(GW.Bob(walkingSample, t0) >= 0 and GW.Bob(walkingSample, t0) <= 0.3, "the body bobs a little with each step")
end
local still = GW.Sample(st, 1)
expect(not still.walking and GW.LegSwing(still, 1, 1) == 0 and GW.Bob(still, 1) == 0, "no leg swing or bob while mining")

-- it faces where it is going and turns back by the end of the walk
local mid = { yaw = 0 }
for t = 0, 60, 0.05 do
    local s = GW.Sample(st, t)
    if s.walking and math.abs(s.yaw) > math.abs(mid.yaw) then mid = s end
end
expect(math.abs(mid.yaw) > 0.1, "turns toward the way it walks")
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
