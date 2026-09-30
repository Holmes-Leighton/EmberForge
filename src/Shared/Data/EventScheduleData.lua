-- The automatic hourly event: every UTC hour one bonus is live in EVERY server. It is computed from the clock alone,
-- so no DataStore is needed and all servers (and the client's countdown banner) agree.
-- kinds: "drops" (all resources), "element" (one element's Golems), "luck" (rare drop weight), "xp"
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

-- The event that follows the current one
function EventScheduleData.Next(now)
    return EventScheduleData.Current(now + EventScheduleData.SLOT_SECONDS)
end

return EventScheduleData
