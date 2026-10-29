-- Funnel, session and retention tracking (AnalyticsHelper): what a dashboard needs to see where new players drop off.
QUIET = true
local A = load("SSS/EmberForge/Services/AnalyticsHelper")
local DAY = 86400
local T0 = 1700000000

local function count(kind, name)
    local n = 0
    for _, e in ipairs(A._log) do if e.kind == kind and (name == nil or e.name == name) then n += 1 end end
    return n
end
local function last(name)
    for i = #A._log, 1, -1 do if A._log[i].name == name then return A._log[i] end end
end

print("== first session")
local d = {}
local s1 = A.Session({}, d, T0)
expect(s1.firstEver and s1.day == 0 and s1.session == 1 and d.FirstJoinAt == T0, "a first join is remembered (session 1, day 0)")
expect(count("funnel", "Joined") == 1, "the first-join funnel step is logged")
expect(last("SessionStart").value == 1, "and a session start")
expect(count("custom", "Retention") == 0, "no retention event on day 0")

print("== coming back")
local s2 = A.Session({}, d, T0 + 3600)
expect(s2.session == 2 and s2.day == 0 and not s2.firstEver, "a second visit the same day is session 2, day 0")
expect(count("funnel", "Joined") == 1, "the funnel step is only logged once, ever")
A.Session({}, d, T0 + DAY + 100)
expect(count("custom", "Retention") == 1 and last("Retention").value == 1, "the first return after a day logs Retention 1")
A.Session({}, d, T0 + DAY + 5000)
expect(count("custom", "Retention") == 1, "and only once")
A.Session({}, d, T0 + 8 * DAY)
local days = {}
for _, e in ipairs(A._log) do if e.name == "Retention" then days[#days + 1] = e.value end end
expect(table.concat(days, ",") == "1,3,7", "a visit on day 8 logs day 3 and 7 together (" .. table.concat(days, ",") .. ")")
A.Session({}, d, T0 + 20 * DAY)
expect(count("custom", "Retention") == 4 and last("Retention").value == 14, "day 14 follows")
expect(d.Sessions == 6, "every session is counted (" .. d.Sessions .. ")")

print("== how long things took")
local nd = {}
A.Session({}, nd, T0)
local t1 = A.TimeTo({}, nd, "FirstGolem", T0 + 95)
expect(t1 == 95 and last("TimeToFirstGolem").value == 95, "time to the first Golem: 95 s")
expect(A.TimeTo({}, nd, "FirstGolem", T0 + 500) == nil and nd.FunnelTimes.FirstGolem == 95, "recorded once, the first time")
expect(A.TimeTo({}, nd, "FirstDeploy", T0 + 140) == 140, "each milestone has its own time")
expect(A.TimeTo({}, {}, "FirstGolem", T0) == nil, "no join time means nothing to log, and no error")

print("== funnel steps")
local fd = {}
A.Funnel({}, fd, "craft", 2, "FirstGolemCrafted")
A.Funnel({}, fd, "craft", 2, "FirstGolemCrafted")
expect(count("funnel", "FirstGolemCrafted") == 1, "a step is logged once")
local steps = {}
for _, src in ipairs({ "src/Server/RemoteHandler.server.lua", "src/Server/Services/CollectService.lua", "src/Server/Services/TowerService.lua", "src/Server/Services/MazeService.lua", "src/Shared/Modules/RemoteEvents.lua" }) do
    local text = SOURCES[src]
    if text then for step, name in text:gmatch('Analytics%.Funnel%([^,]+,[^,]+,[^,]+,%s*(%d+),%s*"(%w+)"') do steps[tonumber(step)] = name end end
end
expect(steps[2] == "FirstGolemCrafted" and steps[3] == "FirstGolemDeployed" and steps[4] == "FirstCollect", "the core steps 2-4 are wired")
expect(steps[5] == "FirstTowerEntered" and steps[6] == "FirstMazeEntered" and steps[7] == "FirstZoneCleared" and steps[8] == "FirstMazePiece" and steps[9] == "FirstMazeEscape",
    "and the Tower and Maze steps 5-9")
local init = SOURCES["src/Server/init.server.lua"]
expect(init:find("Analytics.Session", 1, true) ~= nil, "joining calls Analytics.Session")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
