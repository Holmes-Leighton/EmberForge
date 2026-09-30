QUIET = true
local RemoteEvents = load("game/ReplicatedStorage/Shared/Modules/RemoteEvents")
for _, n in ipairs({ "Notify", "LevelUp" }) do RemoteEvents[n] = fireCounter() end
local PDS = load("SSS/EmberForge/Services/PlayerDataService")
local LiveOps = load("SSS/EmberForge/Services/LiveOpsService")
local Prog = load("SSS/EmberForge/Services/ProgressionService")
local GC = load("game/ReplicatedStorage/Shared/Data/GameConfig")
local Safe = load("SSS/EmberForge/Services/SafeDataStore")

local function at(y, m, d, h)
    -- days since epoch for a civil date (UTC)
    local yy = m <= 2 and y - 1 or y
    local era = math.floor(yy / 400)
    local yoe = yy - era * 400
    local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return (era * 146097 + doe - 719468) * 86400 + (h or 0) * 3600
end

local p = newPlayer(1, "Ops"); local d = PDS.Load(p)

print("== weekends")
advance(at(2026, 9, 2, 12) - os.time())      -- Wednesday
LiveOps.Refresh()
expect(LiveOps.GetMultiplier("xp") == 1, "midweek: no bonus")
advance(at(2026, 9, 5, 12) - os.time())      -- Saturday
expect(LiveOps.GetMultiplier("xp") == 2, "Saturday: Double XP")
local before = d.PlayerXP
Prog.AddPlayerXP(p, 100)
expect(d.PlayerXP - before == 200, "XP is doubled on the weekend (" .. (d.PlayerXP - before) .. ")")
expect(LiveOps.GetMultiplier("drops") == 1, "drops unaffected")

print("== timed events")
advance(at(2026, 9, 2, 12) - os.time())
LiveOps.AddEvent("drops", 3, 2, "Test Drops")
expect(LiveOps.GetMultiplier("drops") == 3, "3x drops event is live")
advance(3 * 3600)
expect(LiveOps.GetMultiplier("drops") == 1, "and ends after its 2 hours")
LiveOps.AddEvent("xp", 2, 24, "Bonus XP")
LiveOps.AddEvent("xp", 1.5, 24, "More XP")
expect(LiveOps.GetMultiplier("xp") == 3, "overlapping events multiply (2 x 1.5)")
LiveOps.ClearEvents()
expect(LiveOps.GetMultiplier("xp") == 1, "clear removes them")

print("== remote overrides are bounded")
local original = GC.ONLINE_PRODUCTION_SPEED
LiveOps.SetOverride("ONLINE_PRODUCTION_SPEED", 30)
expect(GC.ONLINE_PRODUCTION_SPEED == 30, "override applied")
LiveOps.SetOverride("ONLINE_PRODUCTION_SPEED", 99999)
expect(GC.ONLINE_PRODUCTION_SPEED == 600, "clamped to the allowed maximum")
expect(not LiveOps.SetOverride("ADMIN_USER_IDS", {}), "non-whitelisted setting refused")
LiveOps.SetOverride("ONLINE_PRODUCTION_SPEED", nil)
expect(GC.ONLINE_PRODUCTION_SPEED == original, "removing the override restores the default")

print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
