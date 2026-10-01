QUIET = true
local GM = load("game/ReplicatedStorage/Shared/Modules/GolemMotion")

print("== Golem swing shape")
local lo, hi = 9, -9
local maxStep = 0
local prev = GM.Raise(0)
for i = 1, 2000 do
    local u = i / 2000
    local r = GM.Raise(u)
    lo, hi = math.min(lo, r), math.max(hi, r)
    maxStep = math.max(maxStep, math.abs(r - prev))
    prev = r
end
expect(lo >= -0.001 and hi <= 1.05, "stays in range (" .. string.format("%.2f to %.2f", lo, hi) .. ")")
expect(maxStep < 0.06, "never jumps between neighbouring moments (largest step " .. string.format("%.3f", maxStep) .. " of a swing in 1/2000)")
expect(math.abs(GM.Raise(0) - GM.Raise(1)) < 1e-6, "one swing ends exactly where the next begins")

-- anticipation: it rises before the strike, holds near the top, then drops fast
expect(GM.Raise(0.15) > GM.Raise(0.02), "draws back and up first")
expect(GM.Raise(0.34) > 0.97, "pauses at the top")
local dropFast = GM.Raise(0.38) - GM.Raise(0.48)
local riseSlow = GM.Raise(0.30) - GM.Raise(0.0)
expect(GM.Raise(GM.IMPACT) < 0.02, "the pick is on the ground at the impact point")
expect(math.abs(GM.Raise(0.47) - GM.Raise(0.45)) > math.abs(GM.Raise(0.40) - GM.Raise(0.38)), "the strike speeds up toward the ground (ease in)")

-- rebound: it bounces up a little after landing, then settles
local bounce = 0
for i = 0, 100 do bounce = math.max(bounce, GM.Raise(GM.IMPACT + 0.14 * i / 100)) end
expect(bounce > 0.05 and bounce < 0.25, "a small bounce after landing (" .. string.format("%.2f", bounce) .. ")")

-- follow-through: a lagged copy is the same shape, later
expect(math.abs(GM.Lagged(0.5, 0.1) - GM.Raise(0.4)) < 1e-9, "the head follows a beat behind the arm")

-- body drive swings from leaning back to driving forward
local backs, fwd = 9, -9
for i = 0, 100 do local d = GM.Drive(i / 100) backs, fwd = math.min(backs, d), math.max(fwd, d) end
expect(backs < -0.1 and fwd > 0.9 and fwd <= 1.0001, "body leans back on the wind-up and drives forward on the strike")
print("== Golem tiredness")
expect(GM.DurabilityOf({ _durabilitySeconds = 50, _maxDurabilitySeconds = 100 }) == 0.5, "durability is a share of the maximum")
expect(GM.DurabilityOf({}) == 1 and GM.DurabilityOf({ _durabilitySeconds = -5, _maxDurabilitySeconds = 100 }) == 0, "no wear tracked is fresh; below zero clamps to broken")
local fresh, mid, low, dead = GM.Fatigue(1), GM.Fatigue(0.5), GM.Fatigue(0.1), GM.Fatigue(0)
expect(fresh.tempo == 1 and fresh.slump == 0 and fresh.glow == 1 and not fresh.stopped, "a fresh Golem is unaffected")
expect(mid.tempo == 1 and mid.slump == 0, "half durability is still full speed")
expect(low.tempo < 1 and low.tempo > 0.45 and low.slump > 0 and low.glow < 1, "a low Golem slows, sags and dims")
expect(dead.stopped and dead.tempo == 0 and dead.slump == 1 and dead.glow == 0.25, "a broken Golem stops, slumps fully and dims")
local prev = 1
local mono = true
for i = 100, 0, -1 do
    local fx = GM.Fatigue(i / 100)
    if fx.tempo > prev + 1e-9 then mono = false end
    prev = fx.tempo
end
expect(mono, "it only ever gets slower as durability falls")
expect(GM.BarColour(0.9) ~= GM.BarColour(0.4) and GM.BarColour(0.4) ~= GM.BarColour(0.1), "the bar goes green, then amber, then red")
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
