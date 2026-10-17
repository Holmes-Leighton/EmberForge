-- The round clock of the Hollow Maze: pure state, no Roblox objects. A round is: players gather (the gate is shut), a head start (the gate is open, the Zombie Golem sleeps), the
-- hunt (it wakes and hunts), then an intermission before the next maze. When someone escapes, the hunt ends a short while later for everyone still running. Rounds are numbered
-- from the wall clock, so every server is in the same round, with the same maze, at the same moment.
local MazeData = require(game.ReplicatedStorage.Shared.Data.MazeData)

local MazeRound = {}

local CYCLE = MazeData.GATHER_SECONDS + MazeData.HEADSTART_SECONDS + MazeData.HUNT_SECONDS + MazeData.INTERMISSION
MazeRound.CYCLE = CYCLE

-- Where the wall clock `t` (UTC seconds) falls: the round index and how far into it we are
function MazeRound.Locate(t)
    local index = math.floor(t / CYCLE)
    return index, t - index * CYCLE
end

function MazeRound.New(t)
    local index, into = MazeRound.Locate(t)
    local started = t - into
    local opens = started + MazeData.GATHER_SECONDS
    local wakes = opens + MazeData.HEADSTART_SECONDS
    return {
        index = index, seed = MazeData.SeedForRound(index),
        startedAt = started, opensAt = opens, wakesAt = wakes, endsAt = wakes + MazeData.HUNT_SECONDS, nextStart = started + CYCLE,
        sped = false, escapes = {},
    }
end

-- "gather" | "headstart" | "hunt" | "intermission"
function MazeRound.Phase(round, t)
    if t < round.opensAt then return "gather" end
    if t < round.wakesAt then return "headstart" end
    if t < round.endsAt then return "hunt" end
    return "intermission"
end

-- You can walk in any time from the start of the round until the last minute of the hunt (a late arrival starts in the lobby with the gate already open and the
-- Zombie Golem somewhere in the maze; their run is timed from when they came in)
function MazeRound.CanEnter(round, t)
    return t < round.endsAt - MazeData.LATE_ENTRY_CUTOFF
end

function MazeRound.GateOpen(round, t)
    return t >= round.opensAt
end

-- Seconds the zombie has been hunting (0 until it wakes)
function MazeRound.HuntElapsed(round, t)
    return math.max(0, t - round.wakesAt)
end

-- Seconds since the gate opened (what your escape time is measured from)
function MazeRound.RunElapsed(round, t)
    return math.max(0, t - round.opensAt)
end

function MazeRound.Running(round, t)
    return t >= round.opensAt and t < round.endsAt
end

function MazeRound.UntilNext(round, t)
    return math.max(0, round.nextStart - t)
end

-- Advance to time t. Returns the events since the last call: { kind = "new", round } when the next round begins.
function MazeRound.Step(round, t)
    if t >= round.nextStart then
        local fresh = MazeRound.New(t)
        return { { kind = "new", round = fresh } }, fresh
    end
    return {}, round
end

-- Someone escaped at time t: the hunt has at most ESCAPE_SPEEDUP seconds left for everyone else. Returns true the first time that shortens the round.
function MazeRound.Escape(round, userId, t, seconds)
    if t >= round.endsAt then return false end
    table.insert(round.escapes, { userId = userId, t = t, seconds = seconds })
    if round.sped then return false end
    round.sped = true
    local newEnd = t + MazeData.ESCAPE_SPEEDUP
    if newEnd < round.endsAt then
        round.endsAt = newEnd
        return true
    end
    return false
end

return MazeRound
