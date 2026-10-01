QUIET = true
-- The idle sequencer: moves come in random order, never the same one twice running, and walking cancels them.
local IM = load("game/ReplicatedStorage/Shared/Modules/IdleMoves")

local function run(set, seed, seconds, restMin, restMax)
    local st = IM.New(set, seed, restMin, restMax)
    local seq, last, t = {}, nil, 0
    local busy = 0
    while t < seconds do
        local move, k = IM.Step(st, t, true)
        if move then
            busy += 0.05
            if move ~= last then table.insert(seq, move) last = move end
            expect(k >= 0 and k < 1, "progress stays 0..1")
        else last = nil end
        t += 0.05
    end
    return seq, busy
end

print("== both characters have four moves")
for _, set in ipairs({ "pet", "golem" }) do
    local n = 0 for _ in pairs(IM.Sets[set]) do n += 1 end
    expect(n == 4, set .. " has four idle moves")
end

print("== random order, no immediate repeats")
for _, set in ipairs({ "pet", "golem" }) do
    local seq = run(set, 11, 600)
    local repeats, seen = 0, {}
    for i, m in ipairs(seq) do
        seen[m] = true
        if seq[i + 1] == m then repeats += 1 end
    end
    local kinds = 0 for _ in pairs(seen) do kinds += 1 end
    expect(#seq > 30 and kinds == 4 and repeats == 0, set .. ": " .. #seq .. " moves in 10 minutes, all 4 used, no back-to-back repeats")
end
local a, b = run("pet", 1, 300), run("pet", 2, 300)
local same = true for i = 1, math.min(#a, #b, 8) do if a[i] ~= b[i] then same = false end end
expect(not same, "two pets with different seeds do not move in lockstep")
local c1, c2 = run("pet", 5, 300), run("pet", 5, 300)
expect(table.concat(c1, ",") == table.concat(c2, ","), "the same seed gives the same order (so tests are stable)")

print("== resting and walking")
local _, busyPet = run("pet", 3, 300)
local _, busyGolem = run("golem", 3, 300, 6, 16)
expect(busyPet / 300 < 0.6 and busyPet > 20, "a pet spends some of its idle time moving (" .. string.format("%.0f%%", busyPet / 3) .. ")")
expect(busyGolem / 300 < busyPet / 300, "a busy Golem moves less often than a pet (" .. string.format("%.0f%%", busyGolem / 3) .. ")")
local st = IM.New("pet", 4)
local moved = false
for t = 0, 30, 0.05 do local m = IM.Step(st, t, true) if m then moved = true break end end
expect(moved, "a standing pet starts a move within 30 seconds")
local m1 = IM.Step(st, 31, true)
local m2 = IM.Step(st, 31.1, false)
expect(m2 == nil, "walking cancels the move")

print("== body motion")
for _, set in ipairs({ "pet", "golem" }) do
    for name in pairs(IM.Sets[set]) do
        local top = 0
        for k = 0, 1, 0.05 do
            local bob, pitch, roll, yaw = IM.Body(set, name, k, k * 3)
            expect(bob == bob and pitch == pitch and roll == roll and yaw == yaw, name .. " is a number all the way through")
            top = math.max(top, math.abs(bob), math.abs(pitch), math.abs(roll), math.abs(yaw))
        end
        expect(top > 0 and top < 7, set .. "." .. name .. " moves the body (peak " .. string.format("%.2f", top) .. ")")
        local b0, p0, r0, y0 = IM.Body(set, name, 0, 0)
        local b1, p1, r1, y1 = IM.Body(set, name, 1, 0)
        expect(math.abs(b0) < 1e-6 and math.abs(p0) < 1e-6 and math.abs(r0) < 1e-6 and math.abs(b1) < 1e-6 and math.abs(p1) < 1e-6, name .. " starts and ends at rest")
    end
end

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
