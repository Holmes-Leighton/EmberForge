-- The round clock of the Sky Tower: pure state, no Roblox objects. A round runs for ROUND_SECONDS; when anyone reaches the top the time left drops to SUMMIT_SPEEDUP
-- for everyone still climbing; then an intermission, then a new round with a new tower (a new seed). Rounds are numbered from the wall clock, so every server is in
-- the same round at the same moment.
local TowerData = require(game.ReplicatedStorage.Shared.Data.TowerData)

local TowerRound = {}

local CYCLE = TowerData.ROUND_SECONDS + TowerData.INTERMISSION

-- Where the wall clock `t` (UTC seconds) falls: the round index, how far into it we are, and whether we are in the climb or the intermission
function TowerRound.Locate(t)
    local index = math.floor(t / CYCLE)
    local into = t - index * CYCLE
    return index, into, into < TowerData.ROUND_SECONDS
end

function TowerRound.New(t)
    local index, into, running = TowerRound.Locate(t)
    return {
        index = index, seed = TowerData.SeedForRound(index),
        startedAt = t - into, endsAt = (t - into) + TowerData.ROUND_SECONDS, nextStart = (t - into) + CYCLE,
        sped = false, summits = {},
    }
end

-- Advance to time t. Returns the events since the last call: { "end" } when the climbing time is over, { "new", round } when a new round starts.
function TowerRound.Step(round, t)
    local events = {}
    if t >= round.nextStart then
        local fresh = TowerRound.New(t)
        table.insert(events, { kind = "new", round = fresh })
        return events, fresh
    end
    return events, round
end

function TowerRound.Running(round, t)
    return t < round.endsAt
end

function TowerRound.Remaining(round, t)
    return math.max(0, round.endsAt - t)
end

function TowerRound.UntilNext(round, t)
    return math.max(0, round.nextStart - t)
end

-- Someone reached the top at time t: the time left for everyone else drops. Returns true if this was the first summit that sped the round up.
function TowerRound.Summit(round, userId, t, seconds)
    if t >= round.endsAt then return false end
    table.insert(round.summits, { userId = userId, t = t, seconds = seconds })
    if round.sped then return false end
    round.sped = true
    local newEnd = t + TowerData.SUMMIT_SPEEDUP
    if newEnd < round.endsAt then
        round.endsAt = newEnd
        return true
    end
    return false
end

return TowerRound
