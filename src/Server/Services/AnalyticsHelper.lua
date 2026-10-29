-- Thin, crash-proof wrapper over Roblox AnalyticsService (spec 13/14: watch retention, funnel and
-- economy "from day one"). Every call is pcall'd - analytics must never be able to break gameplay -
-- and unavailable APIs (older engine versions, Studio) are silently skipped.

local Analytics = {}

local service
do
    local ok, s = pcall(function() return game:GetService("AnalyticsService") end)
    service = ok and s or nil
end

local function try(fn)
    if not service then return end
    pcall(fn)
end

-- The last few events, kept so tests (and a Studio session) can see what was logged even though Studio has no analytics service
Analytics._log = {}
local function Note(kind, name, value)
    local log = Analytics._log
    log[#log + 1] = { kind = kind, name = name, value = value }
    if #log > 200 then table.remove(log, 1) end
end

-- Onboarding funnel: logged once per player, ever. `key` is remembered in the save.
function Analytics.Funnel(player, data, key, step, name)
    data.Funnel = data.Funnel or {}
    if data.Funnel[key] then return end
    data.Funnel[key] = true
    Note("funnel", name, step)
    try(function() service:LogOnboardingFunnelStepEvent(player, step, name) end)
end

function Analytics.Custom(player, name, value, fields)
    Note("custom", name, value or 1)
    try(function() service:LogCustomEvent(player, name, value or 1, fields) end)
end

-- ── Sessions and retention ────────────────────────────────────────────────────
-- Called when a player joins. Remembers when they first came, counts their sessions, logs the first-join funnel step, and logs a Retention event the first time they are back
-- after 1, 3, 7 and 14 days (so day-1 / day-7 return can be read straight off the dashboard). Returns { day, session, firstEver }.
Analytics.RETENTION_DAYS = { 1, 3, 7, 14 }
local DAY = 86400
function Analytics.Session(player, data, now)
    now = now or os.time()
    local first = false
    if not data.FirstJoinAt then data.FirstJoinAt, first = now, true end
    data.Sessions = (data.Sessions or 0) + 1
    local day = math.floor((now - data.FirstJoinAt) / DAY)
    Analytics.Funnel(player, data, "join", 1, "Joined")
    Analytics.Custom(player, "SessionStart", data.Sessions, { day = day })
    data.Funnel = data.Funnel or {}
    for _, d in ipairs(Analytics.RETENTION_DAYS) do
        local key = "ret" .. d
        if day >= d and not data.Funnel[key] then
            data.Funnel[key] = true
            Analytics.Custom(player, "Retention", d, { day = day })
        end
    end
    return { day = day, session = data.Sessions, firstEver = first }
end

-- How long after first joining a milestone happened (once per milestone): "TimeToFirstGolem" and so on. `seconds` is what to log.
function Analytics.TimeTo(player, data, key, now)
    if not data.FirstJoinAt then return nil end
    data.FunnelTimes = data.FunnelTimes or {}
    if data.FunnelTimes[key] then return nil end
    local seconds = math.max(0, (now or os.time()) - data.FirstJoinAt)
    data.FunnelTimes[key] = seconds
    Analytics.Custom(player, "TimeTo" .. key, seconds, nil)
    return seconds
end

-- flow: "Source" | "Sink"; txType e.g. "Gameplay" | "Shop" | "IAP"
function Analytics.Economy(player, flow, currency, endingBalance, amount, txType, sku)
    try(function()
        service:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType[flow], currency, endingBalance, amount,
            Enum.AnalyticsEconomyTransactionType[txType].Name, sku)
    end)
end

function Analytics.Progression(player, path, status, level)
    try(function()
        service:LogProgressionEvent(player, path, Enum.AnalyticsProgressionStatus[status], level)
    end)
end

return Analytics
