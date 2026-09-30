-- Live operations (spec 11 / 5.3): tune the economy and run timed events WITHOUT shipping an update.
--
-- Config lives in a DataStore ("EmberForge_LiveOps_v1", key "config") shaped like:
--   {
--     overrides = { ONLINE_PRODUCTION_SPEED = 60, DAILY_COIN_REWARD = 150, ... },   -- see ALLOWED
--     weekendXP = true,                                                             -- Double XP weekends
--     events = { { id, name, kind = "xp" | "drops", multiplier = 2, startTime = os.time(), endTime = ... } },
--   }
-- Servers re-read it every 5 minutes. Admins can also use /event in chat (AdminService).

local SafeDataStore = require(script.Parent.SafeDataStore)
local GameConfig    = require(game.ReplicatedStorage.Shared.Data.GameConfig)
local Utils         = require(game.ReplicatedStorage.Shared.Modules.Utils)

local EventScheduleData = require(game.ReplicatedStorage.Shared.Data.EventScheduleData)

local LiveOpsService = {}
LiveOpsService.HourlyEnabled = true      -- the automatic hourly event (EventScheduleData)

local store = SafeDataStore.GetDataStore("EmberForge_LiveOps_v1")
local KEY = "config"
local REFRESH_SECONDS = 300

-- Only these numeric GameConfig values may be overridden remotely (bounds keep a typo from breaking the game)
local ALLOWED = {
    ONLINE_PRODUCTION_SPEED   = { min = 1,    max = 600 },
    DAILY_COIN_REWARD         = { min = 0,    max = 5000 },
    MARKET_LISTING_FEE_PERCENT = { min = 0,   max = 0.5 },
    XP_PER_SMELT              = { min = 0,    max = 500 },
    XP_PER_TRADE              = { min = 0,    max = 500 },
    SMELT_BATCH_SIZE          = { min = 1,    max = 100 },
    STARTING_COINS            = { min = 0,    max = 10000 },
}

local defaults = {}            -- original values, so removing an override restores them
for key in pairs(ALLOWED) do defaults[key] = GameConfig[key] end

local config = { overrides = {}, events = {}, weekendXP = true }

local function ApplyOverrides()
    for key, bounds in pairs(ALLOWED) do
        local value = config.overrides and config.overrides[key]
        if type(value) == "number" and value == value then
            GameConfig[key] = math.clamp(value, bounds.min, bounds.max)
        else
            GameConfig[key] = defaults[key]
        end
    end
end

local function Prune(events)
    local now = Utils.UnixTimestamp()
    local kept = {}
    for _, e in ipairs(events or {}) do
        if type(e) == "table" and (e.endTime or 0) > now then table.insert(kept, e) end
    end
    return kept
end

function LiveOpsService.Refresh()
    local ok, saved = pcall(function() return store:GetAsync(KEY) end)
    if ok and type(saved) == "table" then
        config = {
            overrides = type(saved.overrides) == "table" and saved.overrides or {},
            events    = Prune(saved.events),
            weekendXP = saved.weekendXP ~= false,
        }
    end
    ApplyOverrides()
end

local function IsWeekend(now)
    local wday = os.date("!*t", now).wday        -- 1 = Sunday ... 7 = Saturday (UTC)
    return wday == 1 or wday == 7
end

function LiveOpsService.ActiveEvents()
    local now = Utils.UnixTimestamp()
    local list = {}
    for _, e in ipairs(config.events) do
        if (e.startTime or 0) <= now and (e.endTime or 0) > now then table.insert(list, e) end
    end
    if config.weekendXP and IsWeekend(now) then
        table.insert(list, { id = "weekend", name = "Double XP Weekend", kind = "xp", multiplier = 2 })
    end
    if LiveOpsService.HourlyEnabled then table.insert(list, EventScheduleData.Current(now)) end
    return list
end

-- Product of all active events of this kind ("xp", "drops", "luck" or "element"); never below 1.
-- Element events only count for the element asked about.
function LiveOpsService.GetMultiplier(kind, element)
    local m = 1
    for _, e in ipairs(LiveOpsService.ActiveEvents()) do
        if e.kind == kind and (e.element == nil or e.element == element) then m = m * math.max(1, e.multiplier or 1) end
    end
    return m
end

-- Extra multiplier for one element's Golems (Ember Hour etc.)
function LiveOpsService.GetElementMultiplier(element)
    return LiveOpsService.GetMultiplier("element", element)
end

local function Save(edit)
    pcall(function()
        store:UpdateAsync(KEY, function(old)
            local saved = type(old) == "table" and old or {}
            saved.overrides = type(saved.overrides) == "table" and saved.overrides or {}
            saved.events = Prune(saved.events)
            edit(saved)
            return saved
        end)
    end)
    LiveOpsService.Refresh()
end

function LiveOpsService.AddEvent(kind, multiplier, hours, name)
    local now = Utils.UnixTimestamp()
    Save(function(saved)
        table.insert(saved.events, {
            id = Utils.GenerateId(), name = name or kind, kind = kind,
            multiplier = multiplier, startTime = now, endTime = now + math.floor(hours * 3600),
        })
    end)
end

function LiveOpsService.ClearEvents()
    Save(function(saved) saved.events = {} end)
end

-- e.g. LiveOpsService.SetOverride("ONLINE_PRODUCTION_SPEED", 30); pass nil to restore the default
function LiveOpsService.SetOverride(key, value)
    if not ALLOWED[key] then return false, "not an adjustable setting" end
    Save(function(saved) saved.overrides[key] = value end)
    return true
end

function LiveOpsService.Init()
    LiveOpsService.Refresh()
    task.spawn(function()
        while true do
            task.wait(REFRESH_SECONDS)
            LiveOpsService.Refresh()
        end
    end)
end

return LiveOpsService
