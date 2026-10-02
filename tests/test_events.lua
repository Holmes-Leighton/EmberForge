QUIET = true
-- The automatic hourly event: rotation, fairness and how it feeds the multipliers.
local ES = load("game/ReplicatedStorage/Shared/Data/EventScheduleData")
local LO = load("SSS/EmberForge/Services/LiveOpsService")

print("== rotation")
local seen, repeats = {}, 0
local t0 = 1800000000 - (1800000000 % 3600)
local prev
for h = 0, 24 * 30 do
    local e = ES.Current(t0 + h * 3600 + 17)
    seen[e.id] = (seen[e.id] or 0) + 1
    if prev and prev == e.id then repeats = repeats + 1 end
    expect(e.startTime == t0 + h * 3600 and e.endTime == e.startTime + 3600, "hour " .. h .. " has the right window")
    prev = e.id
end
expect(repeats == 0, "the same event never runs two hours in a row")
local n = 0
for _, c in pairs(seen) do n = n + 1 end
expect(n == #ES.Events, "all " .. #ES.Events .. " events appear over a month")
local lo, hi = math.huge, 0
for _, c in pairs(seen) do lo = math.min(lo, c) hi = math.max(hi, c) end
expect(hi - lo <= 12, "no event is starved or overused (min " .. lo .. ", max " .. hi .. ")")
expect(ES.Next(t0 + 5).startTime == t0 + 3600, "Next() is the following hour")

print("== multipliers")
local cur = ES.Current(os.time())
local expectElement = cur.kind == "element" and cur.multiplier or 1
for _, el in ipairs({ "Ember", "Stone", "Frost", "Storm", "Void", "Coral" }) do
    local want = (cur.kind == "element" and cur.element == el) and cur.multiplier or 1
    expect(LO.GetElementMultiplier(el) == want, el .. " element multiplier is " .. want)
end
expect(LO.GetMultiplier("luck") == (cur.kind == "luck" and cur.multiplier or 1), "luck multiplier follows the hour")
expect(LO.GetMultiplier("drops") >= (cur.kind == "drops" and cur.multiplier or 1), "drop multiplier includes the hour's bonus")
LO.HourlyEnabled = false
expect(LO.GetElementMultiplier("Ember") == 1 and LO.GetMultiplier("luck") == 1, "the hourly event can be switched off")
LO.HourlyEnabled = true


print("== rarer events are shorter")
local jt0 = 1800000000 - (1800000000 % 14400)
local jackpots = 0
for w = 0, 600 do
    local j = ES.Jackpot(jt0 + w * ES.JACKPOT_WINDOW + 30)
    if j then
        jackpots += 1
        expect(j.endTime - j.startTime == ES.JACKPOT_SECONDS, "a jackpot lasts " .. ES.JACKPOT_SECONDS .. "s")
        expect(j.kind == "coins" or j.kind == "sell", j.id .. " is a coin event")
    end
    expect(ES.Jackpot(jt0 + w * ES.JACKPOT_WINDOW + ES.JACKPOT_SECONDS + 5) == nil, "a jackpot is over after " .. ES.JACKPOT_SECONDS .. "s")
end
expect(jackpots > 60 and jackpots < 180, "about one window in five has a jackpot (" .. jackpots .. "/601), so roughly one a day")
expect(ES.NextJackpotStart(jt0) ~= nil, "the next jackpot can be found")
expect(ES.JACKPOT_SECONDS < ES.SURGE_SECONDS and ES.SURGE_SECONDS < ES.SLOT_SECONDS, "jackpot < surge < hourly in length")
expect(ES.JACKPOT_CHANCE / ES.JACKPOT_WINDOW < ES.SURGE_CHANCE / ES.SURGE_WINDOW, "and a jackpot is rarer than a surge")
local kinds = {}
for _, e in ipairs(ES.Events) do kinds[e.kind] = true end
for _, e in ipairs(ES.Surges) do kinds[e.kind] = true end
expect(kinds.coins and kinds.sell, "hourly events and surges include coin and sell events")

print("== coin multiplier is capped")
local hits = 0
for w = 0, 3000 do
    local now = jt0 + w * 1200 + 5
    local m = ES.Multiplier("coins", now)
    expect(m >= 1 and m <= ES.COIN_MULTIPLIER_MAX, "coin multiplier stays in 1.." .. ES.COIN_MULTIPLIER_MAX .. " (" .. m .. ")")
    if m > 1 then hits += 1 end
end
expect(hits > 0, "coin events do happen")
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
