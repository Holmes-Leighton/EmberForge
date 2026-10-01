-- Daily login streak: log in on consecutive UTC days to climb a 7-day reward ladder (then it repeats, with the streak
-- still counting up). Missing a day starts again from day 1. Rewards are granted on join, no button needed.
local StreakData = {}

StreakData.DAY_SECONDS = 86400

-- reward for day 1..7 of the ladder
StreakData.Rewards = {
    { coins = 100 },
    { coins = 150 },
    { speedUps = 1 },
    { coins = 250 },
    { coins = 100, speedUps = 1 },
    { coins = 400 },
    { coins = 600, speedUps = 2, luckBoostSeconds = 3600 },     -- day 7: the big one
}

function StreakData.DayOf(now) return math.floor(now / StreakData.DAY_SECONDS) end

function StreakData.LadderDay(streak) return ((math.max(1, streak) - 1) % #StreakData.Rewards) + 1 end

function StreakData.Describe(r)
    local bits = {}
    if r.coins then table.insert(bits, r.coins .. " coins") end
    if r.speedUps then table.insert(bits, r.speedUps .. " Speed-Up" .. (r.speedUps > 1 and "s" or "")) end
    if r.luckBoostSeconds then table.insert(bits, "a free Lucky Boost") end
    return table.concat(bits, " + ")
end

return StreakData
