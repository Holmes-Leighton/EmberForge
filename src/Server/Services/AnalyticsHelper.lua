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

-- Onboarding funnel: logged once per player, ever. `key` is remembered in the save.
function Analytics.Funnel(player, data, key, step, name)
    data.Funnel = data.Funnel or {}
    if data.Funnel[key] then return end
    data.Funnel[key] = true
    try(function() service:LogOnboardingFunnelStepEvent(player, step, name) end)
end

function Analytics.Custom(player, name, value, fields)
    try(function() service:LogCustomEvent(player, name, value or 1, fields) end)
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
