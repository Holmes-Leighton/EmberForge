-- Daily login streak (see StreakData). PlayerData.LoginStreak = { count, lastDay, best }.

local StreakData        = require(game.ReplicatedStorage.Shared.Data.StreakData)
local Utils             = require(game.ReplicatedStorage.Shared.Modules.Utils)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StreakService = {}

-- Call when a player joins. Returns { streak, day, reward, message } if a reward was granted today, else nil.
function StreakService.OnJoin(player)
    local data = PlayerDataService.Get(player)
    if not data then return nil end
    local s = data.LoginStreak
    if type(s) ~= "table" then s = { count = 0, lastDay = 0, best = 0 } data.LoginStreak = s end

    local today = StreakData.DayOf(Utils.UnixTimestamp())
    if s.lastDay == today then return nil end                       -- already rewarded today
    if s.lastDay == today - 1 then s.count = (s.count or 0) + 1 else s.count = 1 end
    s.lastDay = today
    s.best = math.max(s.best or 0, s.count)

    local day = StreakData.LadderDay(s.count)
    local r = StreakData.Rewards[day]
    if r.coins then data.EmberCoins = (data.EmberCoins or 0) + r.coins end
    if r.speedUps then data.SpeedUps = (data.SpeedUps or 0) + r.speedUps end
    if r.luckBoostSeconds then
        data.LuckBoostExpiry = math.max(data.LuckBoostExpiry or 0, Utils.UnixTimestamp()) + r.luckBoostSeconds
    end
    PlayerDataService.MarkDirty(player)
    return {
        streak = s.count, day = day, reward = r,
        message = string.format("Day %d of your login streak (%d in a row): %s. Come back tomorrow for day %d!",
            day, s.count, StreakData.Describe(r), StreakData.LadderDay(s.count + 1)),
    }
end

return StreakService
