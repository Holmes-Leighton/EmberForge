-- Phone audit: build every menu on a small landscape screen (640x360) and measure how big each piece of text really is
-- after ScaleUI shrinks its window. Roblox recommends text of about 10-11 px or more on a phone; anything below is listed.
QUIET = true
workspace.CurrentCamera.ViewportSize = Vector2.new(640, 360)
local Snapshot = {
    PlayerLevel = 3, PlayerXP = 500, ForgeLevel = 3, ForgeXP = 1600, EmberCoins = 500, GolemSlots = 3, EffectiveGolemSlots = 3,
    Golems = {}, Inventory = { BasicOre = 120, Coal = 60 }, Pending = {}, Blueprints = { "BP_Ember_T1" },
    MasteryLevels = { Ember = 0, Frost = 0, Stone = 0, Storm = 0, Void = 0 }, SmeltQueue = {}, SpeedUps = 0, StorageTier = 0, SeasonPassTier = 0,
    OwnedCosmetics = {}, Titles = {}, Equipped = {}, Settings = {}, DailyChallenges = {}, WeeklyChallenges = {}, Achievements = {},
    AvailableEventBlueprints = {}, SeasonStatus = { seasonId = "Season3", currentWeek = 2, totalWeeks = 7, claimedWeeks = {}, communityCurrent = 0, communityTarget = 1 },
}
installFakeRemotes({ GetPlayerData = function() return Snapshot end, GetMarketListings = function() return {} end, GetMyListings = function() return {} end,
    GetTradeHistory = function() return {} end, GetLeaderboard = function() return {} end })

local builders = {}
for path in pairs(SOURCES) do if path:find("^src/StarterGui/") then table.insert(builders, path) end end
table.sort(builders)
for _, path in ipairs(builders) do runScriptFile(path) end

local MIN_EFFECTIVE = 10
local VERBOSE = false          -- set to true to list every item that is still too small
local MAX_STILL_SMALL = 0       -- regression guard: it was 246 before the text boost
local function effectiveScale(inst)
    local s, p = 1, inst
    while p do
        for _, k in ipairs(p:GetChildren()) do
            if k.ClassName == "UIScale" and type(k.Scale) == "number" then s = s * k.Scale end
        end
        p = rawget(p, "_parent")
    end
    return s
end

-- What ScaleUI's text boost should give: text grows toward READABLE_PX on screen but is fitted to its box (about 1.15 x its height)
local READABLE_PX, SCALE_OFF = 11, 0.85
local function boosted(d, scale)
    if scale >= SCALE_OFF then return d.TextSize end
    local auto = d.AutomaticSize
    if auto ~= nil and auto ~= Enum.AutomaticSize.None then return d.TextSize end
    local want = math.ceil(READABLE_PX / math.max(scale, 0.1))
    local h = d.Size and d.Size.Y and d.Size.Y.Scale == 0 and d.Size.Y.Offset or nil
    local fit = (h and h > 0) and (h / 1.15) or want
    return math.max(d.TextSize, math.min(want, fit))
end

local worst, total, small, smallAfter = {}, 0, 0, 0
for _, gui in ipairs(PlayerGui:GetChildren()) do
    if gui.ClassName == "ScreenGui" then
        local low, count, n = math.huge, 0, 0
        for _, d in ipairs(gui:GetDescendants()) do
            local hidden = d.Name == "KeyHint" or gui.Name == "AdminPanel"       -- key hints are not shown on a phone; the admin panel is staff only
            local p = d
            while p and p ~= gui do if rawget(p, "_props").Visible == false then hidden = true end p = rawget(p, "_parent") end
            if not hidden and (d.ClassName == "TextLabel" or d.ClassName == "TextButton" or d.ClassName == "TextBox") and type(d.TextSize) == "number"
                and (d.Text or "") ~= "" then
                local sc = effectiveScale(d)
                local eff = d.TextSize * sc
                local after = boosted(d, sc) * sc
                n += 1
                if eff < MIN_EFFECTIVE then small += 1 end
                if after < MIN_EFFECTIVE then
                    count += 1
                    if VERBOSE then
                        local path, p = d.Name, rawget(d, "_parent")
                        for _ = 1, 2 do if p and p ~= gui then path = p.Name .. "/" .. path p = rawget(p, "_parent") end end
                        print(string.format("    %-18s %-44s %.1f px (size %d, box %s) \"%s\"", gui.Name, path, after, d.TextSize,
                            d.Size and (d.Size.Y.Scale == 0 and (d.Size.Y.Offset .. "px") or "scaled") or "?", tostring(d.Text):sub(1, 24)))
                    end
                end
                if after < low then low = after end
            end
        end
        total += n; smallAfter += count
        if n > 0 then table.insert(worst, { name = gui.Name, low = low, count = count, n = n }) end
    end
end
table.sort(worst, function(a, b) return a.low < b.low end)
print(string.format("%d of %d text items render under %d px on a 640x360 phone as designed; about %d with the ScaleUI text boost", small, total, MIN_EFFECTIVE, smallAfter))
for _, w in ipairs(worst) do print(string.format("  %-22s smallest %.1f px (boosted)   %d of %d still under %d", w.name, w.low, w.count, w.n, MIN_EFFECTIVE)) end
expect(smallAfter <= MAX_STILL_SMALL, "no more than " .. MAX_STILL_SMALL .. " text items stay under " .. MIN_EFFECTIVE .. " px (" .. smallAfter .. ")")
print(FAILED and ("FAILED: " .. FAILED) or "ALL PASSED")
