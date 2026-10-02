-- The automatic hourly event: every UTC hour one bonus is live in EVERY server. It is computed from the clock alone,
-- so no DataStore is needed and all servers (and the client's countdown banner) agree.
-- kinds: "drops" (all resources), "element" (one element's Golems), "luck" (rare drop weight), "xp",
--        "coins" (coins from quests and level-ups), "sell" (what the Supplier pays for your surplus)
--
-- Three tiers, and the rarer an event, the shorter it lasts:
--   hourly   always one live, 60 minutes
--   surge    about once every 9 hours, 10 minutes
--   jackpot  about once a day, 3 minutes
local EventScheduleData = {}

EventScheduleData.SLOT_SECONDS = 3600

EventScheduleData.Events = {
    { id = "ember",  name = "Ember Hour",   kind = "element", element = "Ember", multiplier = 2,   blurb = "Ember Golems mine x2" },
    { id = "stone",  name = "Stone Hour",   kind = "element", element = "Stone", multiplier = 2,   blurb = "Stone Golems mine x2" },
    { id = "frost",  name = "Frost Hour",   kind = "element", element = "Frost", multiplier = 2,   blurb = "Frost Golems mine x2" },
    { id = "storm",  name = "Storm Hour",   kind = "element", element = "Storm", multiplier = 2,   blurb = "Storm Golems mine x2" },
    { id = "void",   name = "Void Hour",    kind = "element", element = "Void",  multiplier = 2,   blurb = "Void Golems mine x2" },
    { id = "lucky",  name = "Lucky Hour",   kind = "luck",    multiplier = 2,                       blurb = "Rare drops are twice as likely" },
    { id = "xp",     name = "Double XP Hour", kind = "xp",    multiplier = 2,                       blurb = "All XP x2" },
    { id = "bonanza", name = "Bonanza Hour", kind = "drops",  multiplier = 1.5,                     blurb = "All resources x1.5" },
    { id = "coinrush", name = "Coin Rush Hour", kind = "coins", multiplier = 1.5,                      blurb = "Quest and level-up coins x1.5" },
    { id = "market", name = "Market Hour", kind = "sell",     multiplier = 2,                       blurb = "The Supplier pays double for surplus" },
}

-- Index into Events for a given hour slot. The daily shift keeps the order from being the same every 8 hours,
-- and the step of 3 (+1 at most) never repeats the same event in two consecutive hours.
local function IndexFor(slot)
    return (slot * 3 + math.floor(slot / 24)) % #EventScheduleData.Events + 1
end

function EventScheduleData.SlotOf(now)
    return math.floor(now / EventScheduleData.SLOT_SECONDS)
end

-- The event live at time `now` (unix seconds), with its endTime
function EventScheduleData.Current(now)
    local slot = EventScheduleData.SlotOf(now)
    local def = EventScheduleData.Events[IndexFor(slot)]
    local e = table.clone(def)
    e.startTime = slot * EventScheduleData.SLOT_SECONDS
    e.endTime = e.startTime + EventScheduleData.SLOT_SECONDS
    e.scheduled = true
    return e
end

-- ── Surges: rare, short, server-wide moments ──────────────────────────────────
-- Every 3 hours there is a chance (SURGE_CHANCE) that a Surge strikes in the first SURGE_SECONDS of that window.
-- Like the hourly event it comes from the clock alone, so every server has the same surge at the same moment.
EventScheduleData.SURGE_WINDOW  = 3 * 3600
EventScheduleData.SURGE_SECONDS = 10 * 60
EventScheduleData.SURGE_CHANCE  = 0.35
EventScheduleData.Surges = {
    { id = "meteor",  name = "Meteor Shower",  kind = "drops", multiplier = 3, blurb = "Meteors fall! All resources x3" },
    { id = "richvein", name = "Rich Vein",     kind = "luck",  multiplier = 4, blurb = "A rich vein is exposed! Rare drops x4" },
    { id = "frenzy",  name = "Forge Frenzy",   kind = "xp",    multiplier = 3, blurb = "The forge roars! All XP x3" },
    { id = "goldrush", name = "Gold Rush",     kind = "coins", multiplier = 3, blurb = "Gold fever! Quest and level-up coins x3" },
    { id = "caravan", name = "Merchant Caravan", kind = "sell", multiplier = 3, blurb = "A caravan is in town! The Supplier pays triple" },
}

local function SurgeHash(window)
    local h = (window % 1000003) * 2654435761 % 4294967296
    return (h % 10000) / 10000, math.floor(h / 10000) % #EventScheduleData.Surges + 1
end

-- The surge live at `now`, or nil. `startTime`/`endTime` are set; `surge = true`.
function EventScheduleData.Surge(now)
    local window = math.floor(now / EventScheduleData.SURGE_WINDOW)
    local roll, index = SurgeHash(window)
    if roll >= EventScheduleData.SURGE_CHANCE then return nil end
    local start = window * EventScheduleData.SURGE_WINDOW
    if now < start or now >= start + EventScheduleData.SURGE_SECONDS then return nil end
    local e = table.clone(EventScheduleData.Surges[index])
    e.startTime, e.endTime, e.surge = start, start + EventScheduleData.SURGE_SECONDS, true
    return e
end

-- The next surge after `now` (looks up to a week ahead), or nil
function EventScheduleData.NextSurgeStart(now)
    local window = math.floor(now / EventScheduleData.SURGE_WINDOW)
    for w = window, window + 56 do
        local roll = SurgeHash(w)
        local start = w * EventScheduleData.SURGE_WINDOW
        if roll < EventScheduleData.SURGE_CHANCE and start + EventScheduleData.SURGE_SECONDS > now then return start end
    end
    return nil
end

-- ── Jackpots: the rarest, shortest moments ────────────────────────────────────
-- Every 4 hours there is a one-in-five chance that a Jackpot strikes in the first JACKPOT_SECONDS of that window: about once a day, and only 3 minutes long.
-- Like the others it comes from the clock alone, so every server has the same jackpot at the same moment.
EventScheduleData.JACKPOT_WINDOW  = 4 * 3600
EventScheduleData.JACKPOT_SECONDS = 3 * 60
EventScheduleData.JACKPOT_CHANCE  = 0.2
EventScheduleData.Jackpots = {
    { id = "hoard",    name = "Dragon's Hoard", kind = "coins", multiplier = 5, blurb = "The hoard is open! Quest and level-up coins x5" },
    { id = "windfall", name = "Windfall",       kind = "sell",  multiplier = 5, blurb = "A fortune for your surplus! The Supplier pays x5" },
}

local function JackpotHash(window)
    local h = ((window + 7919) % 1000003) * 2654435761 % 4294967296
    return (h % 10000) / 10000, math.floor(h / 10000) % #EventScheduleData.Jackpots + 1
end

-- The jackpot live at `now`, or nil. `startTime`/`endTime` are set; `jackpot = true`.
function EventScheduleData.Jackpot(now)
    local window = math.floor(now / EventScheduleData.JACKPOT_WINDOW)
    local roll, index = JackpotHash(window)
    if roll >= EventScheduleData.JACKPOT_CHANCE then return nil end
    local start = window * EventScheduleData.JACKPOT_WINDOW
    if now < start or now >= start + EventScheduleData.JACKPOT_SECONDS then return nil end
    local e = table.clone(EventScheduleData.Jackpots[index])
    e.startTime, e.endTime, e.jackpot = start, start + EventScheduleData.JACKPOT_SECONDS, true
    return e
end

-- The next jackpot after `now` (looks up to two weeks ahead), or nil
function EventScheduleData.NextJackpotStart(now)
    local window = math.floor(now / EventScheduleData.JACKPOT_WINDOW)
    for w = window, window + 84 do
        local roll = JackpotHash(w)
        local start = w * EventScheduleData.JACKPOT_WINDOW
        if roll < EventScheduleData.JACKPOT_CHANCE and start + EventScheduleData.JACKPOT_SECONDS > now then return start end
    end
    return nil
end

-- The event that follows the current one
function EventScheduleData.Next(now)
    return EventScheduleData.Current(now + EventScheduleData.SLOT_SECONDS)
end

-- Product of every scheduled event of `kind` live at `now` (hourly, surge and jackpot together), never below 1 and never above COIN_MULTIPLIER_MAX for the
-- coin kinds, so events that overlap cannot snowball. The server uses LiveOpsService.GetMultiplier (which adds admin events); this is for the client's mirror.
EventScheduleData.COIN_MULTIPLIER_MAX = 6
function EventScheduleData.Multiplier(kind, now)
    local m = 1
    for _, e in ipairs({ EventScheduleData.Current(now), EventScheduleData.Surge(now) or false, EventScheduleData.Jackpot(now) or false }) do
        if e and e.kind == kind then m = m * math.max(1, e.multiplier or 1) end
    end
    if kind == "coins" or kind == "sell" then m = math.min(m, EventScheduleData.COIN_MULTIPLIER_MAX) end
    return m
end

return EventScheduleData
